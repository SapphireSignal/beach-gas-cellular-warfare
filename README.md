# Beach Gas: Cellular Warfare

A first-person duel where your phone is the weapon. Up to 8 players over local
WiFi, no internet required.

Built in Godot 4.7.1.

---

## The idea

You're holding a phone, not a gun. It has three apps. There is no ammo —
cooldowns and heat ration everything.

| | Limit | What it does |
|---|---|---|
| **ZAP** | Heat: ~9 shots, then 5 s locked out | 20 damage up close, 13 at max range — five hits kills. Short 0.18 s gap between shots. The beam leaves the phone's camera lens. |
| **TRACK** | 8 s cooldown | Sonar ping. Reveals everyone on your radar for 3 s — **and tells them you scanned them**. |
| **CALL** | 20 s cooldown | Makes their phone ring, anywhere on the map. Walls and distance don't matter, because phone calls don't. For 5 s they move at 45% speed and can't shoot, and ice crusts over them so everyone can see it landed. |

The loop the game is built around is **track → call → zap**: find them, pin
them, finish them.

### The call is the interesting one

When your phone rings you get a choice, and neither option is free:

- **Ride it out** — 4 seconds of being slow and unable to shoot.
- **Answer it** — the ring stops immediately, but you're frozen solid for 1
  second while it connects.

Answering is shorter and more dangerous. That's the whole decision, and it's
what the caller is betting on.

### Things that give you away

- Zapping is loud and positional. People hear where you shot from.
- A ringing phone is audible to everyone nearby, not just the victim.
- Your phone screen glows in the dark and its colour tells people which app
  you're on. Red means someone is holding a laser.
- Scanning tells your targets they've been scanned.

### The map

**Beach Gas** — a gas station at dusk. Store with two entrances and shelf
aisles, a canopy with two pump islands, parked cars, a dumpster corral, and a
pylon sign tall enough to navigate by from anywhere on the lot.

The host picks the map in the lobby. The other slots are listed but locked; the
selection, syncing and preview are already wired up, so adding a real one later
is a scene and a flag in `scripts/maps.gd`.

---

## Playing on the PC

Launch the project in Godot and press play, or run the exported executable.

**Practice vs Bot** gives you a live opponent immediately — it hunts, shoots,
tracks, calls, and answers its phone. Good for learning the controls.

### Desktop controls

| | |
|---|---|
| Move | `W` `A` `S` `D` |
| Look | Mouse |
| Sprint | `Shift` |
| Jump | `Space` |
| Crouch | `Ctrl` (toggle) |
| Zap | Left mouse |
| Track | `Q` |
| Call | `E` |
| Answer | `F` |
| Scoreboard | Hold `Tab` |
| Free the cursor | `Alt` |
| Leave the match | `Esc` |
| Preview the phone layout | `F1` |

### Testing multiplayer with two windows

```bash
BeachGas.exe -- --autohost --name=Host
```

```bash
BeachGas.exe -- --autojoin=127.0.0.1 --name=Guest
```

The host starts the match by itself as soon as somebody joins.
`-- --practice` skips straight into a bot match.

---

## Playing on phones

Everyone must be on the same WiFi. **No internet connection is needed** — the
phones talk directly to each other.

1. One person taps **HOST A GAME**.
2. Everyone else taps **JOIN A GAME** and waits a second. The host's name
   appears in a list. Tap it.
3. Host taps **START MATCH**. First to 8 zaps wins.

If the list stays empty, type the **join code** from the host's lobby screen
(something like `1-42`). Some networks block the broadcast that powers the list
but still allow a direct connection.

If neither works, the network has **client isolation** turned on — it's
deliberately stopping devices from talking to each other. Either get it switched
off, or bring any cheap travel router. It doesn't need internet; it just needs
to make a network.

### Touch controls

- **Left side of the screen** — the stick appears wherever your thumb lands.
  Push it most of the way out to sprint.
- **Right side** — drag to look.
- **Buttons** — ZAP, TRACK, CALL, JUMP, plus SCORE and QUIT under the radar.
- **ANSWER** appears in the middle of the screen while your phone is ringing.

---

## Customising

**CHARACTER** on the main menu — twelve people, each with their own look and a
live 3D turntable showing what they're up to. Your pick is what you see in your
own hands and what everyone else sees walking around. The props they're posing
with (bike, cats, computer, car) are select-screen only.

**SETTINGS** — graphics quality (Low / Good / Awesome), frame rate limit, FPS
counter toggle, master and sound-effect volume, and look sensitivity. Quality
applies live. Phones never get real-time shadows regardless of the setting;
shadow mapping is the most expensive thing on the map by a wide margin.

**PHONE** on the main menu.

- **Case** — eight colours. Everyone can see yours; it's how people tell each
  other apart.
- **HUD theme** — six accent colours for your crosshair, stick and radar. Only
  you see this.

Phone *screen* colours are deliberately fixed. Red/green/blue meaning
zap/track/call is real information you read off other players across the lot,
and making it customisable would quietly delete a mechanic.

---

## Getting it onto an iPhone

See **[MAC_SETUP.md](MAC_SETUP.md)**. Short version: it needs a Mac with Xcode
once, and on a free Apple account the install expires after 7 days.

---

## How it fits together

```
scripts/
  net.gd        autoload. LAN discovery, lobby, and all authoritative match state
  loadout.gd    autoload. Saved name and cosmetics
  sfx.gd        autoload. Every sound, synthesised at load — no audio files ship
  main.gd       root. Swaps between menu and match
  menu.gd       title screen, LAN browser, lobby, customisation
  world.gd      the gas station, generated from code so it's one file to retune
  player.gd     one player body; the same scene runs on every device
  phone.gd      the weapon: zap, track, call
  bot.gd        practice opponent
  hud.gd        in-match UI and all touch routing
  radar.gd      the heartbeat sensor readout
  action_button.gd  round thumb buttons
  beam.gd       laser VFX
```

### Network model

Deliberately simple, because this is a friendly duel between people standing
next to each other.

- **Movement is client authoritative.** You own your own body and tell everyone
  else where it is, so your own movement never rubber-bands.
- **Damage, kills, respawns and score are host authoritative.** Clients *report*
  hits and the host decides whether they count, with light sanity checks on
  range and fire rate.
- Hit detection trusts the shooter, which is what makes shooting feel
  responsive.

### Protocol version

`Net.PROTOCOL_VERSION` is bumped whenever the way devices talk changes — an RPC
signature, a packed flag, a field in the lobby record. Mismatched builds are
detected at join time and told plainly, instead of producing confusing bugs.

It is **not** the app version. Visual changes, sounds, map edits and balance
tweaks don't touch it, and builds either side of such a change play together
fine.
