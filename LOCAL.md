# Local migration notes

The machine-specific half of [MACOS-MIGRATE.md](MACOS-MIGRATE.md). The guide is generic; whenever a
step needs facts or decisions about *this* machine it sends you to a numbered section here
(L1 … L6). Do what the section says, then go back to the step named in its "Return to" line.

This copy describes one real machine and doubles as an example. Host and user names are replaced
by `$HOSTNAME` and `$USER`.

## How to produce this file

For a person or an LLM agent, on the Mac you are going to migrate **from**:

1. Run `bin/110-OLD-prepare.sh`, then `bin/120-OLD-inventory.sh`. The second one rewrites the block
   between `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->` at the end of this file. Never
   edit inside that block.
2. Rewrite sections L1 – L6 for this machine. Each section starts with a *Fill in* note that says
   which part of the generated inventory to read and what to write. Replace the previous
   machine's content; delete what does not apply; update the "Reviewed" date.
3. Rules for the hand-written parts:
   - No secrets, tokens, internal URLs or host names. Write `$USER` and `$HOSTNAME` for the user
     and host. Naming a file that holds a credential is fine; quoting its content is not.
   - Every item is an action or a decision: a command to run, an app to install and from where,
     a setting to check. Use `- [ ]` checkboxes for things to do.
   - Keep the section headings and the "Called from / Return to" lines unchanged; the guide and the
     step scripts refer to them.
4. Apply what L1 – L3 tell you to change in `conf/` (`excludes-home.txt`, `library-rules.txt`,
   `Brewfile.extra`), then continue with `bin/130-OLD-capture.sh`.

Re-run step 120 whenever the machine has changed, and re-review L1 – L6 afterwards.

Reviewed: 2026-11-13.

---

## L1. Before migrating

Called from: step 120 (`120-OLD-inventory.sh`) and step 140. Return to: step 130.

*Fill in:* read "Checks", "Applications" and "Files holding credentials" in the generated
inventory. List everything that should be fixed, decided or exported on this Mac before the
snapshot is taken.

- [ ] Give the terminal Full Disk Access (the "Checks" list says it is missing), re-run step 120.
- [ ] `brew uninstall --cask chromium` – the cask is registered but the app is gone.
- [ ] Bartender: the cask now installs version 7, the installed app is 6.5.2. Decide: accept 7 on the
      new Mac, or keep 6 by copying the bundle (then add it to the `copy-apps.sh` line in L2).
- [ ] `git config --global --unset http.cookiefile` – it points into a home directory that does
      not exist.
- [ ] Delete leftovers of the previous migration: `~/ncprefs.backup*.plist`,
      `~/usernoted-db.backup*`, `~/migrate/hotkeys*.plist`,
      `~/Library/Application Support/zoom.us~00`, `~02`, `~03`.
- [ ] Shell start-up files export API tokens in plain text (`~/.bashrc`, `~/.profile`). They are
      copied as they are; consider moving them to a file with mode 600 first.
- [ ] Exports for step 140: Raycast (`.rayconfig`), BetterTouchTool preset.

## L2. Applications

Called from: step 420 (`420-NEW-apps-manual.sh`). Return to: step 510.

*Fill in:* take "Not managed by Homebrew or the App Store" and "App Store" from the generated
inventory. For each app decide the source. To test for a cask: `brew info --cask <name>`. Apps with
a cask go into `conf/Brewfile.extra` (installed by step 410) and are only listed here for the record.

- [ ] Self Service (IT-delivered; casks exist as a fallback): Google Chrome, Slack, zoom.us, Glean,
      Okta Verify.
- [ ] App Store, signed in with the Apple ID: Keynote, Numbers, Pages, GarageBand, iMovie.
      Xcode: `xcodes install --latest`.
- [ ] No cask – copy the bundles from the old Mac:

  ```bash
  bin/copy-apps.sh "SimpleFloatingClock" "Skitch" "DTerm" "Inklet" "iTermBrowserPlugin" \
    "ChatGPT Classic" "InputMethodHinter" "Visual Studio Code - Insiders~103"
  ```

