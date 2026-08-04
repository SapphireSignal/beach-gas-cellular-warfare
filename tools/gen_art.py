#!/usr/bin/env python3
"""Beach Gas texture pipeline. Generates every surface texture into art/gen/
from the colours in scripts/palette.gd. Deterministic: same script, same pixels.

If a surface looks wrong, fix this file and rerun. Never hand-edit the outputs —
they are build products and the next run will overwrite them.

    python3 tools/gen_art.py

Outputs, per surface, at 512x512:

    art/gen/<name>_albedo.png     colour
    art/gen/<name>_normal.png     surface relief, for the lamps to catch
    art/gen/<name>_rough.png      how sharp the reflection is, per pixel

Three things about this project drive every decision below.

**Everything must tile seamlessly.** The forecourt is one open expanse and a
texture repeats across it dozens of times. Any seam shows up as a grid and reads
worse than the flat colour we started with. So all noise here is generated
periodically — the lattice indices wrap with a modulo, and every derivative uses
np.roll — which makes tiling a property of the maths rather than something to
fix up afterwards.

**The normal maps are the point.** Beach Gas has thirteen omni lights and real
shading. Colour variation alone still reads as flat paint; relief is what makes
asphalt catch a lamp along its aggregate and look like ground. This is the one
thing a 3D game gets that a 2D one cannot.

**It has to run on a phone.** 512 is chosen so you can walk up to a wall without
it turning to mush, while staying cheap once Godot compresses it. Surfaces you
only ever see from across the lot don't need entries here at all.
"""
import re
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / "scripts" / "palette.gd"
OUT = ROOT / "art" / "gen"

SIZE = 512

# One seed for the whole run. Bump it only if you want a different-looking set
# of surfaces; leaving it alone is what makes reruns reproducible.
SEED = 0xBEACA5


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

def load_palette():
    """Parse `const NAME := Color(r, g, b[, a])` out of scripts/palette.gd.

    Parsed rather than duplicated so there is exactly one place a colour is
    written down. If someone edits the palette and reruns this, the textures
    follow; a copy here would drift silently the first time that happened.
    """
    text = PALETTE.read_text()
    pattern = re.compile(
        r"^const\s+([A-Z][A-Z0-9_]*)\s*:=\s*Color\(([^)]*)\)", re.MULTILINE)
    out = {}
    for name, args in pattern.findall(text):
        parts = [p.strip() for p in args.split(",")]
        try:
            out[name] = tuple(float(p) for p in parts[:3])
        except ValueError:
            continue          # a Color built from something other than literals
    if not out:
        sys.exit("no colours parsed from %s — has its format changed?" % PALETTE)
    return out


# ---------------------------------------------------------------------------
# Noise
#
# Value noise on a wrapping lattice, summed over octaves. Every lookup takes its
# lattice index modulo the period, so the result is periodic by construction and
# tiles with no seam.
# ---------------------------------------------------------------------------

def _lattice(size, period, rng):
    grid = rng.random((period, period)).astype(np.float32)

    t = np.linspace(0.0, period, size, endpoint=False, dtype=np.float32)
    i0 = np.floor(t).astype(np.int32)
    f = t - i0
    f = f * f * (3.0 - 2.0 * f)            # smoothstep, so octaves don't crease
    i1 = (i0 + 1) % period
    i0 = i0 % period

    g00 = grid[np.ix_(i0, i0)]
    g01 = grid[np.ix_(i0, i1)]
    g10 = grid[np.ix_(i1, i0)]
    g11 = grid[np.ix_(i1, i1)]

    fx = f[None, :]
    fy = f[:, None]
    top = g00 * (1.0 - fx) + g01 * fx
    bot = g10 * (1.0 - fx) + g11 * fx
    return top * (1.0 - fy) + bot * fy


