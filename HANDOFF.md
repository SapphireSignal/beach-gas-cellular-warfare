# Handoff

Everything a new session needs to pick this up without re-deriving it.

---

## Where things are

- **Project:** `D:\Games\LensLethal` (folder name predates the rename)
- **Repo:** https://github.com/SapphireSignal/beach-gas-cellular-warfare — private
- **Godot:** `D:\Godot\Godot_v4.7.1-stable_win64_console.exe` (must stay 4.7.1)
- **Run it:** `& "D:\Godot\Godot_v4.7.1-stable_win64.exe" --path "D:\Games\LensLethal"`

## Verifying changes

Nothing ships without these passing. All should exit 0 with no `ERROR` or
`SCRIPT ERROR` lines. Use `--port=` on anything scripted so a test run can't
collide with a game already hosting on the machine — that exact collision once
made every check pass while the game never started.

```
--headless --path . --import
--headless --path . --quit-after 1500
--headless --path . --quit-after 20000 -- --tour
--headless --path . --quit-after 4000 -- --practice --name=Me --port=27200
--headless --path . --quit-after 4000 -- --practice --map=level_three --name=Me --port=27202
```

Two-instance multiplayer test (this has caught real bugs three times now):

```
--autohost --name=Host --port=27210            # instance 1
--autojoin=127.0.0.1 --name=Guest --port=27210 # instance 2, started ~4s later
```

CLI flags: `--autohost`, `--autojoin=<ip>`, `--practice`, `--map=<id>`,
`--name=<x>`, `--port=<n>`, `--tour`, `--shots`, `--audit`.

**`--practice` from the command line now plays the match**, not just the lobby.
It used to stop at the lobby, which meant the "practice" check only ever tested
the menu — no level, no players, no HUD, no bot. Anything relying on it before
v1.2.0 proved much less than it looked like.

**A scripted run that can't start now exits non-zero.** It used to return 0
whichever way it went.

### The three tools worth knowing

- `--tour` walks every menu panel *and* builds all twelve characters, then
  prints `TOUR ok`. Most of this menu is built in code the moment a panel opens,
  so a plain launch proves nothing about the other eight screens.
- `--shots` (with `--tour`, windowed not headless) writes a PNG of every screen
  to `user://`. This is the only way to actually look at the layout without a
  device.
- `--audit` prints what a level costs to build and to draw, including the worst
  frame over 900 frames with the cap and vsync removed. **Average framerate is
  useless here** — it just reports whatever cap is set. The worst frame is the
  number that matches what a hand feels.

`user://` is `%APPDATA%\Godot\app_userdata\Beach Gas- Cellular Warfare\`.

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
7. **Don't `git checkout` a file to undo a temporary experiment** unless you're
   sure nothing else in the working tree depends on it. Doing that mid-session
   reverted a finished fix in `sfx.gd` while `main.gd` still called into it.

## Architecture, briefly

Everything — level, characters, sounds — is generated at runtime. **Zero binary
assets.** Mobile renderer (iOS target), so no SSAO, SSIL, SDFGI or volumetric
fog, and no custom shaders anywhere.

- `net.gd` — autoload. LAN discovery, lobby, host-authoritative damage/score.
- `world.gd` — base for all maps: players, materials, builders, merging.
  Subclasses override `_build_level()`, `spawn_points()`, `wants_traffic()`,
  `_ambient_for()`, `_wants_sun_shadows()`.
- `map_level_three.gd` — the parking garage. Beach Gas lives in `world.gd`.
- `mesh_merge.gd` — collapses runtime-built geometry. **This is what makes it
  viable on a phone.**
- `character_builder.gd` / `_props` / `_rig` — people, their showcase props, and
  two-bone IK posing.
- `phone.gd` — the weapon. Beam fires from the camera lens.
- `hud.gd` — in-match UI *and* all touch routing (one `_input`, explicit hit
  tests — Godot's Control input can't do reliable multitouch).
- `stats.gd` — career totals and the per-character leaderboard, on this device.

**Network model:** movement is client-authoritative; damage, kills, respawns and
score are host-authoritative with light sanity checks.

## Performance: the measured numbers

Taken with `--audit` on this PC. Re-measure rather than assume.

| | Beach Gas | Level 3 |
|---|---|---|
| Mesh instances before merge | 3412 | 596 |
| Draw surfaces after merge | 249 | 219 |
| **Draw calls in frame** | **89** (was 150) | **89** |
| Triangles | 53k | 21k |
| Static bodies | 26 (was 267) | 21 (was 301) |
| Omni lights | 13 | 7 |

Triangles are a non-issue at this scale. Draw calls and per-shot allocation are
the things that matter.

### Two findings worth not re-deriving

1. **Splitting the merge into spatial cells makes it worse.** Tried 12m, 18m,
   24m and 40m grids so chunks could be frustum-culled separately: draw calls
   went from 150 up to between 168 and 224 on both maps and never once came
   down. Neither level has anything to cull against — the forecourt is one open
   sightline and the garage's pillars are too small to hide a chunk behind. One
   mesh per material is correct here.

2. **The Mobile renderer only lets eight omni lights affect any one object.**
   Beach Gas places twelve, against meshes that span the whole level, so four of
   its lamps contribute nothing to the ground. This is almost certainly why the
   lot edges read dark and why ambient got raised to compensate. Fixing it
   properly means removing lamps, which is a look decision — flagged, not done.
   `--audit` warns when a level goes over eight.

## Current state (v1.2.0)

Two maps, 12 characters, settings, leaderboard, career, changelog, how-to card,
practice vs bot, haptics. All warnings cleared. Verified on PC including the
two-instance test; **never yet run on a phone.**

Fixed this pass: the sound pool being deleted with the level, the settings-change
lighting regression, the spawn deadlock on a mid-load disconnect, frozen bots for
practice guests, and the frame cap being ignored at startup on mobile.

## What's next

1. **Phone interruptions.** If a phone locks or a call arrives, Godot pauses and
   the connection times out — you're dumped to the menu. On work phones this
   will happen constantly. Still the biggest real gap, still deliberately
   deferred until after the first hardware test.
2. **Whatever the first phone session turns up.** Thumb reach, whether the
   garage is too dark on a small screen, whether five-hit kills feel right
   against a moving target, and whether shooting still stutters — Jay reported
   it on PC, and the two per-shot costs found (the error-throwing sound pool and
   per-shot particle node creation) are both fixed, but it has not been
   confirmed in his hands yet.
3. **Physics runs at 120Hz.** Halving it to 60 is the single largest remaining
   CPU saving on a phone and it is one line in `project.godot`. Not done,
   because it changes movement feel and doing that immediately before a first
   hardware test would confuse the results.

## The human context

Jay plays this with coworkers on shift at a gas station. **All iPhones**, nobody
has Android. He has no Mac; a friend brings one. On a free Apple account the app
expires every 7 days and needs the physical Mac each time, so the workflow is:
iterate and playtest on the Windows PC, batch changes, and do occasional Mac
sessions. See `MAC_SETUP.md`.

Open question: whether the gas station WiFi has client isolation on. If it does,
LAN discovery fails; fallbacks are the manual join code, then a cheap travel
router.

He is not a coder, but his design instincts have been consistently right — he
caught the mobile aiming problem, the spam-fire feel, the damage tuning, the
title overlapping its own subtitle, and the shooting stutter. Explain reasoning;
don't just hand over changes.