- [ ] macFUSE: approve the system extension in System Settings → Privacy & Security, reboot at the
      end of this step.
- Already covered by `conf/Brewfile.extra`: Audacity, ChatGPT, Claude, Cursor, Discord, draw.io,
  ImHex, KeePassXC, LM Studio, OpenCode, T3 Code, VS Code Insiders.
- Nothing to do: MDM and security agents, Self Service itself, `~/Applications/*` (copied with
  the home directory).

## L3. Data to leave behind

Called from: step 120. Return to: step 130. Applied by: step 320 through `conf/excludes-home.txt`.

*Fill in:* read "Disk usage" in the generated inventory. For every bulky entry decide: copy,
or exclude (add a line to `conf/excludes-home.txt`).

| Entry | Decision |
|---|---|
| `~/Downloads` (about 200 G) | copy; uncomment `/Downloads/` in `excludes-home.txt` to skip |
| `~/.lmstudio` (75 G of models) | copy; re-downloading is slower than the cable |
| `~/tmp` (42 G) | copy, or prune first |
| `~/.cache` (17 G) | `uv` and `puppeteer` caches are excluded already; the rest is copied |
| `~/Library/Application Support/Claude/vm_bundles` (13 G) | excluded by `library-rules.txt`; re-downloaded on demand |

## L4. Sign-ins after migrating

Called from: step 620 (`620-NEW-signins.sh`). Return to: step 630.

*Fill in:* read "Files holding credentials", "Keychain items" and "Toolchains". List the tools
and apps that need a login on the new Mac, and those that do not.

- [ ] Claude Code: `/login`; `/mcp` for the OAuth-based MCP servers. Servers that take tokens from
      `~/.claude.json` work immediately.
- [ ] Command-line tools with browser or keychain login: the OIDC helper, the remote-build
      credential helper, Copilot CLI, opencode.
- [ ] VS Code, VS Code Insiders, Cursor: GitHub sign-in.
- [ ] Slack workspaces, Zoom, Discord (unless step 515 was used).
- Working without action (tokens are in files): `gh`, codex, the CI client, the Jira/Confluence
  tokens.

## L5. Settings and per-app items to check

Called from: step 630 (`630-NEW-settings.sh`). Return to: step 710.

*Fill in:* read "Settings", "Login items" and "User LaunchAgents". List what must be true on
the new Mac and how to check or restore it.

- [ ] Input sources: U.S. and Russian-PC present; `InputMethodHinter` running (login item).
- [ ] Caps Lock is remapped to "no action" (per-host; restored by step 530).
- [ ] Menu bar: Ice spacing compact (per-host values 0/0), Ice sections in the right place.
- [ ] Maccy (sandboxed): launch once, quit, then

  ```bash
  rsync -a ~/migrate/stage/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/ \
    ~/Library/Containers/org.p0deje.Maccy/Data/Library/Preferences/ && killall cfprefsd && open -a Maccy
  ```

- [ ] Raycast: "Import Settings & Data" with the exported `.rayconfig`.
- [ ] BetterTouchTool: triggers present; otherwise import the exported preset.
- [ ] LaunchAgent loaded: `launchctl print gui/$(id -u)/com.user.slack-signin-monitor | head -3`.
- [ ] Default browser is Brave.
- [ ] `/etc/profile` carries the Homebrew environment (step 330).

## L6. Cleanup

Called from: step 720 (`720-NEW-cleanup.sh`). Return to: the end of the guide.

*Fill in:* anything on either Mac that only existed for the migration.

- [ ] Remote Login off on both Macs.
- [ ] `~/macsetup.sh` (old `defaults write` tweaks) is obsolete; its `sudo` lines are stale.

---

## Inventory

<!-- BEGIN GENERATED -->
Generated by `bin/120-OLD-inventory.sh` on 2026-11-13. Do not edit inside this block.

### Machine

