# Getting Beach Gas onto the iPhones

Everything here happens **once, on a Mac**. After that the app lives on the
phone like any other app until the 7-day signature expires.

---

## The short version

If you just want the steps, they're here. Everything below this section is the
same list again with the reasons, the exact field names, and what to do when
something goes wrong.

**Tonight**

- [ ] Add your friend as a collaborator on the repo (Settings → Collaborators)
- [ ] He installs **Xcode** from the App Store — *start this first, it's ~10GB*
- [ ] He installs **Godot 4.7.1**, then gets the iOS export templates from
      inside it (`Editor → Manage Export Templates`)
- [ ] Find a cable that fits both the iPhone and the Mac

**Tomorrow, on the Mac — about 20 minutes**

1. `git clone https://github.com/SapphireSignal/beach-gas-cellular-warfare.git`
2. Open Godot → **Import** → pick `project.godot` → **Import & Edit**
3. Press **F5**. Does the game run on the Mac? Good — the project is fine.
4. **Project → Export → Add → iOS.** Set Bundle Identifier to
   `com.yourname.beachgas`. Leave Team ID blank.
5. **Export Project…** into a new empty folder.
6. Open the `.xcodeproj` that just appeared.
7. **Signing & Capabilities** → tick *Automatically manage signing* → pick his
   Personal Team.
8. **Info tab** → `+` → add `Privacy - Local Network Usage Description`.
   **Don't skip this one — multiplayer fails silently without it.**
9. Plug the iPhone in, unlock it, tap **Trust**.
10. Pick the phone in Xcode's toolbar dropdown, press **▶**.
11. First launch fails. On the phone:
    `Settings → General → VPN & Device Management → Trust`.
12. Open the game. Tap **Allow** when it asks about the local network.
13. Second phone: repeat 9–12. Nothing else to redo.

**Then test**

- Both phones on the same WiFi
- One taps **HOST A GAME**, the other taps **JOIN A GAME**
- Host's name appears in a list → tap it → **START MATCH**
- List empty? Type the **join code** from the host's screen instead
- Still nothing? The WiFi is blocking device-to-device traffic — see the
  troubleshooting at the bottom

**Later**

- Every 7 days: plug in, press ▶. 30 seconds.
- New version: `git pull`, then redo steps 5 and 10 only.

---

## Tonight — before you turn up

Two of these are large downloads. If they aren't done before you sit down,
tomorrow is a write-off.

**You:**

1. Add your friend as a collaborator on the repo:
   `github.com/SapphireSignal/beach-gas-cellular-warfare` →
   **Settings → Collaborators → Add people**. Without this the repo 404s for him.

**Your friend, on the Mac:**

2. **Xcode**, from the Mac App Store. Around 10 GB and it can take hours. Open it
   once when it finishes and accept the licence agreement — it won't work until
   he does.
3. **Godot 4.7.1**, from https://godotengine.org/download/macos/
   It must be **4.7.1**. A different version may refuse to open the project.
4. **iOS export templates** — open Godot, then
   `Editor ▸ Manage Export Templates… ▸ Download and Install`. About 1 GB.

**Bring:**

- Every phone that wants the game, and their passcodes.
- A cable that fits **both** the iPhone and the Mac. iPhone 15 and newer are
  USB-C; older are Lightning; recent MacBooks are USB-C only. Check this. It is
  the single most common way this day gets wasted.

---

## At the gas station

### 1. Get the project (2 minutes)

```bash
git clone https://github.com/SapphireSignal/beach-gas-cellular-warfare.git
```

### 2. Open it in Godot (2 minutes)

Godot → **Import** → pick `beach-gas-cellular-warfare/project.godot` →
**Import & Edit**. It'll spend a moment building its import cache. That's normal
and only happens once.

Press **F5** to check it runs on the Mac before going anywhere near Xcode. If it
plays there, the project is fine and anything that goes wrong afterwards is an
Apple problem, not a game problem.

### 3. Export to an Xcode project (5 minutes)

`Project ▸ Export… ▸ Add… ▸ iOS`

