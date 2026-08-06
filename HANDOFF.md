# Handoff

Everything a new session needs to pick this up without re-deriving it.

---

## Where things are

**Development moved to the Mac on 2026-08-04.** This repo is now worked on there
and only there; the Windows PC still holds Jay's other repos but is retired for
this one. The old `D:\Games\LensLethal` path and every PowerShell workaround
below it are gone — don't resurrect them from an older copy of this file.

- **Project:** `/Users/jay/Projects/beach-gas-cellular-warfare` — a real git
  clone. Anything in `~/Downloads` is a stale ZIP; there were six of them, and
  the launcher pointed at a pre-CI one for a day.
- **Repo:** https://github.com/SapphireSignal/beach-gas-cellular-warfare — public
- **Godot:** `/Applications/Godot.app/Contents/MacOS/Godot` (must stay 4.7.1)
- **Open the editor:** `~/Desktop/BeachGas.command`
- **The Mac:** 2017 MacBook Pro, Ventura 13.7.8, Intel Iris Plus 640, Xcode 15.2.
  That Xcode is why the iOS build happens in CI — see below.

## Verifying changes

Nothing ships without these passing. All should exit 0 with no `ERROR` or
`SCRIPT ERROR` lines. Use `--port=` on anything scripted so a test run can't
collide with a game already hosting on the machine — that exact collision once
made every check pass while the game never started.

Set `GODOT=/Applications/Godot.app/Contents/MacOS/Godot` first, then:

```
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --quit-after 1500
"$GODOT" --headless --path . --quit-after 20000 -- --tour
"$GODOT" --headless --path . --quit-after 4000 -- --practice --name=Me --port=27200
"$GODOT" --headless --path . --quit-after 4000 -- --practice --map=level_three --name=Me --port=27202
"$GODOT" --headless --path . --quit-after 4000 -- --practice --map=beach_gas_real --name=Me --port=27204
"$GODOT" --headless --path . --quit-after 3000 -- --shift --name=Me --port=27206
```

Two more that catch things the suite above cannot:

```
"$GODOT" --headless --path . --script res://tools/check_doors.gd
"$GODOT" --headless --path . --script res://tools/check_shots.gd
```

`check_doors` sweeps the player's own capsule through both shop doorways and
names whatever it collides with — both were blocked twice, and eyeballing the
box maths missed it both times. `check_shots` does the same for the menu
backdrop's camera moves against real level collision.

All five verified green on the Mac, 2026-08-04.

Two-instance multiplayer test (this has caught real bugs three times now):

```
--autohost --audit --name=Host --port=27210    # instance 1
--autojoin=127.0.0.1 --name=Guest --port=27210 # instance 2, started ~4s later
```

**Add `--audit` to the host, or this test proves nothing.** Both instances exit
0 whether or not they ever spoke to each other — `join_game()` only returns
false on an immediate socket error, not on a connection that never completes,
and the game prints nothing on a successful join. What *is* proof: the host only
calls `begin_match()` at `players.size() >= 2`, and the world is built on match
start, so audit output means a peer really connected. A passing run ends with
two `AUDIT World | <peer id> | grounded=true` lines — one `1`, one large random
id. One line means the guest never arrived.

CLI flags: `--autohost`, `--autojoin=<ip>`, `--practice`, `--map=<id>`,
`--name=<x>`, `--port=<n>`, `--tour`, `--shots`, `--audit`, `--min-players=<n>`,
`--shift`.

**`--shift` drops straight into the work mode**, and it exists because that mode
shipped to a phone as a grey screen with nothing testable about it. Under
`--shift` it prints `AUDIT Shift | camera current=...`, which is the thing that
was wrong: `player.setup()` makes the camera current only when
`is_multiplayer_authority()`, and a peer left over from a previous match makes
that false — no camera, grey screen, no way to do anything. The shift now
clears any peer and forces the camera on regardless.

**Testing more than two players needs `--min-players`.** Without it `--autohost`
starts the moment the second peer registers, so every later guest joins a match
already running and you are testing late-join, not a four-player game. That is
why this was never tested above two. Four players, all in the lobby first:

```
--autohost --audit --min-players=4 --name=Host --port=27230   # then 3 guests
```

Verified 4/4 in a built world with zero errors, 2026-08-04. Frame numbers from
that run are **not** usable — four engines on one 2017 MacBook contend for CPU,
which is what produced a 135ms worst frame against 19ms for two.

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

`user://` is
`~/Library/Application Support/Godot/app_userdata/Beach Gas- Cellular Warfare/`.

**`--audit` draw numbers are meaningless headless.** No renderer means
`draw_calls=0 objects=0 primitives=0`. The perf table further down was measured
windowed; measure it the same way or don't compare against it.

## Traps that have already bitten

1. **Don't force `--rendering-driver opengl3`.** The default is Vulkan Forward
   Mobile — the same renderer the iOS build ships, so the Mac shows you what the
   phone shows you. `opengl3` drops to OpenGL Compatibility, a different path,
   and it's the one that throws `Texture with GL ID ...: leaked N bytes` on exit.
   The launcher carried this flag for a while; it's been removed.
