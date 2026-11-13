# migrate

Scripts and a step-by-step guide for moving a macOS user environment to a new Mac by hand, for
machines where Apple's Migration Assistant cannot be used (corporate MDM).

The goal is a new Mac that is as close to the old one as possible: same tools, files, application and
UI settings. What can be scripted is scripted; what cannot (privacy permissions, sign-ins, hardware
settings) is a guided manual step.

## The three documents

| File | Role |
|---|---|
| `bin/NN-OLD\|NEW-name.sh` | **what to do**: the numbered steps, short and action-oriented |
| [MACOS-MIGRATE.md](MACOS-MIGRATE.md) | **why and what if**: reasons, nuances, troubleshooting; one section per step |
| [LOCAL.md](LOCAL.md) | **this machine**: decisions and facts the steps need (which apps come from where, what to exclude, what to sign in to), plus a generated inventory. The copy in the repository is a real example |

## How to run a migration

```bash
bin/steps.sh                 # the list of steps, in order
bin/110-OLD-prepare.sh        # start here, on the Mac you are leaving
```

- The three-digit numbers are one execution order across both Macs: `ls bin/` shows it. Run the
  files in that order, each on the Mac named in its file name (`OLD` or `NEW`). The hundreds digit
  is the phase: 1 old Mac, 2 handover, 3 Homebrew and home, 4 apps, 5 settings, 6 manual finish,
  7 verify and clean up.
- Every step prints what it is going to do and asks before doing it. Manual steps print
  instructions and wait. Each step ends by naming the next one.
- `-n` / `--dry-run` prints what a step would do and changes nothing (on either Mac);
  `-y` / `--yes` skips the prompts.
- Steps refuse to run on the wrong Mac: step 110 records the old Mac's hardware UUID.
- Files with the same number and a letter (`310a`, `310b`) are alternatives: run one. `a` is the
  recommended one.
- Steps titled "Optional:" (145, 515) can be skipped.
- When a step says "→ LOCAL.md, section Lx", do what that section says and come back.
- Everything in `bin/` without a number is a tool, used by the steps or for repairs.

Step 150 prints the few commands that have to be typed on the new Mac before the scripts exist there.

## Layout

| Path | Content |
|---|---|
| `bin/1xx-OLD-…` | old Mac: prepare, inventory, snapshot, exports, bootstrap instructions for the new Mac |
| `bin/2xx-…` | handover: prepare the new Mac, freeze the old one, fetch the final snapshot |
| `bin/3xx-NEW-…` | Homebrew (two alternatives), home directory, `/etc/profile` |
| `bin/4xx-NEW-…` | applications |
| `bin/5xx-NEW-…` | `~/Library`: stage, apply while logged out, per-host preferences and login items |
| `bin/6xx-NEW-…` | privacy permissions, sign-ins, hardware-bound settings |
| `bin/7xx-NEW-…` | verify, clean up |
| `bin/steps.sh` | list the steps; `--check` verifies the guide has a section for each |
| `bin/capture.sh` | write a snapshot of a Mac (used by several steps) |
| `bin/copy-apps.sh` | copy drag-installed app bundles from the old Mac |
| `bin/statusitems.sh` | compare / restore menu bar item positions |
| `bin/notif-reset.sh` | reset an app's notification registration so it prompts again |
| `bin/safe-storage.sh` | list / export / import browser and Electron "Safe Storage" keychain keys |
| `lib/step.sh` | helpers shared by the step scripts |
| `conf/kit.conf` | shared settings |
| `conf/kit.local.conf` | untracked; written by step 110 (`OLD_UUID`, `OLD_HOST`), plus your overrides |
| `conf/excludes-home.txt` | rsync excludes for the home directory |
| `conf/library-rules.txt` | rsync filter selecting what is taken from `~/Library` |
| `conf/Brewfile.extra` | casks for apps that were installed by hand |

Runtime data is kept outside the repository, in `~/migrate`: `state/` (snapshot of the old Mac),
`inventory/`, `stage/` (staged `~/Library`), `backup-*/`, `state-new/`.

## Using it on another machine

`MACOS-MIGRATE.md`, `bin/` and `lib/` are generic. Three things describe one machine and have to be
redone: `LOCAL.md`, and the `conf/` files derived from it.

1. `bin/110-OLD-prepare.sh`, then `bin/120-OLD-inventory.sh`. Step 120 regenerates the inventory
   block at the end of `LOCAL.md`. User name, home path and host name are replaced by placeholders;
   set `REDACT='regex'` in `conf/kit.local.conf` to blank out more.
2. Rewrite sections L1 – L6 of `LOCAL.md` following its "How to produce this file" section. The
   instructions are written for a person or an LLM agent: each section says which part of the
   inventory to read and what to write.
3. Adjust `conf/excludes-home.txt`, `conf/library-rules.txt` and `conf/Brewfile.extra` to match.

## Requirements

- macOS on Apple Silicon; both Macs with the same short user name and home path.
- Homebrew. GNU `rsync` 3.x on both Macs (step 110 and step 310 install it); the system `rsync`
  lacks features the copies need.
- `python3` (Homebrew or Command Line Tools).
- Remote Login with "Allow full disk access for remote users", and Full Disk Access for the terminal
  (steps 110 and 210 walk through it and check).
- A Thunderbolt cable is recommended.

Scripts are written for the stock `/bin/bash` 3.2.

## Safety

- `~/migrate` and the home directory contain API tokens; the optional step 145 writes browser session
  keys to `~/migrate/state/safe-storage.tsv`. Transfer only over SSH or a cable. Nothing under
  `~/migrate` belongs in this repository.
- `LOCAL.md` is tracked: keep secrets, internal URLs and host names out of it.
- The pulls never delete on the destination. Step 520 backs up the existing `~/Library/Preferences`
  first and refuses to run while the user is logged in at the console.
- MDM and security agents are excluded from every copy; never migrate them.

## Status

Tested on one machine (macOS 26.7, bash 3.2): the old-Mac steps, the snapshot and verification
logic, the Mac-role guard, the rsync filters as dry runs. The steps that need a second Mac (the
transfers, applying `~/Library`, the permission walk) have not been run end to end yet. Details:
guide §14.

## License

[MIT](LICENSE)