| Field | What to put |
|---|---|
| **Bundle Identifier** | `com.yourname.beachgas` — lowercase, no spaces, no underscores. Make it unique to you. |
| **App Store Team ID** | Leave blank. Xcode handles signing on a free account. |

Then **Export Project…**, make a *new empty folder* next to the repo (call it
`ios-build`), and export into it.

This does not produce an app. It produces an Xcode project.

> These export settings are saved to `export_presets.cfg`, which is deliberately
> **not** in git — it's local to the Mac. That's what you want: set it up once
> and it survives every future `git pull`.

### 4. Signing (3 minutes)

Open `ios-build/beachgas.xcodeproj`.

Click the blue project icon at the top of the left sidebar → the app target →
**Signing & Capabilities**.

- Tick **Automatically manage signing**.
- **Team**: choose `<his name> (Personal Team)`.
  If the list is empty: `Xcode ▸ Settings ▸ Accounts ▸ +`, sign in with an Apple
  ID. A free one is fine.
- If it says the bundle identifier is unavailable, change it (add a number) and
  try again.

### 5. The local network permission — do not skip this

iOS 14+ blocks apps from talking to other devices on the WiFi unless the app
says why it needs to. **Skip this and the multiplayer silently fails with no
error message.**

Still in Xcode, with the target selected, open the **Info** tab. Hover over any
row, click the small **+**, and add:

- **Key**: `Privacy - Local Network Usage Description`
- **Value**: `Beach Gas uses your local network to find and play with nearby players.`

### 6. Put it on a phone (5 minutes, then 2 per extra phone)

1. Plug the iPhone in. Unlock it. Tap **Trust** when it asks about the computer.
2. In Xcode's toolbar, click the device dropdown and pick the iPhone — **not** a
   simulator.
3. Press **▶**.

The first launch fails with **"Untrusted Developer."** That's expected. On the
phone:

`Settings ▸ General ▸ VPN & Device Management ▸ [the developer entry] ▸ Trust`

Now open Beach Gas from the home screen.

### 7. Allow local network

First time you host or join, iOS asks:

> "Beach Gas" would like to find and connect to devices on your local network.

**Tap Allow.** If someone taps Don't Allow, fix it at
`Settings ▸ Privacy & Security ▸ Local Network`.

### 8. Second phone

Same cable, repeat steps 6 and 7. Xcode installs to several phones in a row
without redoing any setup.

---

## Then actually test it

1. Both phones on the **same WiFi**.
2. One person: **HOST A GAME**.
3. Other person: **JOIN A GAME**, wait a second. The host's name should appear
   in the list. Tap it.
4. Host: **START MATCH**.

**If the list stays empty**, type the **join code** from the host's lobby screen
(something like `1-42`) into the code box. Some networks block the broadcast
that powers the list but still allow a direct connection.

**If neither works**, the WiFi has client isolation turned on — it's
deliberately stopping devices talking to each other. Either get it switched off,
or use any cheap travel router. It doesn't need internet; it just needs to make
a network.

---

## Every 7 days

The signature expires and the app stops opening. Plug the phone into the same
Mac, open the same Xcode project, press **▶**. About 30 seconds per phone.

You don't redo the setup — just the run.

---

## When there's a new version

On the Mac:

```bash
cd beach-gas-cellular-warfare
git pull
```

Then repeat **steps 3 and 6**. Signing and the Info entry are already saved in
the Xcode project, so 4 and 5 are skipped unless you export to a brand new
folder.

Everyone needs the same build. The game checks this and says so plainly if two
phones disagree, rather than misbehaving quietly.

---

## If it goes wrong

**"Could not launch — the app was not signed"**
Signing & Capabilities: make sure a Team is selected and automatic signing is on.

**"Unable to install — bundle identifier is already in use"**
Change the Bundle Identifier in Godot's export settings, re-export, re-open.

**Free accounts allow 10 app IDs per 7 days.**
Pick one bundle identifier and stick to it, or you'll run out.

**App installs but nobody can see anybody**
1. Same WiFi?
2. Did both tap **Allow** on the local network prompt?
3. Try the join code.
4. Still nothing → client isolation. Travel router.