2. **The first windowed run after a fresh setup blocks on a macOS permission
   dialog.** It looks exactly like a hang — no output, never quits, survives a
   long timeout. It's the audio prompt waiting behind the terminal. Click it.
   Headless runs never hit this, which is why the whole check suite passed
   before anyone noticed.
3. **`timeout` doesn't exist on macOS.** It's `gtimeout`, from `brew install
   coreutils`. A script using bare `timeout` exits 127 and reads as a real
   failure of whatever it wrapped.
4. **`brew install` can exit 0 while installing nothing.** Ventura needs the
   Command Line Tools (`xcode-select --install`) for any formula built from
   source — full Xcode is not enough, Homebrew says so explicitly. Piping brew
   through `tail` hides it, because the pipeline reports `tail`'s status. Check
   the binary exists, not the exit code.
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
8. **The app's version must match what `altstore.json` claims.** AltStore checks
   the installed app against the version its source promised and refuses with
   "doesn't match the specified source" on any mismatch. The export preset left
   `application/short_version` and `application/version` empty, so Godot stamped
   `config/version` (`1.2.0`) while the manifest advertised `1.2.0.<run>`. The
   version is now worked out *before* the preset is written and stamped into
   both fields — **don't move that step back after the export.**

   This survived four releases because a manual sideload skips the check
   entirely, and every install until 2026-08-04 was a manual sideload. **A
   release that installs by sideload proves nothing about the source route.**
9. **`ObjectDB instances were leaked at exit` under `--quit-after` is not a
   bug.** It's 2/4/6 `AudioStreamWAV` + `AudioStreamPlaybackWAV` pairs, one per
   sound that was playing when the engine stopped the process mid-frame, about
   one run in ten. Quits initiated by game code are clean — 0 in 8 runs against
   ~1 in 10 for the flag. The audio thread releases playbacks on its own mix
   cycle and GDScript can't win that race. Already investigated properly once;
   don't spend another hour on it.

## Architecture, briefly

Everything — level, characters, sounds — is generated at runtime. Mobile
renderer (iOS target), so no SSAO, SSIL, SDFGI or volumetric fog, and no custom
shaders anywhere.

**"Zero binary assets" ended on 2026-08-04** and this file said it in three
places. `art/gen` now holds generated PNG textures and the app icon. They are
still *generated* — `tools/gen_art.py` is the source of truth and the PNGs are
build products — but they are committed, because CI has no Python step and the
`.ipa` needs them.

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
   runner (Xcode 26.6, iOS SDK 26.5). It's `workflow_dispatch` only, so it never
   fires on a push — someone has to start it. On github.com: **Actions ▸ Build
   iOS ipa ▸ Run workflow**, then download the `beachgas-ipa` artifact from the
   finished run.

   `gh workflow run build-ios.yml` does the same thing from the terminal.
   **`gh` 2.97.0 is installed and logged in as `SapphireSignal`** (token in the
   macOS keyring, git protocol SSH).

   Note for whoever reinstalls it: **it did not come from Homebrew and can't.**
   Ventura needs the Command Line Tools to build anything from source, full
   Xcode doesn't count, and `brew install gh` exits 0 having installed nothing.
   It's the official prebuilt `gh_<version>_macOS_amd64.zip` from
   `github.com/cli/cli` releases, checksum-verified, dropped in
   `/usr/local/bin`. No compiler needed.
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

Beach Gas has been played on a real iPhone. Everything here comes from those
sessions. Items struck through were done on 2026-08-04/05.

1. ~~**Phone interruptions.**~~ **Done.** A lock or a call suspends the engine,
   the host times the client out, and the client used to land on "The host left
   the game." `net.gd` now remembers what it joined, notices the OS handing the
   app back, and retries for 12s behind a `RECONNECTING` banner. Both cases
   arrive as the same `server_disconnected` signal — the resume grace window is
   the only thing separating them, so don't remove it. **Not yet confirmed on a
   real phone**; it needs a lock mid-match.

