# Handoff

Everything a new session needs to pick this up without re-deriving it.

---

## Where things are

- **Project:** `D:\Games\LensLethal` (folder name predates the rename; renaming it
  is safe and unrelated to anything else — the repo and the game are already
  Beach Gas)
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
8. **`ObjectDB instances were leaked at exit` under `--quit-after` is not a
   bug.** It's 2/4/6 `AudioStreamWAV` + `AudioStreamPlaybackWAV` pairs, one per
   sound that was playing when the engine stopped the process mid-frame, about
   one run in ten. Quits initiated by game code are clean — 0 in 8 runs against
   ~1 in 10 for the flag. The audio thread releases playbacks on its own mix
   cycle and GDScript can't win that race. Already investigated properly once;
   don't spend another hour on it.

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

## Current state

Two maps, 12 characters, settings, leaderboard, career, changelog, how-to card,
practice vs bot, haptics. `project.godot` still says **1.2.0**; the CI build
appends the run number on top of it, so releases read `1.2.0.<n>`.

**It has now been played on a real iPhone** (2026-08-04) — that sentence used to
say the opposite, and everything in "What's next" comes from that session.

Changed since 1.2.0, all verified with the full check suite:

- Physics **120Hz → 60**. The largest CPU saving available on a phone.
- **Aim assist**, reported as snapping away. Two causes: it pulled during an
  active drag, fighting the player for their own camera; and its strength curve
  was inverted against its own comment — weakest at the cone edge where help is
  wanted, strongest dead-centre where it just grabs.
- **HUD**: radar top-left and larger, SCORE/QUIT to the left column, CALL and
  JUMP lowered to be reachable.
- **Safe area** honoured, so nothing sits under the notch or home indicator.
- **Death screen** drew two stacked full-screen alpha rects per frame; now one.
- Jay's cigarette bags → a **slushy machine**; Josh's → **baggies and a bird**
  the rig keeps alive.
- Two GDScript warnings cleared, and Josh's blurb spelled out.

## How updates reach the phones

The whole loop, end to end:

```
push  →  GitHub Actions builds the .ipa  →  cuts a release  →
regenerates altstore.json  →  AltStore shows Update  →  they tap it
```

- **Source URL** (public, no auth):
  `https://raw.githubusercontent.com/SapphireSignal/beach-gas-cellular-warfare/main/altstore.json`
- Each phone adds that source **once**, in AltStore → Browse → `+`. After that
  it's the Update button forever.
- **AltServer must be reachable** — Mac awake, on the same WiFi — because
  AltStore does not sign apps itself. This is the one condition that free
  provisioning cannot remove; only a paid account with TestFlight does.
- Cables are needed **once per phone**, to install AltStore itself. Never again.
- Every build appends the run number to the version. Without that AltStore sees
  the same `1.2.0` it already has and offers nothing.
- Builds are **serialised** (`concurrency: ios-build`). Two at once each cut a
  release and then race to commit the manifest, leaving it pointing at whichever
  finished first rather than the newest code. That happened once; don't undo it.

**All eight of Jay's repos are public** as of 2026-08-04, with secret scanning
and push protection enabled. Public was needed for AltStore to fetch releases
without auth, and it removes the Actions minutes ceiling (macOS runners bill at
10× against the private-repo quota).

## How it gets onto a phone — READ THIS BEFORE MAC_SETUP.md

**`MAC_SETUP.md` describes a route that no longer works.** Jay's only Mac is a
2017 MacBook Pro, capped at Ventura, capped at Xcode 15.2 and the iOS 17.2 SDK.
Godot 4.7.1's iOS export template is precompiled against the **iOS 26 SDK** and
references `MTLTensor`, `MTLResidencySetDescriptor` and
`NSProcessPerformanceProfile*`. It cannot be linked by that Xcode. No flag fixes
it. **Always check Godot's template SDK requirement before choosing an Xcode.**

The working route, proven 2026-08-04:

1. **`.github/workflows/build-ios.yml`** builds the `.ipa` on the **`macos-26`**
   runner (Xcode 26.6, iOS SDK 26.5). Trigger with
   `gh workflow run build-ios.yml`, then download the `beachgas-ipa` artifact.
2. **AltStore** installs it. AltServer runs on the 2017 MacBook — which is fine,
   because signing and installing don't need a modern Xcode. Confirmed working
   on a work iPhone running **iOS 26.5.2**.

Three things that make the workflow work, and will silently break it if changed:

- It builds **unsigned** (`CODE_SIGNING_ALLOWED=NO`). AltStore re-signs on
  install, so no certificates or secrets belong in this repo.
- Godot's export runs `xcodebuild` itself and fails with no certificate present.
  That failure is expected and tolerated; we build the generated `.xcodeproj`
  ourselves in a later step.
- Godot writes `additional_plist_content` into the **entitlements** file, not
  Info.plist. That breaks signing *and* drops
  `NSLocalNetworkUsageDescription`, which silently kills all multiplayer with no
  error. The workflow patches Info.plist with PlistBuddy after export. **Verify
  that key is in any `.ipa` before shipping it.**

## What's next

Beach Gas has now been played on a real iPhone (2026-08-04). Everything below
comes from that session.

1. **Phone interruptions.** A lock or an incoming call pauses Godot and the
   connection times out — you're dumped to the menu. On work phones this will
   happen constantly. **Still the biggest real gap.**
2. **Everything is generated at runtime, and generation blocks the main
   thread.** This is the cause of all three freezes Jay reported: ~5s grey
   screen at launch (engine boot, `Sfx` synthesising every sound, menu build), a
   couple of seconds on Play/Quit (level generation), and an fps drop when
   picking a character (that character being built on tap). Fix shape is the
   same each time: spread the work across frames and draw a progress screen.
3. **No colour palette.** Colours are scattered as literals across `world.gd`,
   `character_props.gd`, `hud.gd`, `phone.gd` and `characters.gd`. A palette file
   would be the entire art direction in one place. **Constraint:** the
   red/green/blue of ZAP/TRACK/CALL are load-bearing information players read
   off each other across the lot — refine, never re-assign.
4. **Safe area.** iPhone notch and home indicator aren't accounted for
   (`DisplayServer.get_display_safe_area()`). The radar now sits top-left, which
   in landscape is where the notch is.
5. **A real app icon.** Currently whatever Godot generates from `icon.svg`.
6. **Approved but not started:** a title font, art and textures, and real sound
   to replace the synthesised bank. All would be the project's first binary
   assets — worth knowing that "zero binary assets" is why the repo is 416 KB
   and why the CI build is as simple as it is.
7. **In-match settings button**, left side. Requested; settings currently only
   exist in the menu.

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
