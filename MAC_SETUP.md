# Getting Lens Lethal onto the iPhones

Everything here happens **once, on a Mac**. After this, the app lives on the
phone like any other app until the 7-day signature expires.

---

## Do this the night before

Whoever owns the Mac should have all of this finished *before* you sit down,
because two of them are big downloads.

1. **Xcode** — Mac App Store, free, roughly 10 GB. This is the slow one; it can
   take hours. Open it once after installing and accept the license agreement.
2. **Godot 4.7.1** — https://godotengine.org/download/macos/
   It must be **4.7.1**, the same version the project was built with. A different
   version may refuse to open it or behave oddly.
3. **iOS export templates** — open Godot, then
   `Editor ▸ Manage Export Templates… ▸ Download and Install` (about 1 GB).

Also bring:

- The `LensLethal` project folder (USB stick, AirDrop, Google Drive — anything).
- A cable that fits **both** the iPhone and the Mac.
  iPhone 15 and newer are USB-C; older phones are Lightning. Newer MacBooks are
  USB-C only. Check this — it is the single most common way this day gets ruined.
- Every phone that wants the game, and their passcodes.

---

## On the Mac

### 1. Open the project

Copy the `LensLethal` folder onto the Mac. Open Godot, click **Import**, choose
`LensLethal/project.godot`, then **Import & Edit**.

### 2. Export to an Xcode project

`Project ▸ Export… ▸ Add… ▸ iOS`

Fill in:

| Field | What to put |
|---|---|
| **Bundle Identifier** | `com.yourname.lenslethal` — lowercase, no spaces, no underscores. Make it unique to you. |
| **App Store Team ID** | Leave blank. Xcode handles signing on a free account. |
| **Signing ▸ Code Sign** | Leave at the default. |

Then **Export Project…**, make a *new empty folder* (call it `ios-build`), and
export into it. This does not produce an app — it produces an Xcode project.

### 3. Open it in Xcode

Open `ios-build/LensLethal.xcodeproj`.

### 4. Set up signing

Click the blue project icon at the top of the left sidebar, then the
**LensLethal** target, then the **Signing & Capabilities** tab.

- Tick **Automatically manage signing**.
- **Team**: pick `<name> (Personal Team)`.
  If nothing is listed: `Xcode ▸ Settings ▸ Accounts ▸ +` and sign in with an
  Apple ID. A free one is fine.
- If it complains the bundle identifier is unavailable, change it to something
  more unique (add a number) and try again.

### 5. Add the local network permission — do not skip this

iOS 14 and later blocks apps from talking to other devices on the WiFi unless
the app declares why it needs to. **Without this the multiplayer will silently
fail and you will have no idea why.**

In Xcode, with the target still selected, open the **Info** tab. Hover over any
row, click the small **+**, and add:

- **Key**: `Privacy - Local Network Usage Description`
- **Value**: `Lens Lethal uses your local network to find and play with nearby players.`

### 6. Install onto a phone

1. Plug the iPhone in. Unlock it. Tap **Trust** when it asks about the computer.
2. In the toolbar at the top of Xcode, click the device dropdown and pick the
   iPhone (not a simulator).
3. Press the **▶** button.

The first launch will fail with **"Untrusted Developer."** That's expected. On
the phone:

`Settings ▸ General ▸ VPN & Device Management ▸ [the developer entry] ▸ Trust`

Now open Lens Lethal from the home screen.

### 7. Allow local network access

The first time you host or join, iOS will ask:

> "Lens Lethal" would like to find and connect to devices on your local network.

**Tap Allow.** If someone taps Don't Allow by accident, fix it at
`Settings ▸ Privacy & Security ▸ Local Network`.

### 8. Repeat for the other phones

Same cable, same steps 6 and 7. The Mac can install to several phones in a row.

---

## Every 7 days

The signature expires and the app stops opening. Plug the phone into the same
Mac, open the same Xcode project, press **▶**. About 30 seconds per phone.

Nothing else changes — you don't redo the setup, just the run.

---

## When you want a new version

I rebuild the project on the PC and you repeat **steps 1, 2 and 6** with the
updated folder. Signing and the Info entry are already saved in the Xcode
project, so you can skip 4 and 5 unless you started a fresh export folder.

Everyone needs the same build. The game checks this and will tell you plainly if
two phones disagree, rather than misbehaving quietly.

---

## If it goes wrong

**"Could not launch — the app was not signed"**
Signing & Capabilities, make sure a Team is selected and "Automatically manage
signing" is ticked.

**"Unable to install — bundle identifier is already in use"**
Change the Bundle Identifier in Godot's export settings, re-export, and re-open.

**Free accounts are limited to 10 app IDs per 7 days.**
If you re-export with a new bundle ID repeatedly you can run out. Pick one
identifier and keep it.

**App installs but nobody can see anybody**
1. Are both phones on the same WiFi?
2. Did both tap **Allow** on the local network prompt?
3. If the host's name doesn't appear in the list, try the **join code** shown on
   the host's lobby screen. Some networks block the "I'm hosting" broadcast but
   still allow a direct connection.
4. If neither works, the network has client isolation switched on. Either get it
   turned off, or use any cheap travel router — it doesn't even need to be
   plugged into the internet, it just needs to make a network.
