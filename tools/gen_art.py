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


def build_metal(pal, rng):
    """Pump housings, poles, shutters. Brushed rather than polished — a mirror
    finish on a phone reads as plastic, because there's no reflection probe for
    it to mirror."""
    # Anisotropic on purpose: brushing runs one way, so the noise is stretched
    # along x by sampling a tall, narrow lattice.
    fine = fbm(SIZE, 4, 5, rng)
    brush = _lattice(SIZE, 256, rng)
    grime = fbm(SIZE, 3, 3, rng)

    variation = normalise(brush * 0.6 + fine * 0.25 + grime * 0.15)
    albedo = tint(pal["METAL"], variation, 0.14)

    height = normalise(brush * 0.8 + fine * 0.2)
    # Grimy patches are duller. That contrast is most of what sells metal —
    # uniform roughness reads as painted plastic at any resolution.
    rough = np.clip(0.32 + grime * 0.34 + brush * 0.06, 0.0, 1.0)

    return emit("metal", albedo, height, rough, 0.7)


def build_rubber(pal, rng):
    """Tyres and mats. Almost black, so the relief is doing all the work — with
    no texture at all these read as holes cut in the world."""
    tread = fbm(SIZE, 6, 3, rng)
    pores = speckle(SIZE, 160, rng, 0.78)

    variation = normalise(tread)
    albedo = tint(pal["RUBBER"], variation, 0.55)   # large, since the base is dark

    height = normalise(tread) - pores * 0.5
    rough = np.clip(0.93 + tread * 0.06, 0.0, 1.0)

    return emit("rubber", albedo, height, rough, 1.8)


def build_hedge(pal, rng):
    """Planting. Dense small-scale clumping rather than leaf shapes — at the
    distance these are ever seen, clumping is what reads as foliage and actual
    leaves would just alias into noise."""
    clump = fbm(SIZE, 14, 5, rng, gain=0.62)
    coarse = fbm(SIZE, 4, 3, rng)

    variation = normalise(clump * 0.7 + coarse * 0.3)
    albedo = tint(pal["HEDGE"], variation, 0.45)
    # A few lighter tips catching the lamps, or it reads as a green block.
    tips = speckle(SIZE, 96, rng, 0.76)
    albedo = np.clip(albedo + tips[..., None] * 0.10, 0.0, 1.0)

    height = normalise(clump)
    rough = np.clip(0.95 + clump * 0.04, 0.0, 1.0)

    return emit("hedge", albedo, height, rough, 2.6)


SURFACES = [build_asphalt, build_concrete, build_wall, build_curb,
            build_metal, build_rubber, build_hedge]


# ---------------------------------------------------------------------------
# App icon
#
# Drawn with signed-distance fields rather than polygons: every shape is "how
# far is this pixel from the thing", which gives clean antialiased edges at any
# size for free, and lets shapes be combined with plain arithmetic.
#
# The brief is a home screen at thumbnail size, so it is built from three reads
# that survive being shrunk: a dusk sky, a black phone held upright, and the ZAP
# beam coming off its lens. No text — a wordmark is illegible at 60px and iOS
# prints the app name underneath anyway.
# ---------------------------------------------------------------------------

ICON_SIZE = 1024


def _coords(size):
    """Pixel grid in 0..1, y down."""
    t = (np.arange(size, dtype=np.float32) + 0.5) / size
    return np.meshgrid(t, t)          # x, y


def _sd_round_rect(x, y, cx, cy, hw, hh, r):
    """Distance to a rounded rectangle. Negative inside."""
    dx = np.abs(x - cx) - (hw - r)
    dy = np.abs(y - cy) - (hh - r)
    outside = np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dy, 0.0) ** 2)
    inside = np.minimum(np.maximum(dx, dy), 0.0)
    return outside + inside - r


def _fill(rgb, mask, colour):
    """Composite a flat colour through an alpha mask."""
    c = np.array(colour, dtype=np.float32)[None, None, :]
    m = mask[..., None]
    return rgb * (1.0 - m) + c * m


def _edge(sd, softness):
    """Signed distance to coverage. One pixel of softness keeps it crisp."""
    return np.clip(0.5 - sd / softness, 0.0, 1.0)