- Model Name: MacBook Pro
- Model Identifier: Mac17,6
- Chip: Apple M5 Max
- Memory: 48 GB
- macOS 26.7.1 (25G241); FileVault is On.
- User `$USER` (uid 502), home `/Users/$USER`, login shell `/bin/bash`
- Remote Login: on
- Disk: 546Gi used of 1.8Ti

### Disk usage

Home entries over 1 GB:

```
  207.5 G  ~/Downloads
   75.4 G  ~/.lmstudio
   61.2 G  ~/src
   42.4 G  ~/tmp
   41.9 G  ~/Library
   17.0 G  ~/.cache
    2.9 G  ~/go
    2.4 G  ~/.vscode
    2.1 G  ~/Documents
    2.1 G  ~/bin
    1.9 G  ~/.local
    1.8 G  ~/.vscode-insiders
    1.7 G  ~/.npm
    1.4 G  ~/.rustup
```

`~/Library/Application Support` entries over 0.2 GB:

```
   14.5 G  ~/Library/Application Support/Claude
    2.9 G  ~/Library/Application Support/Code - Insiders
    1.8 G  ~/Library/Application Support/Google
    1.6 G  ~/Library/Application Support/Slack
    1.6 G  ~/Library/Application Support/BraveSoftware
    1.4 G  ~/Library/Application Support/zoom.us~00
    1.3 G  ~/Library/Application Support/com.apple.wallpaper
    1.1 G  ~/Library/Application Support/zoom.us
    0.6 G  ~/Library/Application Support/Cursor
    0.5 G  ~/Library/Application Support/discord
    0.5 G  ~/Library/Application Support/com.raycast.macos
    0.4 G  ~/Library/Application Support/zoom.us~02
    0.4 G  ~/Library/Application Support/Vivaldi
    0.3 G  ~/Library/Application Support/Glean
    0.3 G  ~/Library/Application Support/Chromium
    0.2 G  ~/Library/Application Support/virtualenv
```

### Homebrew

- Homebrew 7.0.7 at `/opt/homebrew`
- 247 formulae (95 leaves), 58 casks
- Taps: gromgit/fuse REDACTED/brew opencode-ai/tap oven-sh/bun tdsmith/ham yurikoles/yurikoles 
- Brewfile entries: 102 brew, 58 cask, 8 go, 1 npm, 6 tap, 129 vscode
- Services running: 0

### Applications

App Store:

- GarageBand.app
- Keynote.app
- Numbers.app
- Okta Verify.app
- Pages.app
- Xcode.app
- iMovie.app

Not managed by Homebrew or the App Store (hand-installed or MDM):

- Audacity.app
- Bartender 6.app
- ChatGPT Classic.app
- ChatGPT.app
- Claude.app
- Cloudflare WARP.app
- Code42-AAT.app
- Cursor.app
- DTerm.app
- Discord.app
- Falcon.app
- Glean.app
- Google Chrome.app
- ImHex.app
- Inklet.app
- InputMethodHinter.app
- KeePassXC.app
- LM Studio.app
- REDACTED IT Self Service.app
- OpenCode.app
- SimpleFloatingClock.app
- Skitch.app
- Slack.app
- T3 Code (Nightly).app
- Visual Studio Code - Insiders.app
- Visual Studio Code - Insiders~103.app
- draw.io.app
- iTermBrowserPlugin.app
- zoom.us.app

`~/Applications`:

- Brave Browser Apps.localized
- BreakApp.app
- Chrome Apps.localized
- Claude Code URL Handler.app
- Quick Camera.app
- Skitch.app

### MDM and security agents (never copied)

- com.cloudflare.1dot1dot1dot1.macos.warp.daemon.plist
- com.cloudflare.warp.updater.plist
- com.code42.agent.plist
- com.code42.agent.uninstall.plist
- com.crowdstrike.falcon.UserAgent.plist
- com.jamf.connect.daemon.ssp.plist
- com.jamf.connect.plist
- com.jamf.management.daemon.plist
- com.jamf.management.login.plist
- com.jamf.selfserviceplus.agent.plist
- com.jamf.selfserviceplus.daemon.plist
- com.jamf.ssp.daemon.plist
- com.jamfsoftware.task.1.plist
- com.kolide-k2.launcher.plist

