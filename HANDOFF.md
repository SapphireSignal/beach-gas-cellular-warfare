# Handoff

Everything a new session needs to pick this up without re-deriving it.

---

## Where things are

- **Project:** `D:\Games\LensLethal` (folder name predates the rename)
- **Repo:** https://github.com/SapphireSignal/beach-gas-cellular-warfare — private
- **Godot:** `D:\Godot\Godot_v4.7.1-stable_win64.exe` (must stay 4.7.1)
- **Run it:** `& "D:\Godot\Godot_v4.7.1-stable_win64.exe" --path "D:\Games\LensLethal"`

## Verifying changes

Nothing ships without these passing. All three should exit 0 with no output:

```
Godot_v4.7.1-stable_win64_console.exe --headless --path D:\Games\LensLethal --import
Godot_v4.7.1-stable_win64_console.exe --headless --path D:\Games\LensLethal --quit-after 1500
Godot_v4.7.1-stable_win64_console.exe --headless --path D:\Games\LensLethal --quit-after 1800 -- --practice --name=Me
Godot_v4.7.1-stable_win64_console.exe --headless --path D:\Games\LensLethal --quit-after 1800 -- --practice --map=level_three --name=Me
```

Two-instance multiplayer test (this has caught real bugs twice):

```
--autohost --name=Host        # instance 1
--autojoin=127.0.0.1 --name=Guest   # instance 2
```

CLI flags: `--autohost`, `--autojoin=<ip>`, `--practice`, `--map=<id>`, `--name=<x>`.

## Traps that have already bitten

1. **PowerShell `Set-Content -Encoding utf8` writes a BOM.** Godot's `.tscn`
   parser rejects it outright. Use
   `[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))`.
2. **`[System.IO.File]` ignores `Set-Location`** — it uses the process working
   directory. Always pass absolute paths.
3. **Never pipe `gh`/`git` through `2>&1`.** PowerShell 5.1 turns their normal
   stderr progress output into a failure and reports exit 255 on success.
4. **Commit messages with double quotes break native arg splitting.** Write the
   message to a file and use `git commit -F`.
5. **GDScript type inference:** `var x := <untyped expr>` fails to parse. Use an
   explicit type or leave it untyped. Same for `for x in [floats]` — write
   `for x: float in [...]`.
6. **Server damage bounds must track `phone.gd`.** `Net.MAX_ZAP_DAMAGE` was left
   at a stale value once and silently clamped every hit to a third of its
   damage. Bump `Net.PROTOCOL_VERSION` whenever RPC signatures or packed flags
   change.

## Architecture, briefly

Everything — level, characters, sounds — is generated at runtime. **Zero binary
assets.** Mobile renderer (iOS target), so no SSAO, SSIL, SDFGI or volumetric
fog, and no custom shaders anywhere.

- `net.gd` — autoload. LAN discovery, lobby, host-authoritative damage/score.
- `world.gd` — base for all maps: players, materials, builders, merging.
  Subclasses override `_build_level()`, `spawn_points()`, `wants_traffic()`.
- `map_level_three.gd` — the parking garage. Beach Gas lives in `world.gd`.
- `mesh_merge.gd` — collapses runtime-built geometry. **This is what makes it
  viable on a phone**: world 350+ instances → 49, characters 55 → 14.
- `character_builder.gd` / `_props` / `_rig` — people, their showcase props, and
  two-bone IK posing.
- `phone.gd` — the weapon. Beam fires from the camera lens.
- `hud.gd` — in-match UI *and* all touch routing (one `_input`, explicit hit
  tests — Godot's Control input can't do reliable multitouch).

**Network model:** movement is client-authoritative; damage, kills, respawns and
score are host-authoritative with light sanity checks.

## Current state (v1.1.0)

Two maps, 12 characters, settings, records, changelog, how-to card, practice vs
bot, haptics. All warnings cleared. Verified on PC; **never yet run on a phone.**

## What's next

1. **Phone interruptions.** If a phone locks or a call arrives, Godot pauses and
   the connection times out — you're dumped to the menu. On work phones this
   will happen constantly. Deliberately deferred until after the first hardware
   test. This is the biggest real gap.
2. Whatever the first real phone session turns up — thumb reach, whether the
   garage is too dark on a small screen, whether five-hit kills feel right
   against a moving target.

## The human context

Jay plays this with coworkers on shift at a gas station. **All iPhones**, nobody
has Android. He has no Mac; a friend brings one. On a free Apple account the app
expires every 7 days and needs the physical Mac each time, so the workflow is:
iterate and playtest on the Windows PC, batch changes, and do occasional Mac
sessions. See `MAC_SETUP.md`.

Open question: whether the gas station WiFi has client isolation on. If it does,
LAN discovery fails; fallbacks are the manual join code, then a cheap travel
router.

He is not a coder, but his design instincts have been consistently right —
he caught the mobile aiming problem, the spam-fire feel, and the damage tuning.
Explain reasoning; don't just hand over changes.
