# macOS laptop migration guide (manual, no Migration Assistant)

A guide for moving a macOS user environment to a new Mac by hand. It grew out of a real corporate
laptop refresh in July 2026 (§1). **Old Mac** = the machine you are leaving, **new Mac** = the
replacement.

The work is a sequence of numbered step scripts in `bin/`. Each script says what it will do and asks
before doing it; this guide holds the reasons, the nuances and the troubleshooting. Facts and
decisions about one particular machine live in [LOCAL.md](LOCAL.md).

Contents

1. [Background: what went wrong in July 2026](#1-background-what-went-wrong-in-july-2026)
2. [How each kind of state migrates](#2-how-each-kind-of-state-migrates)
3. [How the process is organised](#3-how-the-process-is-organised)
4. [Run sheet](#4-run-sheet)
5. [Phase 1 – Old Mac: prepare and snapshot](#5-phase-1--old-mac-prepare-and-snapshot)
6. [Phase 2 – Handover](#6-phase-2--handover)
7. [Phase 3 – Homebrew and home directory](#7-phase-3--homebrew-and-home-directory)
8. [Phase 4 – Applications](#8-phase-4--applications)
9. [Phase 5 – Settings](#9-phase-5--settings)
10. [Phase 6 – Permissions, sign-ins, hardware settings](#10-phase-6--permissions-sign-ins-hardware-settings)
11. [Phase 7 – Verify and clean up](#11-phase-7--verify-and-clean-up)
12. [Troubleshooting](#12-troubleshooting)
13. [Tools](#13-tools)
14. [What was tested](#14-what-was-tested)

---

## 1. Background: what went wrong in July 2026

A corporate MacBook refresh. Apple's Migration Assistant could not be used because of corporate
software, so the transfer was done by hand: Homebrew via Brewfile or prefix copy, `rsync` of the home
directory, `rsync` of a subset of `~/Library`, the old Mac logged out and reached over SSH.

| Symptom on the new Mac | Root cause | Fix used then |
|---|---|---|
| Ice did not compact menu bar icons | `NSStatusItemSpacing` / `NSStatusItemSelectionPadding` live in per-host prefs (`ByHost`), which were skipped | `defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6` (same for `…SelectionPadding`), re-login |
| Menu bar icon order scrambled | `NSStatusItem Preferred Position *` keys are read only when an item is created; apps that ran before the plists landed overwrote them | ⌘-drag icons by hand |
| System keyboard shortcuts lost | `com.apple.symbolichotkeys.plist` was a 734-byte stub rewritten by the live session (cfprefsd clobber) | re-pull `com.apple.symbolichotkeys.plist` + `pbs.plist`, `killall cfprefsd`, re-login |
| Slack showed no notifications | migrated `com.apple.ncprefs.plist` disagreed with `usernoted`'s per-machine DB (`~/Library/Group Containers/group.com.apple.usernoted/db2/db`): no prompt, no entry in Settings, no delivery | delete the app's records from **both** stores, relaunch, answer the prompt |
| Same for six more apps | same | same, scripted |
| Ice "search menu" empty | Screen Recording permission (TCC) never migrates | grant in Privacy & Security |

Lessons built into the steps:

1. Copy `~/Library` into the live account only while that account is **not logged in at the console**
   (stage first, apply over SSH). Removes the cfprefsd clobber and the status-item overwrite.
2. Do not migrate `com.apple.ncprefs.plist`. Let every app re-register for notifications.
3. Migrate per-host prefs explicitly with `defaults -currentHost export/import` (handles the
   hardware-UUID rename).
4. Install apps before settings, but do not launch them before settings are in place.
5. TCC permissions, login-item registrations and keychain-backed logins never migrate – they get
   guided manual steps.
6. Snapshot the old Mac in machine-readable form so the result can be diffed afterwards.

---

## 2. How each kind of state migrates

| State | Mechanism | Step | Automated |
|---|---|---|---|
| Homebrew formulae | tar-pipe of `/opt/homebrew` (minus `Caskroom`), or clean install + Brewfile | 310a / 310b | yes |
| Casks, VS Code extensions, Go and npm packages | `brew bundle` from the snapshot's `Brewfile` | 410 | yes (sudo prompts) |
| Hand-installed apps | `conf/Brewfile.extra`, or bundle copy with `copy-apps.sh` | 410, 420 | yes |
| App Store apps | App Store / `xcodes` | 420 | no – sign-in needed |
| MDM and security agents, Self Service | pushed by MDM | – | never copy |
| Home directory: code, dotfiles, `~/bin`, `~/.local`, toolchains, credential files | rsync | 320 | yes |
| App and UI settings (`~/Library/Preferences`, `Application Support`, …) | rsync to a staging area, applied while logged out | 510, 520 | yes |
| Per-host prefs (menu bar spacing, modifier-key remaps, trackpad, Control Center) | `defaults -currentHost export` / `import` | 130, 530 | yes |
| Login items | System Events | 130, 530 | yes (one Automation prompt) |
| User LaunchAgents (`com.user.*`) | part of the `~/Library` copy; loaded at login | 520 | yes |
| Menu bar icon order | plists in place before first login; `statusitems.sh` as repair | 520 | mostly |
| Keyboard shortcuts | plists, plus backup exports in the snapshot | 520 | yes |
| Notification permissions | not migrated; apps re-prompt | 610 | no – click Allow |
| Privacy permissions (TCC) | not migratable; panes opened with the old Mac's app list | 610 | guided |
| Keychain (SSO sessions, Wi-Fi, app tokens) | not migrated; optional session-key transfer | 145, 515, 620 | partly |
| `/etc/profile`, login shell, power settings | from the snapshot, with `sudo` | 210, 330, 630 | yes |
| Display arrangement, Touch ID, Wi-Fi, Bluetooth pairings, FileVault | hardware / Secure Enclave bound | 630 | no |

The single most important invariant: **same short user name and home path** (`/Users/$USER`) on
both Macs. Virtualenvs, git worktrees, Claude Code project history, LaunchAgents and many plists embed
absolute paths. Step 210 checks it.

---

## 3. How the process is organised

**Steps.** Every file in `bin/` whose name starts with a number is a step:
`{number}-{OLD|NEW}-{name}.sh`. The three-digit numbers give one execution order across both Macs
(a plain `ls bin/` shows it); the hundreds digit is the phase (§4). Run the files in that order, each
on the Mac named in its file name – the sequence switches between the Macs during the handover.
`bin/steps.sh` prints the list. Each step

- prints what it is about to do and asks `Proceed? [y/N]` (automated steps), or prints instructions
  and waits for Enter (steps marked *manual*);
- refuses to run on the wrong Mac. `110-OLD-prepare.sh` records the old Mac's hardware UUID in
  `conf/kit.local.conf`; OLD steps run only there, NEW steps only elsewhere;
- runs checks where the result can be tested, and stops if one fails;
- ends by naming the next step.

Flags: `-n` / `--dry-run` prints what the step would do and exits without changing anything (works on
either Mac, useful for reading ahead); `-y` / `--yes` skips the prompts.

**Alternatives** share a number and differ by a letter: `310a-…` and `310b-…`. Run exactly one; `a`
is the recommended one. Each script stays linear – the choice is made by picking the file.

**Optional steps** have "Optional:" in their title and sit between the tens (145, 515). Skipping
them never breaks a later step.

**Tools** are the files in `bin/` without a number (§13). Steps call some of them; the others are for
repairs.

**Scripts versus this guide.** The scripts are the authority on *what to do*: short and
action-oriented. This guide is the authority on *why*, on what can go wrong, and on how to fix it.
Every step has a section here with the same number (`bin/steps.sh --check` verifies the two stay in
sync).

**`LOCAL.md` is called like a subroutine.** Where a step needs machine-specific input, the script and
this guide say "→ LOCAL.md, section Lx". Go there, do what the section says, and come back to the
step named in its "Return to" line. `LOCAL.md` consists of hand-written sections L1 – L6 and a
generated inventory; its first section explains how to produce it for another machine (by a person
or an LLM agent).

**Data** lives outside the repository in `~/migrate`: `state/` (snapshot of the old Mac),
`inventory/` (snapshot used for `LOCAL.md`), `stage/` (staged `~/Library`), `backup-*/`,
`state-new/` (verification snapshot). It contains tokens; never commit or upload it.

---

## 4. Run sheet

| Step | Mac | Kind | What |
|---|---|---|---|
| **Phase 1** | | | **Old Mac: prepare and snapshot** |
| 110 | OLD | auto + manual | record the old Mac, install GNU rsync, enable Remote Login and Full Disk Access |
| 120 | OLD | auto | inventory → `LOCAL.md`; then work through LOCAL.md L1 – L3 |
| 130 | OLD | auto | snapshot into `~/migrate/state` |
| 140 | OLD | manual | exports that file copies cannot carry |
| 145 | OLD | auto, optional | export browser/Electron session keys |
| 150 | OLD | manual | first boot of the new Mac; bootstrap commands to type there |
| **Phase 2** | | | **Handover** |
| 210 | NEW | auto + manual | Rosetta, login shell, remote access; identity and SSH checks |
| 220 | OLD | auto + manual | final snapshot, quit apps, log out |
| 230 | NEW | auto | fetch the final snapshot (checks the old Mac is logged out) |
| **Phase 3** | | | **Homebrew and home directory** |
| 310a | NEW | auto | Homebrew: copy the prefix (recommended) |
| 310b | NEW | auto | Homebrew: clean install (alternative) |
| 320 | NEW | auto | pull the home directory |
| 330 | NEW | auto | restore `/etc/profile` |
| **Phase 4** | | | **Applications** |
| 410 | NEW | auto | `brew bundle`: casks and the rest |
| 420 | NEW | manual | remaining apps → LOCAL.md L2. Launch nothing |
| **Phase 5** | | | **Settings** |
| 510 | NEW | auto | stage the `~/Library` subset |
| 515 | NEW | auto, optional | import session keys |
| 520 | NEW | auto, over SSH | apply the staged `~/Library` while logged out |
| 530 | NEW | auto | per-host prefs, login items; then log out and in |
| **Phase 6** | | | **Permissions, sign-ins, hardware settings** |
| 610 | NEW | manual, guided | privacy permissions, notifications |
| 620 | NEW | manual | sign-ins → LOCAL.md L4 |
| 630 | NEW | auto + manual | power settings; hardware-bound settings → LOCAL.md L5 |
| **Phase 7** | | | **Verify and clean up** |
| 710 | NEW | auto | verify against the snapshot |
| 720 | NEW | manual | cleanup → LOCAL.md L6 |

Hardware: a real Thunderbolt/USB4 cable (charging-only USB-C cables carry no data at speed), both
Macs on AC power.

---

## 5. Phase 1 – Old Mac: prepare and snapshot

### Step 110 (OLD) – Prepare the old Mac

`bin/110-OLD-prepare.sh`

- Writes `OLD_UUID` and `OLD_HOST` into `conf/kit.local.conf` (untracked; other lines in it are
  kept). This is what later lets every step tell the two Macs apart. Running it on a Mac that was
  itself migrated to earlier simply re-records that Mac as the new starting point.
- Installs GNU rsync 3.x. macOS ships `openrsync`, which lacks what the copies need: `-X` (extended
  attributes, so Finder tags survive), `-N` (creation times) and the filter syntax in
  `conf/library-rules.txt`.
- Manual part, System Settings:
  - General → Sharing → **Remote Login** on; ⓘ → access for your user only, and
    **"Allow full disk access for remote users"** on. Without the latter, rsync over SSH gets
    `Operation not permitted` on `~/Desktop`, `~/Documents`, `~/Downloads` and parts of `~/Library`.
  - Privacy & Security → **Full Disk Access** for the terminal app; restart the terminal. Needed
    for the privacy-grant report in the snapshot.

Optional: `brew install mas` and sign in to the App Store, so the Brewfile records App Store apps.

### Step 120 (OLD) – Inventory this Mac into LOCAL.md

`bin/120-OLD-inventory.sh` (`--no-sizes` skips the slow disk-usage pass)

Regenerates the inventory block of `LOCAL.md` from a fresh snapshot in `~/migrate/inventory`:
hardware, disk usage, Homebrew, apps by origin, MDM agents, toolchains, login items, settings,
credential files, and a "Checks" list of problems. The user name, home path and host name are
replaced by `$USER`, `~` and `$HOSTNAME`; set `REDACT='regex'` in `conf/kit.local.conf` to blank out
anything else (an employer name, for instance).

**→ LOCAL.md, "How to produce this file", then sections L1 – L3.** They turn the inventory into
actions: what to fix on this Mac (L1), where each hand-installed app will come from (L2), which
bulky data to leave behind (L3). Apply the resulting changes to `conf/excludes-home.txt`,
`conf/library-rules.txt` and `conf/Brewfile.extra`. Return here and continue with step 130.

Why review the three `conf/` files: they encode decisions for one machine. `library-rules.txt` lists
the MDM agents to keep out, the caches to skip and the sandboxed apps worth staging;
`excludes-home.txt` the regenerable caches and optional bulky directories; `Brewfile.extra` the
hand-installed apps that have a cask.

### Step 130 (OLD) – Snapshot the old Mac

`bin/130-OLD-capture.sh` – run in a GUI session (System Events and the keychain need one). Read-only
apart from writing `~/migrate/state/`:

| File | Content |
|---|---|
| `system.txt` | OS, host, user, login shell |
| `brew/Brewfile` | taps, formulae, casks, VS Code extensions, Go and npm packages (+ `mas` entries if `mas` is installed) |
| `brew/leaves.txt`, `formulae.txt`, `casks.txt`, `taps.txt`, `services.txt` | reference lists |
| `apps/applications.txt`, `user-applications.txt`, `manual-apps.txt` | all apps; apps that are neither cask nor App Store |
| `apps/login-items.txt`, `launchagents-user.txt`, `launchd-system.txt` | login items and launchd jobs |
| `apps/*-extensions.txt` | editor extension lists |
| `toolchains.txt` | npm/pipx/uv/cargo/rustup/go/gh-extension inventories |
| `byhost/*.plist` | every per-host preference domain, exported with `defaults -currentHost export` |
| `defaults/*.plist` | backup exports: symbolic hotkeys, `pbs`, global domain, Dock, Finder, input sources, Control Center, screenshots, trackpad |
| `statusitems.tsv` | every `NSStatusItem …` key (menu bar positions/visibility) per domain |
| `notifications.tsv` | apps with notification settings (reference for re-toggling) |
| `tcc-user.txt`, `tcc-system.txt` | privacy grants (`auth_value` 2 = allowed); drives step 610 |
| `etc/` | `/etc/profile`, `paths`, `paths.d`, `hosts`, `pmset`, printers, network services, Wi-Fi list, crontab |

The step fails its check if the privacy grants are empty – that means the terminal still lacks Full
Disk Access.

### Step 140 (OLD) – Export app data that a file copy cannot carry

`bin/140-OLD-app-exports.sh` (manual)

Some apps keep data encrypted with a keychain key, or in a form that only their own export handles:

- **Raycast**: "Export Settings & Data" → `.rayconfig`. Its database is keychain-encrypted, so the
  copied files alone are useless.
- **BetterTouchTool**: Presets → Export (belt and braces; the data store is copied anyway).
- **iStat Menus / Bartender / Rectangle**: Settings → Export, if you rely on them.
- License keys: make sure they are reachable (a password-manager database in the home directory
  travels with it).

Save exports under `~/migrate/`. **→ LOCAL.md L1** lists the machine-specific ones.

### Step 145 (OLD) – Optional: export session keys

`bin/145-OLD-session-keys.sh`

Chromium browsers and Electron apps encrypt cookies and saved logins with a per-app key stored in the
login keychain as "*App* Safe Storage". Profiles are copied in step 510, but without the key they are
unreadable: you are logged out of every site and workspace. This step exports those keys to
`~/migrate/state/safe-storage.tsv`; step 515 imports them. Expect one keychain password prompt per
item.

Trade-off: the file is as sensitive as the sessions it unlocks. Skip the step to sign in again
everywhere instead (browser sync restores most of it). Not exercised in the July migration – verify
with one app before relying on it.

### Step 150 (OLD) – Hand over to the new Mac

`bin/150-OLD-handover.sh` (manual) prints, with this Mac's names filled in:

1. The first-boot checklist for the new Mac:
   - Setup Assistant: **skip** Migration Assistant / "Transfer your data".
   - Complete corporate enrolment. The account must come out with the same short name and home
     (`$USER`, `/Users/$USER`). If it differs, stop and get IT to fix it.
   - Use the same login password as on the old Mac if policy allows.
   - Wait for MDM to install its agents; re-enrol the SSO authenticator now – everything else
     behind SSO depends on it and its keys are device-bound.
   - Install pending macOS updates so both Macs run the same major version (Homebrew bottles are
     per-OS; otherwise prefer 310b).
   - Customise nothing yet – copied settings will overwrite it.
2. The bootstrap commands to type on the new Mac: install the Command Line Tools, copy this
   repository (including `conf/kit.local.conf`) and the snapshot, start step 210.

Connecting: plug in the Thunderbolt cable; both Macs get a `169.254.x.x` address on "Thunderbolt
Bridge" (`ipconfig getifaddr bridge0`). The `.local` name normally resolves over it. If SSH is
refused or hangs: check Remote Login on the old Mac, use the `169.254` address (and put it into
`OLD_HOST` in `conf/kit.local.conf` on the new Mac), and if the VPN client interferes pause it for the
duration, policy permitting.

Keep the old Mac logged in until step 210 has passed on the new Mac: its last check proves that SSH
works before you lock yourself out of the GUI.

---

## 6. Phase 2 – Handover

This phase alternates between the Macs: 210 on the new one, 220 on the old one, 230 on the new one.
The order matters – 210 proves SSH access while the old Mac is still usable, 220 freezes it, and 230
refuses to copy unless the old Mac is logged out.

All later scripts share one multiplexed SSH connection (`ControlPersist`), so the old Mac's password
is asked once. Long copies run under `caffeinate`.

### Step 210 (NEW) – Prepare the new Mac

`bin/210-NEW-prepare.sh`

Installs Rosetta (x86 apps such as Wine need it), creates `~/.ssh`, sets the login shell to the old
Mac's (`chsh` asks for the password). Manual part: Remote Login with "Allow full disk access for
remote users", and Full Disk Access for the terminal – same as step 110, here needed for the pulls and
for step 520.

Checks: same user name and home path as in the snapshot, Command Line Tools present, Remote Login on,
Full Disk Access, and the old Mac answering over SSH. It also prints both macOS versions.

### Step 220 (OLD) – Freeze the old Mac

`bin/220-OLD-freeze.sh` takes the final snapshot, then tells you to quit all apps and **log out**.

- Logging out is what guarantees that every app has quit and `cfprefsd` has flushed all preference
  plists to disk. SSH keeps working at the login window.
- Do **not** restart or shut down: with FileVault, SSH is unavailable until someone unlocks the disk
  at the console.
- Leave the Mac on AC power with the lid open.

### Step 230 (NEW) – Fetch the final snapshot

`bin/230-NEW-fetch-snapshot.sh`

Run after step 220. It first checks over SSH that nobody is logged in at the old Mac's console, then
copies `~/migrate/state`. This is the consistency gate for everything that follows.

---

## 7. Phase 3 – Homebrew and home directory

### Step 310a (NEW) – Homebrew: copy the prefix

`bin/310a-NEW-homebrew-copy.sh` – recommended when both Macs are Apple Silicon on the same macOS
major version.

Homebrew has no external database: the installed state *is* the tree under `/opt/homebrew`, and
bottles are relocatable within the same prefix. The copy gives identical versions in minutes.
`Caskroom` is deliberately excluded – otherwise Homebrew believes the casks are installed while the
apps are missing, and step 410 would skip them. `brew doctor` warnings about bottles built for
another macOS version heal with later `brew upgrade`. Services started with `brew services` need a
`brew services restart <name>`.

### Step 310b (NEW) – Homebrew: clean install

`bin/310b-NEW-homebrew-install.sh` – the alternative: official installer, then GNU rsync. Formulae
are downloaded fresh by step 410. Slower, but independent of the old Mac's OS version.

### Step 320 (NEW) – Pull the home directory

`bin/320-NEW-home.sh`

Copies everything under `~` except `~/Library` and the entries in `conf/excludes-home.txt`
(regenerable caches, MDM state, and whatever LOCAL.md L3 decided). It never deletes on the
destination and is safe to re-run. Arrives with this step: `~/src`, dotfiles, `~/bin`, `~/.local`,
`~/.cargo`, `~/.rustup`, `~/go`, `~/.vscode*/extensions`, `~/.vim`, `~/.config`, `~/.ssh`,
`~/.claude*`, token files, `~/Applications`.

With an identical home path the copied toolchains work as they are: rustup, uv Pythons and venvs,
Go tools, `~/.local/bin`. Nothing is reinstalled.

rsync exit code 23/24 means some files were unreadable – read the messages. Many
`Operation not permitted` lines = a missing Full Disk Access grant (§12.7); a handful of
`Permission denied` lines on oddly-permissioned directories (a browser extension folder, for
example) is harmless.

### Step 330 (NEW) – Restore /etc/profile

`bin/330-NEW-system-shell.sh` shows the diff against the old Mac's `/etc/profile` and replaces the
file with `sudo` after a second confirmation (the old one is kept as `/etc/profile.before-migrate`).
Relevant if the old Mac sets up the Homebrew environment or other variables there. Open a new terminal
afterwards: `brew`, git aliases, the prompt and completion should work as before.

---

## 8. Phase 4 – Applications

### Step 410 (NEW) – Install applications with Homebrew

`bin/410-NEW-apps-brew.sh`

`brew bundle install --no-upgrade` with the snapshot's Brewfile, then with `conf/Brewfile.extra`.
Installing apps *before* settings matters: the settings then land on top of installed apps instead
of being overwritten by first-launch defaults. For the same reason: **launch nothing** until step
530.

Expect `sudo` password prompts (kernel/system extensions, X11, Wine …). VS Code extensions and Go
tools are already satisfied by the home copy. Failures are listed at the end; fix individually with
`brew install --cask <name>`.

### Step 420 (NEW) – Install the remaining applications

`bin/420-NEW-apps-manual.sh` (manual) lists the apps that were in `/Applications` on the old Mac and
are still missing, before and after.

**→ LOCAL.md L2** names the source of each one. The classes:

| Class | How to get it |
|---|---|
| Delivered by IT (browser, chat, video, SSO apps) | Self Service first; the cask as fallback |
| No cask: discontinued apps, own builds, pinned old versions | `bin/copy-apps.sh "App One" "App Two"` |
| Xcode | `xcodes install --latest` (Apple ID) or App Store |
| Other App Store apps | App Store → account → Purchased; or `mas install <id> …` (Keynote 409183694, Numbers 409203825, Pages 409201541, GarageBand 682658836, iMovie 408981434) |
| MDM and security agents | nothing to do |

`copy-apps.sh` works for drag-installed apps. Apps with privileged helpers or system extensions must
be installed properly. If a cask now installs a newer major version than the one you want to keep,
treat the app as "no cask" and copy the bundle. System extensions (macFUSE, for example) need approval
in Privacy & Security and a reboot – do that at the end of this step.

---

## 9. Phase 5 – Settings

### Step 510 (NEW) – Stage the ~/Library subset

`bin/510-NEW-library-stage.sh` pulls the part of the old `~/Library` selected by
`conf/library-rules.txt` into `~/migrate/stage/Library`. Nothing live is touched.

- **Taken:** `Preferences` (minus `ByHost`, `com.apple.ncprefs.plist`, `MobileMeAccounts.plist` and the
  Messages/Contacts/Home service plists), third-party `Application Support`, Finder sidebar
  (`com.apple.sharedfilelist`), wallpaper store, `Fonts`, `Services`, `Keyboard Layouts`,
  `Input Methods`, `KeyBindings`, `PreferencePanes`, `Screen Savers`, `Spelling`, `com.user.*`
  LaunchAgents, and the containers of selected sandboxed apps (staged only, applied by hand: LOCAL.md
  L5).
- **Skipped:** caches of every kind, Chromium `Singleton*` lock files (they carry the old host name and
  make browsers refuse the profile), VM bundles, wallpaper aerials, Apple daemon state, anything
  belonging to MDM and security agents, `Keychains`, `Containers` and `Group Containers` in general,
  `Mail`, `Safari`.

Why not all of `~/Library`: `ByHost` files are keyed to the hardware UUID, caches are junk,
bulk-copied containers can trip sandbox checks, and agent state must come from MDM.

### Step 515 (NEW) – Optional: import session keys

`bin/515-NEW-session-keys.sh` – only if step 145 was run, and **before the affected apps are launched
for the first time**. Items that already exist are skipped. At an app's first launch macOS asks
whether it may use the item → login password → Always Allow.

If an app was launched too early, its fresh key wins: quit it,
`security delete-generic-password -a <acct> -s "<svc>"` (names: `bin/safe-storage.sh list`), re-run
this step, and copy that app's profile from the stage again.

### Step 520 (NEW) – Apply the staged ~/Library

`bin/520-NEW-library-apply.sh` – must run over SSH while you are logged out of the new Mac:

1. The old Mac's data is staged, so the old Mac no longer has to stay frozen. Log in there.
2. On the new Mac: Apple menu → **Log Out** (stay at the login window; do not reboot).
3. From the old Mac (or any SSH client, a phone works):
   `ssh -t <new-mac>.local ~/src/migrate/bin/520-NEW-library-apply.sh` – the script prints the exact
   line when started at the console, and refuses to continue there.

It backs up the new Mac's current `~/Library/Preferences` to `~/migrate/backup-<timestamp>/`, kills
your `cfprefsd`, and copies the staged tree into `~/Library` (containers excluded).

Why logged out: `cfprefsd` caches preferences in memory and running apps write their state back on
exit. Copying under a live session is what produced the lost shortcuts and scrambled menu bar in
July. With nobody logged in there is nothing to write back, and at the next login every app and
Control Center read the migrated values first.

### Step 530 (NEW) – Per-host preferences and login items

`bin/530-NEW-post-login.sh` – log in on the new Mac, open nothing else, run it.

- Imports per-host preferences from the snapshot: the global per-host domain (menu bar spacing,
  modifier-key remaps, trackpad gestures), Control Center modules, screenshot options, and
  third-party per-host domains. Machine-bound keys are filtered out. `defaults import` merges, so
  existing keys survive.
- Re-creates login items; macOS asks once to let the terminal control System Events. Many apps
  re-register themselves on first launch anyway.
- Restarts Control Center and prints a keyboard-shortcut sanity check (entry count now versus old
  Mac).

Then **log out and back in**. Per-host settings and login items are now active; apps start and begin
asking for permissions – that is step 610.

---

## 10. Phase 6 – Permissions, sign-ins, hardware settings

### Step 610 (NEW) – Privacy permissions and notifications

`bin/610-NEW-permissions.sh` (manual, guided) opens one Privacy & Security pane at a time –
Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Camera, Microphone – and prints
the apps that were allowed on the old Mac (from `tcc-*.txt`). Enable them, use **+** if an app is not
listed, let apps restart.

- Typical: window managers, launchers, clipboard and menu bar tools need Accessibility; menu bar
  managers and conferencing apps need Screen Recording; terminals need Full Disk Access.
- Screen Recording grants are re-confirmed by macOS roughly monthly – that is normal.
- Automation prompts appear per app on first use; confirm them.

**Notifications:** `ncprefs` is deliberately not migrated, so every app asks "would like to send you
notifications" at its first notification attempt (not at launch). Click **Allow** – or **Don't
Allow** for apps you want silent. Re-apply banner/alert styles in System Settings → Notifications;
`~/migrate/state/notifications.tsv` lists the apps that had settings. An app that stays silent with no
prompt: §12.4.

### Step 620 (NEW) – Sign in again

`bin/620-NEW-signins.sh` (manual). The login keychain is not copied: corporate certificates and
device-bound items make a wholesale copy unreliable.

| What | Remedy |
|---|---|
| SSO authenticator, device management login, VPN | re-enrol first |
| Browsers; Electron apps (chat, editors, conferencing) | profiles are copied, but cookies and saved passwords are encrypted with the "Safe Storage" key → logged out, unless steps 145/515 were used; browser sync restores the rest |
| Claude Code | `claude` → `/login`, then `/mcp` to re-authorise HTTP/OAuth MCP servers. Servers configured with tokens in `~/.claude.json` and plugins work immediately. Project histories match because paths are identical |
| CLIs with file-based tokens (`gh`, tokens kept in dotfiles) | already working |
| CLIs with keychain or browser-based login | log in again on first use |
| Wi-Fi networks, Bluetooth devices, Touch ID, Apple ID / iCloud | re-join / re-pair / re-enrol |
| SSH keys | copied; passphrases are asked again |
| App licenses | usually carried by the copied settings; re-enter the key if the app asks |

**→ LOCAL.md L4** is the list for this machine.

### Step 630 (NEW) – Power settings and hardware-bound settings

`bin/630-NEW-settings.sh` applies the old Mac's display-sleep and sleep timers with `sudo pmset`
(MDM may override them), then lists what has to be redone by hand:

- Displays (resolution/scaling, arrangement, Night Shift), sound devices – bound to hardware.
- Wallpaper: the store is copied; if the picture is wrong, re-select it.
- Printers, `/etc/hosts` entries, crontab: see `~/migrate/state/etc/`; re-add by hand. Time Machine:
  re-select the disk. Computer name: usually assigned by MDM.
- Menu bar. Spacing comes from step 530. An app-specific control may exist too (Ice: Settings →
  Advanced → "Menu bar item spacing", a flat bar without a knob – drag it, then **Apply**). Order
  should match because the position keys were in place before first login; otherwise ⌘-drag, or
  `bin/statusitems.sh` (shows differences) and `bin/statusitems.sh --apply` (quits each affected app,
  rewrites its `NSStatusItem …` keys, relaunches it).
- Sandboxed apps keep their settings in `~/Library/Containers`, which is staged but not applied.
  Pattern: launch the app once, quit it, copy `Data/Library/Preferences` from the stage into the
  live container, `killall cfprefsd`, relaunch.
- Default browser and file handlers are carried by `com.apple.LaunchServices`; if not, System
  Settings → Desktop & Dock → Default web browser.

**→ LOCAL.md L5** has the concrete items and commands for this machine.

---

## 11. Phase 7 – Verify and clean up

### Step 710 (NEW) – Verify

`bin/710-NEW-verify.sh` snapshots the new Mac into `~/migrate/state-new` and diffs it against the old
snapshot. Expected differences: cask versions, MDM apps, host-specific keys.

Manual spot checks:

```bash
git -C ~/src/<some-repo> status -sb && gh auth status && ssh -T git@github.com
claude --version && code --list-extensions | wc -l
defaults -currentHost read -g NSStatusItemSpacing
launchctl print gui/$(id -u)/<your-launchagent-label> | head -5
osascript -e 'display notification "test" with title "NC delivery test"'
```

Then use the top daily apps for a day before wiping anything.

### Step 720 (NEW) – Clean up

`bin/720-NEW-cleanup.sh` (manual): delete the session-key file and SSH control sockets, later the
stage and backups, turn Remote Login off. Keep the old Mac untouched for 1–2 weeks as the fallback –
anything missed can be pulled per app from its `~/Library`. Before returning it: sign out of Apple ID,
deregister the SSO authenticator, follow IT's wipe procedure.

**→ LOCAL.md L6** for machine-specific leftovers.

When the new Mac is settled, run steps 110 and 120 on it: that makes it the starting point of the next
migration and refreshes `LOCAL.md`.

---

## 12. Troubleshooting

### 12.1 A setting reverted after copying

A live process wrote its cached copy back. Restore that domain from the snapshot or the stage with the
owning app quit, then re-login:

```bash
defaults import com.apple.symbolichotkeys ~/migrate/state/defaults/com.apple.symbolichotkeys.plist
defaults import pbs ~/migrate/state/defaults/pbs.plist
killall cfprefsd          # then log out and in; do not open System Settings in between
```

For anything else: quit the app, `cp ~/migrate/stage/Library/Preferences/<domain>.plist ~/Library/Preferences/`,
`killall cfprefsd`, relaunch.

### 12.2 Keyboard shortcuts (System Settings → Keyboard → Keyboard Shortcuts)

| File / key | Holds |
|---|---|
| `com.apple.symbolichotkeys.plist` | Mission Control, Screenshots, Spotlight, Input Sources, function keys, Accessibility |
| `.GlobalPreferences.plist` → `NSUserKeyEquivalents` | App Shortcuts for all applications (e.g. "Paste and Match Style" ⌘⇧V) |
| `<app domain>.plist` → `NSUserKeyEquivalents` | per-app App Shortcuts |
| `pbs.plist` | Services |

A healthy `symbolichotkeys` has dozens of entries; a ~700-byte file with a handful is the default stub.

### 12.3 Menu bar spacing or modifier-key remap missing

Per-host values did not import. Check `defaults -currentHost read -g`, re-run step 530, re-login.
Manual spacing: `defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6` and the same for
`NSStatusItemSelectionPadding`.

### 12.4 An app shows no notifications and no prompt

1. Confirm delivery works at all: `osascript -e 'display notification "x" with title "test"'`.
   Nothing → `killall usernoted cfprefsd`, check Focus, check "allow when mirroring/sharing".
2. App-specific: reset its registration in both stores (terminal needs Full Disk Access):

```bash
bin/notif-reset.sh com.tinyspeck.slackmacgap
# Chromium browsers register a helper as well:
bin/notif-reset.sh com.brave.Browser com.brave.browser.framework.alertnotificationservice
```

3. Relaunch the app and make it notify (Slack: `/remind me to test in 1 minute`, then switch to another
   app). Click Allow. `tccutil` is irrelevant here – notifications are not TCC-managed, and
   reinstalling the app does not help.

Background: notification state lives in `com.apple.ncprefs.plist` (settings) and in `usernoted`'s
database (registrations). If they disagree the app is neither prompted for nor shown in Settings.

### 12.5 Browser says the profile is in use on another computer

A `SingletonLock` was copied. Quit the browser and remove `Singleton*` in its profile root, e.g.
`rm ~/Library/Application\ Support/BraveSoftware/Brave-Browser/Singleton*`.

### 12.6 An app misbehaves in a way settings cannot explain

Order of suspicion: missing privacy permission (step 610) → missing login item or helper (reinstall
the cask) → per-host pref (`ls ~/migrate/state/byhost`) → keychain item (sign in again).

### 12.7 rsync reports `Operation not permitted`

Full Disk Access is missing for sshd on the sending Mac ("Allow full disk access for remote users")
or for the terminal on the receiving Mac.

---

## 13. Tools

Files in `bin/` without a number. Settings come from `conf/kit.conf`, overridden by the untracked
`conf/kit.local.conf`.

| Tool | Purpose |
|---|---|
| `bin/steps.sh` | list the steps; `--check` compares them with the step headings of this guide |
| `bin/capture.sh [dir]` | write a snapshot (used by steps 120, 130, 220, 710) |
| `bin/copy-apps.sh "App" …` | new Mac: copy drag-installed app bundles from the old Mac |
| `bin/statusitems.sh [--apply]` | compare / restore menu bar item positions against the snapshot |
| `bin/notif-reset.sh <bundle-id> …` | reset an app's notification registration so it prompts again |
| `bin/safe-storage.sh list\|export\|import` | "Safe Storage" keychain items (used by steps 145, 515) |

| Config | Purpose |
|---|---|
| `conf/kit.conf` | shared settings: data directory, rsync and ssh options |
| `conf/kit.local.conf` | untracked: `OLD_UUID`, `OLD_HOST` (written by step 110), `REDACT`, overrides |
| `conf/excludes-home.txt` | rsync excludes for step 320 |
| `conf/library-rules.txt` | rsync filter for step 510 |
| `conf/Brewfile.extra` | casks for hand-installed apps (step 410) |
| `lib/step.sh` | helpers shared by the step scripts |

---

## 14. What was tested

Checked on one machine (macOS 26.7, bash 3.2) on 2026-11-13:

- `bash -n` and `shellcheck` on every script; `bin/steps.sh --check`; `-n` on every step.
- The role guard: OLD steps refuse before step 110 has run, NEW steps refuse on the old Mac.
- Steps 110, 120, 130, 220 end to end on the old-Mac side, with data redirected to a scratch directory
  (step 110 and 130 stop at their Full Disk Access check on a terminal without it, as intended).
- Step 710's capture-and-diff, step 420's missing-app list and step 630's `pmset` parsing, with the
  machine temporarily treated as "new".
- The per-host import code of step 530: a scratch domain, plus the global per-host domain with one
  unchanged key (key filtering works, existing keys are kept).
- rsync 3.5.1 with `-aHXN`: Finder tags, quarantine, provenance and creation times survive;
  `--filter=-x_com.apple.macl` drops the TCC attribute.
- `conf/library-rules.txt` as a dry run against a real `~/Library`: nothing from the excluded classes,
  all expected items present. `conf/excludes-home.txt` against a synthetic home tree.
- The tar pipe of step 310a (exclude, symlinks, hard links) on a scratch tree.
- Cask names in `conf/Brewfile.extra` exist in Homebrew.

Not testable without a second Mac – treat as reviewed, not proven:

- Everything that talks to the other Mac: steps 210 (SSH check), 230, 310a, 320, 510, and
  `copy-apps.sh`.
- Steps 310b, 330, 410, 520 (the copy itself; its console guard was checked), the login-item part of
  530, the pane walk of 610, `statusitems.sh --apply`.
- Steps 145 and 515 (new technique, not used in July).
- `notif-reset.sh` is a port of the commands that fixed the notification problem in July; the script
  form was not re-run.
- Whether menu bar order survives without manual ⌘-drag.