def fbm(size, period, octaves, rng, gain=0.5):
    """Fractal sum. Low octaves give the broad patchiness you read from across
    the lot; high octaves give the grain you only see up close."""
    total = np.zeros((size, size), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for i in range(octaves):
        total += amp * _lattice(size, period * (2 ** i), rng)
        norm += amp
        amp *= gain
    return total / norm


def speckle(size, period, rng, threshold=0.72):
    """Hard-edged flecks — aggregate in asphalt, grit in concrete. Thresholded
    rather than smooth, because stones have edges and blurred blobs read as
    stains instead."""
    n = _lattice(size, period, rng)
    return (n > threshold).astype(np.float32)


def normalise(a):
    lo, hi = float(a.min()), float(a.max())
    if hi - lo < 1e-6:
        return np.zeros_like(a)
    return (a - lo) / (hi - lo)


# ---------------------------------------------------------------------------
# Maps
# ---------------------------------------------------------------------------

def normal_map(height, strength):
    """Height to tangent-space normal.

    np.roll is what keeps this tileable — the pixel at the left edge takes its
    neighbour from the right edge, so the relief wraps exactly as the colour
    does. Computing gradients any other way puts a visible ridge on every seam.
    """
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength

    nz = np.ones_like(dx)
    length = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nz = -dx / length, -dy / length, nz / length

    # Godot expects the +Y-up convention, so green is flipped on the way out.
    rgb = np.stack([nx, -ny, nz], axis=-1)
    return (rgb * 0.5 + 0.5)


def tint(base_rgb, variation, amount):
    """Colour with per-pixel lightness variation, kept in gamma space because
    that is how Godot will read the PNG back."""
    v = 1.0 + (variation - 0.5) * 2.0 * amount
    rgb = np.array(base_rgb, dtype=np.float32)[None, None, :] * v[..., None]
    return np.clip(rgb, 0.0, 1.0)


# ---------------------------------------------------------------------------
# PNG writing
#
# Written by hand rather than through Pillow's convenience wrappers so the exact
# bit depth and colour type are pinned. A 16-bit or palettised PNG sneaking in
# would import into Godot with different settings and be a confusing thing to
# debug later.
# ---------------------------------------------------------------------------

def write_png(path, rgb_float):
    h, w, _ = rgb_float.shape
    data = (np.clip(rgb_float, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)

    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)
    return len(png)


# ---------------------------------------------------------------------------
# Godot import settings
#
# Written here, alongside the textures, because a texture is only as good as the
# settings it gets imported under — and Godot's defaults are wrong for this game
# in two ways that both cost real quality on a phone:
#
#   compress/mode=0    Lossless. Fine on a desktop, but it means the texture
#                      sits in VRAM uncompressed: 1 MB each, 12 MB for the set.
#                      Mode 2 is VRAM Compressed, which becomes ETC2/ASTC for
#                      iOS (project.godot already sets import_etc2_astc) and
#                      cuts that to roughly a quarter.
#
#   mipmaps=false      The worse of the two. Without mipmaps a ground texture
#                      viewed down the length of the forecourt aliases into a
#                      shimmering mess whenever you move — and it is worst on a
#                      small high-DPI phone screen, which is the only screen
#                      this game is played on.
#
# Godot rewrites [remap] and [deps] itself on import; only [params] needs to
# come from us. Any existing uid is preserved so references don't break.
# ---------------------------------------------------------------------------

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
%(uid)s
[deps]

source_file="res://art/gen/%(file)s"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=%(normal)d
compress/channel_pack=%(pack)d
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(png_path, kind):
    imp = png_path.with_suffix(png_path.suffix + ".import")

    uid = ""
    if imp.exists():
        for line in imp.read_text().splitlines():
            if line.startswith("uid="):
                uid = line + "\n"
                break

    # Normal maps get the dedicated compressor, which stores them in a way that
    # keeps the relief clean rather than blocky. Roughness is data, not colour,
    # so it is packed as a normal-map-style channel rather than treated as sRGB.
    normal = 1 if kind == "normal" else 0
    pack = 1 if kind in ("normal", "rough") else 0

    imp.write_text(IMPORT_TEMPLATE % {
        "uid": uid,
        "file": png_path.name,
        "normal": normal,
        "pack": pack,
    })


def emit(name, albedo, height, rough, normal_strength):
    maps = [
        ("albedo", albedo, "albedo"),
        ("normal", normal_map(height, normal_strength), "normal"),
        ("rough", np.repeat(rough[..., None], 3, axis=-1), "rough"),
    ]
    written = 0
    for suffix, data, kind in maps:
        path = OUT / ("%s_%s.png" % (name, suffix))
        written += write_png(path, data)
        write_import(path, kind)
    print("  %-10s %6.1f KB" % (name, written / 1024.0))
    return written


# ---------------------------------------------------------------------------
# The surfaces
# ---------------------------------------------------------------------------

def build_asphalt(pal, rng):
    """Old, patched, oil-stained. The forecourt is the single biggest thing on
    screen, so this one carries the most weight."""
    grain = fbm(SIZE, 8, 5, rng)
    patch = fbm(SIZE, 2, 3, rng)               # broad worn areas
    stones = speckle(SIZE, 96, rng, 0.70)      # aggregate showing through

    variation = normalise(grain * 0.55 + patch * 0.45)
    albedo = tint(pal["ASPHALT"], variation, 0.42)

    # Aggregate reads as slightly paler flecks, not white — wet-look stones on a
    # night forecourt would sparkle and pull the eye off the players.
    albedo = np.clip(albedo + stones[..., None] * 0.055, 0.0, 1.0)

    height = normalise(grain * 0.6 + stones * 0.4)

    # Oil patches: smoother than the surrounding surface, which is what makes
    # them read as spills rather than just darker asphalt.
    oil = np.clip((fbm(SIZE, 3, 3, rng) - 0.58) * 4.0, 0.0, 1.0)
    rough = np.clip(0.97 - oil * 0.45 - stones * 0.08, 0.0, 1.0)

    return emit("asphalt", albedo, height, rough, 2.2)


def build_concrete(pal, rng):
    """Garage floors and pillars. Blotchier and flatter than asphalt, with the
    pitting you get from years of tyres."""
    blotch = fbm(SIZE, 3, 4, rng)
    fine = fbm(SIZE, 16, 4, rng)
    pits = speckle(SIZE, 128, rng, 0.80)

    variation = normalise(blotch * 0.65 + fine * 0.35)
    albedo = tint(pal["CONCRETE"], variation, 0.24)
    albedo = np.clip(albedo - pits[..., None] * 0.075, 0.0, 1.0)

    height = normalise(fine * 0.5 + blotch * 0.3) - pits * 0.45
    rough = np.clip(0.88 + fine * 0.10, 0.0, 1.0)

    return emit("concrete", albedo, height, rough, 1.5)


def build_wall(pal, rng):
    """Painted breeze block on the shop front. Nearly flat — the relief is the
    render coat, not the blocks, since the blocks are real geometry."""
    coat = fbm(SIZE, 12, 4, rng)
    stain = fbm(SIZE, 2, 3, rng)

    variation = normalise(coat * 0.5 + stain * 0.5)
    albedo = tint(pal["WALL"], variation, 0.16)

    height = normalise(coat)
    rough = np.clip(0.84 + coat * 0.12, 0.0, 1.0)

    return emit("wall", albedo, height, rough, 0.9)


def build_curb(pal, rng):
    """Kerbs and bollards. Coarser than the wall, cleaner than the ground."""
    grain = fbm(SIZE, 10, 4, rng)
    chips = speckle(SIZE, 64, rng, 0.84)

    variation = normalise(grain)
    albedo = tint(pal["CURB"], variation, 0.20)
    albedo = np.clip(albedo - chips[..., None] * 0.06, 0.0, 1.0)

    height = normalise(grain) - chips * 0.35
    rough = np.clip(0.90 + grain * 0.08, 0.0, 1.0)

    return emit("curb", albedo, height, rough, 1.3)


SURFACES = [build_asphalt, build_concrete, build_wall, build_curb]


def main():
    pal = load_palette()
    print("palette: %d colours from %s" % (len(pal), PALETTE.name))

    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    print("generating %d surfaces at %dx%d:" % (len(SURFACES), SIZE, SIZE))
    total = sum(build(pal, rng) for build in SURFACES)
    print("total: %.1f KB in %s" % (total / 1024.0, OUT.relative_to(ROOT)))


if __name__ == "__main__":
    main()