2. **Generation still blocks the main thread.** Loading screens now *cover*
   launch, Play and Quit, and warm-ups run behind them (a character is built,
   and the HUD's call overlay is drawn once, so neither costs a frame later).
   **None of that made generation faster** — that is still the real fix, and it
   is spreading `_build_level()` across frames.

   Measured, so don't re-guess: engine + autoloads ~1.3s headless but **~13s
   windowed on the dev Mac**; `Sfx` is only ~11% of it, and this file used to
   imply it was the problem. The menu backdrop was 388ms inside `_ready` and is
   now deferred.

3. ~~**No colour palette.**~~ **Done** — `scripts/palette.gd`. It was 446
   literals across 17 files, not the 5 this file used to claim. `world.gd`,
   `map_level_three.gd` and `phone.gd` are migrated; `character_props.gd` (92),
   `menu.gd` (61), `hud.gd` (56) and `characters.gd` (37) still hold their own.
   **Constraint, still binding:** the red/green/blue of ZAP/TRACK/CALL are
   load-bearing information players read off each other across the lot —
   refine, never re-assign.

4. **Joining a match already in progress is broken.** A guest arriving after
   `begin_match()` gets RPC failures against player nodes that don't exist on
   their end — `Node not found: Main/GameRoot/World/Players/<id>`, then
   `Invalid packet received`. **Four players all in the lobby before the start
   work perfectly** — 4/4 in a built world, zero errors — so this is
   specifically late-join, not player count. Needs the host to hand a late
   joiner the match state and spawn everyone once their world reports ready.
   **Highest-value bug left.**

5. **Art and textures — well started.** `tools/gen_art.py` generates asphalt,
   concrete, wall, curb, metal, rubber and hedge (albedo/normal/roughness,
   512px) plus the app icon, all from `palette.gd`. Deterministic; **never
   hand-edit the outputs, fix the script and rerun.**

   - **Zero binary assets is over**, deliberately. ~9.5 MB imported.
   - Applied with **world-space triplanar**, forced by the merge: after
     `mesh_merge` one material is shared by a 40m forecourt and a 1m crate, so
     no per-object UV scale survives. Costs 3 texture samples per pixel.
   - **The generator writes its own `.import` files.** Godot's defaults are
     wrong twice over — no VRAM compression and no mipmaps, without which the
     forecourt shimmers on every step. Don't let those regenerate as defaults.
   - Still flat: glass, plants, pot, shelf, stock, chrome, signs.

   Still not started: **a title font**, and **real sound** to replace the
   synthesised bank. Sound is the biggest remaining "unfinished" item.

6. ~~**In-match settings button.**~~ **Done** — SETUP in the left column opens
   look speed, aim assist and fire mode. It swallows touches while open, or a
   thumb reaching for a row also reads as a look-drag.

7. ~~**The mobile 8-light cap.**~~ **Done.** Beach Gas placed 12 omni lights
   where the Mobile renderer only lets 8 affect one object — and after
   `mesh_merge` the ground *is* one object, so four were discarded every frame
   and Godot chose which. Now exactly 8. **Emission is free against this cap**,
   so anything that only needs to *look* lit should not be an `OmniLight3D` —
   that is how the Summerleaf purple was kept without a light.

   **Re-judge the ambient level on a phone.** It was lifted from 0.75 to
   compensate for lights that were being thrown away; that reason is gone.

8. **Unconfirmed on a real phone**, all reported by Jay and fixed blind:
   the match-start fps drop, the menu character-pick stutter (not addressed —
   only match spawning was warmed), and a **blue graphical glitch inside the
   gas station** that was never diagnosed. The store has both a transparent
   `glass` material with `CULL_DISABLED` and an emissive `cooler`; bad alpha
   sorting and z-fighting look different and have different fixes, so get a
   description before changing anything.

9. **Phone performance has never actually been measured.** The dev Mac is an
   Intel Iris Plus 640 — every iOS 26 device is far faster, so its frame
   numbers say nothing useful. The game has a **Show FPS** setting; that
   reading is the only real number.

## The human context

Jay plays this with coworkers on shift at a gas station. **All iPhones**, nobody
has Android.

The workflow as of 2026-08-04: he has the 2017 MacBook Pro himself now, and
develops this repo on it — write, run the checks, push, let CI build the `.ipa`,
install through AltStore. The old "iterate on Windows, batch changes, borrow a
Mac occasionally" loop is over, and so is the every-7-days re-signing trip;
AltStore handles renewal as long as AltServer is awake on the same WiFi. His
Windows PC still has his other repos, just not this one. `MAC_SETUP.md`
describes the superseded route — read the CI section above instead.

**The gas station WiFi does have client isolation** — answered on site
2026-08-04, no longer an open question. The Mac was on `BeachGas-Guest`, and a
guest network isolates clients by design. Symptom was AltStore silently failing
to install: it downloads, tries, fails, and the button goes back to `FREE`.

Jay owns the station and **turned isolation off on that SSID**. Verified from
the Mac: a ping sweep of `192.168.2.0/24` went from seeing only the router to
seeing four other hosts. **That toggle is now load-bearing for two separate
things** — AltStore signature renewal *and* the game's own UDP-broadcast LAN
discovery. If someone turns it back on, both break with no error that explains
why. Check it first when "multiplayer stopped working".

Other SSIDs in range: `BeachGas-POS` and `Cameras` (payment and security — keep
off both), `RUT241_D4F6` (a Teltonika router, strong signal; if it's Jay's it is
the travel-router answer already on site), `summerleaf`.

He is not a coder, but his design instincts have been consistently right — he
caught the mobile aiming problem, the spam-fire feel, the damage tuning, the
title overlapping its own subtitle, and the shooting stutter. Explain reasoning;
don't just hand over changes.