def build_icon(pal, rng):
    size = ICON_SIZE
    px = 1.0 / size
    soft = 2.0 * px
    x, y = _coords(size)

    # Sky: the game's own dusk, vertical, with the horizon glow low and warm.
    top = np.array(pal["SKY_TOP"], dtype=np.float32)
    horizon = np.array(pal["SKY_HORIZON"], dtype=np.float32)
    t = np.clip(y * 1.15, 0.0, 1.0)[..., None] ** 1.4
    rgb = top[None, None, :] * (1.0 - t) + horizon[None, None, :] * t

    # Ground: the forecourt, dark, cutting across the lower third.
    ground = _edge(0.66 - y, soft)
    rgb = _fill(rgb, ground, pal["ASPHALT"])

    # A lamp glow behind the phone, so the silhouette has something to sit on
    # and the icon doesn't read as a black slab on a flat gradient. Pushed
    # brighter than looks right at full size — iOS composites this against
    # whatever wallpaper the player has, and a low-contrast icon disappears.
    glow = np.exp(-(((x - 0.5) ** 2 + (y - 0.52) ** 2) / 0.075))
    lamp = np.array(pal["LAMP"], dtype=np.float32)[None, None, :]
    rgb = np.clip(rgb + lamp * (glow * 0.66)[..., None], 0.0, 1.0)

    # The phone, seen from the BACK. The beam fires from the camera lens in
    # phone.gd, so the back is the side that matters — and it keeps the icon
    # from turning into a generic bright-screen app tile, which is what a
    # front-facing version looked like.
    #
    # Smaller and lower than feels natural at full size: iOS masks icons to a
    # squircle that eats the corners, and the beam needs room to end inside the
    # frame rather than running off it.
    cy = 0.60
    body = _sd_round_rect(x, y, 0.5, cy, 0.132, 0.225, 0.040)
    body_a = _edge(body, soft)
    rgb = _fill(rgb, _edge(body + 0.010, soft), (0.02, 0.02, 0.03))   # rim

    # A vertical sheen down the back so it reads as a solid object catching the
    # forecourt lamps, rather than a flat cut-out.
    sheen = np.clip(1.0 - (y - (cy - 0.22)) * 1.9, 0.0, 1.0) ** 1.6
    back = np.array(pal["DARK_METAL"], dtype=np.float32)[None, None, :]
    back = back * (0.72 + 0.85 * sheen)[..., None]
    rgb = rgb * (1.0 - body_a[..., None]) + np.clip(back, 0.0, 1.0) * body_a[..., None]

    # Camera module: the raised square every modern phone has, centred rather
    # than in the corner because symmetry survives being shrunk to a thumbnail.
    mod_y = cy - 0.135
    module = _sd_round_rect(x, y, 0.5, mod_y, 0.062, 0.062, 0.022)
    rgb = _fill(rgb, _edge(module, soft), (0.055, 0.058, 0.068))

    # The lens itself, sitting in that module — the thing the beam comes out of.
    lens_y = mod_y
    lens_r = 0.030
    lens_d = np.sqrt((x - 0.5) ** 2 + (y - lens_y) ** 2)
    rgb = _fill(rgb, _edge(lens_d - lens_r, soft), (0.03, 0.03, 0.04))
    # Thin bright ring, so the lens reads as glass rather than a hole.
    ring = np.abs(lens_d - lens_r * 0.86) - 0.0035
    rgb = _fill(rgb, _edge(ring, soft) * 0.55, (0.45, 0.47, 0.55))

    zap = np.array(pal["ZAP"], dtype=np.float32)

    # Beam: a cone opening upward that fades out before the top edge. The first
    # pass ran it off the frame, which read as a crop rather than a beam.
    reach = 0.30                       # how far up it travels before it's gone
    up = np.clip((lens_y - y) / reach, 0.0, 1.0)
    half_width = 0.016 + up * 0.044
    in_beam = _edge(np.abs(x - 0.5) - half_width, soft * 2.5) * (y < lens_y)
    # Squared falloff so it thins out well short of the edge instead of being
    # chopped off at full strength.
    beam = in_beam * ((1.0 - up) ** 2.0) * 1.15
    rgb = np.clip(rgb + zap[None, None, :] * beam[..., None], 0.0, 1.0)

    # Muzzle bloom at the lens itself.
    flare = np.exp(-(((x - 0.5) ** 2 + (y - lens_y) ** 2) / 0.0020))
    rgb = np.clip(rgb + zap[None, None, :] * (flare * 1.0)[..., None], 0.0, 1.0)
    rgb = _fill(rgb, _edge(np.sqrt((x - 0.5) ** 2 + (y - lens_y) ** 2) - lens_r * 0.42, soft),
                (1.0, 0.94, 0.94))

    # Vignette. Pulls the eye to the middle and stops the corners competing with
    # the home screen wallpaper behind it.
    vig = 1.0 - 0.5 * np.clip(((x - 0.5) ** 2 + (y - 0.5) ** 2) / 0.30, 0.0, 1.0)
    rgb = np.clip(rgb * vig[..., None], 0.0, 1.0)

    path = ROOT / "icon.png"
    written = write_png(path, rgb)
    print("  %-10s %6.1f KB  (%dx%d, %s)"
          % ("icon", written / 1024.0, size, size, path.name))
    return written


def main():
    pal = load_palette()
    print("palette: %d colours from %s" % (len(pal), PALETTE.name))

    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    print("generating %d surfaces at %dx%d:" % (len(SURFACES), SIZE, SIZE))
    total = sum(build(pal, rng) for build in SURFACES)
    print("app icon:")
    total += build_icon(pal, rng)
    print("total: %.1f KB" % (total / 1024.0))


if __name__ == "__main__":
    main()