### Toolchains

```
# npm -g
├── @google/clasp@3.3.0
└── npm@11.17.0

# pipx
# uv tools
# uv pythons
cpython-3.14.6-macos-aarch64-none
cpython-3.14.6-macos-aarch64-none
cpython-3.13.14-macos-aarch64-none
cpython-3.10.18-macos-aarch64-none
cpython-3.9.6-macos-aarch64-none
# cargo
# rustup
stable-aarch64-apple-darwin (active, default)
# go bin
curator
dlv
godef
gomodifytags
goplay
gopls
gotests
impl
staticcheck
# gh extensions
gh copilot	github/gh-copilot	v1.2.0
gh dash	dlvhdr/gh-dash	v4.22.0
gh lazy	gizmo385/gh-lazy	7905466f
gh models	github/gh-models	v0.0.25
gh pr-review	agynio/gh-pr-review	v1.6.2
gh prview	bmon/gh-prview	v0.0.4
gh review-conductor	gh-tui-tools/gh-review-conductor	v1.3.0
```

- code: 129 extensions
- code-insiders: 129 extensions

### Login items

- /Applications/Cloudflare WARP.app
- /Applications/Rectangle.app
- /System/Applications/Utilities/Activity Monitor.app
- /Applications/Fluor.app
- /Applications/Raycast.app
- /Applications/BetterTouchTool.app
- /Applications/BlueHarvest.app
- /Applications/Ice.app
- /Applications/Glean.app
- /Applications/Maccy.app
- /Applications/Okta Verify.app
- /Applications/SimpleFloatingClock.app
- /Applications/InputMethodHinter.app
- ~/Applications/BreakApp.app

### User LaunchAgents and crontab

- com.user.slack-signin-monitor.plist
- crontab entries: 0

### Settings

- Appearance: Dark
- Languages: ( "en-AU", "ru-AU" )
- Input sources: U.S., RussianWin
- Dock: autohide=1, tilesize=24
- Screenshots: location=~/Downloads
- Default browser: com.brave.browser
- Per-host: NSStatusItemSpacing=0, NSStatusItemSelectionPadding=0, modifier-key remaps: 2
- Keyboard shortcuts: 78 symbolic hotkeys; app shortcuts: { "Paste and Match Style" = "@$v"; }
- Preferences: 520 plists, 27 per-host
- Menu bar items with stored positions: 80

Power (`pmset -g custom`):

```
Battery Power:
 hibernatemode        3
 displaysleep         2
 sleep                1
AC Power:
 hibernatemode        3
 displaysleep         10
 sleep                0
```

### Keychain items that keep copied app profiles logged in

- Brave Safe Storage
- Chrome Safe Storage
- Claude Safe Storage
- Code - Insiders Safe Storage
- Code Safe Storage
- Cursor Safe Storage
- OpenCode Safe Storage
- Slack Safe Storage
- t3code Safe Storage
- Zoom Safe Storage

### Files holding credentials (names only)

- `~/.ssh`
- `~/.pypirc`
- `~/.config/gh/hosts.yml`
- `~/.claude.json`
- `~/.codex/auth.json`
- `~/.evergreen-oauth-token`
- `~/.jira-token`
- `~/keepass3.kdbx`
- `~/.confluence-token`
- `~/.bashrc` exports secrets in plain text
- `~/.profile` exports secrets in plain text

### Checks

- The terminal has no Full Disk Access: the privacy-grant report (`tcc-*.txt`) is empty.
- Cask registered in Homebrew but app missing: Bartender 7.app
- Cask registered in Homebrew but app missing: Chromium.app
- Remote Login is on (needed during a migration; turn it off otherwise).

<!-- END GENERATED -->
