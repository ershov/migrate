#!/bin/bash
# Snapshot of everything that is not a plain file copy. Writes $STATE (or $1). Run in a GUI session.
. "$(dirname "$0")/../conf/kit.conf"
OUT=${1:-$STATE}
mkdir -p "$OUT/brew" "$OUT/apps" "$OUT/byhost" "$OUT/defaults" "$OUT/etc"
chmod 700 "$OUT"
cd "$OUT" || exit 1
PY=$(command -v python3)
P="$HOME/Library/Preferences"

echo "== system"
{
  sw_vers; uname -m
  echo "host=$(scutil --get LocalHostName)"
  echo "user=$(id -un) uid=$(id -u) home=$HOME"
  dscl . -read "/Users/$(id -un)" UserShell
} > system.txt 2>&1

echo "== homebrew"
brew bundle dump --force --file=brew/Brewfile >/dev/null
brew leaves > brew/leaves.txt
brew list --formula --versions > brew/formulae.txt
brew list --cask --versions > brew/casks.txt
brew tap > brew/taps.txt
brew services list > brew/services.txt 2>&1
[ -x "$RSYNC" ] || echo "  !! $RSYNC missing: brew install rsync"

echo "== apps"
ls -1 /Applications > apps/applications.txt
ls -1 "$HOME/Applications" > apps/user-applications.txt 2>/dev/null
"$PY" - > apps/manual-apps.txt <<'EOF'
import json, os, subprocess
apps = {a for a in os.listdir('/Applications') if a.endswith('.app')}
cask = set()
out = subprocess.run(['brew', 'info', '--cask', '--json=v2', '--installed'], capture_output=True, text=True).stdout
for c in json.loads(out or '{"casks": []}')['casks']:
    for art in c.get('artifacts', []):
        if isinstance(art, dict):
            cask.update(os.path.basename(a) for a in art.get('app', []) if isinstance(a, str))
for a in sorted(apps - cask - {'Safari.app'}):
    kind = 'MAS' if os.path.exists(f'/Applications/{a}/Contents/_MASReceipt') else 'MANUAL'
    print(f'{kind}\t{a}')
for a in sorted(cask - apps):
    print(f'CASK-WITHOUT-APP\t{a}')
EOF
osascript > apps/login-items.txt <<'EOF'
tell application "System Events" to set p to path of every login item
set AppleScript's text item delimiters to linefeed
return p as text
EOF
ls -1 "$HOME/Library/LaunchAgents" > apps/launchagents-user.txt 2>/dev/null
ls -1 /Library/LaunchAgents /Library/LaunchDaemons > apps/launchd-system.txt 2>/dev/null
for c in code code-insiders cursor; do
  command -v "$c" >/dev/null && "$c" --list-extensions > "apps/$c-extensions.txt" 2>/dev/null
done

echo "== toolchains"
{
  echo "# npm -g";        npm ls -g --depth=0 2>/dev/null | tail -n +2
  echo "# pipx";          pipx list --short 2>/dev/null
  echo "# uv tools";      uv tool list 2>/dev/null
  echo "# uv pythons";    uv python list --only-installed 2>/dev/null | awk '{print $1}'
  echo "# cargo";         cargo install --list 2>/dev/null | grep -v '^ '
  echo "# rustup";        rustup toolchain list 2>/dev/null
  echo "# go bin";        ls -1 "$HOME/go/bin" 2>/dev/null
  echo "# gh extensions"; gh extension list 2>/dev/null
} > toolchains.txt

echo "== per-host preferences"
defaults -currentHost export -g byhost/GlobalPreferences.plist
for f in "$P/ByHost/"*.plist; do
  d=$(basename "$f" | sed -E 's/\.[0-9A-Fa-f-]{36}\.plist$//')
  defaults -currentHost export "$d" "byhost/$d.plist" 2>/dev/null
done

echo "== preference backups"
defaults export -g defaults/GlobalPreferences.plist
for d in com.apple.symbolichotkeys pbs com.apple.dock com.apple.finder com.apple.HIToolbox \
         com.apple.controlcenter com.apple.screencapture com.apple.WindowManager \
         com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults export "$d" "defaults/$d.plist" 2>/dev/null
done

echo "== menu bar items, notification settings"
"$PY" - "$P" <<'EOF'
import glob, os, plistlib, sys
prefs = sys.argv[1]
rows = []
for p in glob.glob(prefs + '/*.plist'):
    try:
        with open(p, 'rb') as f:
            d = plistlib.load(f)
    except Exception:
        continue
    dom = os.path.basename(p)[:-6]
    for k, v in d.items():
        if k.startswith('NSStatusItem ') and isinstance(v, (bool, int, float)):
            rows.append((dom, k, type(v).__name__, v))
with open('statusitems.tsv', 'w') as f:
    for r in sorted(rows):
        f.write('\t'.join(str(x) for x in r) + '\n')
try:
    with open(prefs + '/com.apple.ncprefs.plist', 'rb') as f:
        apps = plistlib.load(f).get('apps', [])
    with open('notifications.tsv', 'w') as f:
        for a in sorted(apps, key=lambda a: a.get('bundle-id', '')):
            f.write(f"{a.get('bundle-id', '?')}\tauth={a.get('auth', '')}\tflags={a.get('flags', '')}\t{a.get('path', '')}\n")
except Exception as e:
    print('  ncprefs not readable:', e)
EOF

echo "== privacy grants"
Q="select service, client, auth_value from access order by service, client;"
sqlite3 "file:$HOME/Library/Application Support/com.apple.TCC/TCC.db?mode=ro" "$Q" > tcc-user.txt 2>&1 ||
  echo "  !! user TCC.db unreadable: give this terminal Full Disk Access and re-run"
sqlite3 "file:/Library/Application Support/com.apple.TCC/TCC.db?mode=ro" "$Q" > tcc-system.txt 2>&1 ||
  echo "  !! system TCC.db unreadable: give this terminal Full Disk Access and re-run"

echo "== system-level"
pmset -g custom > etc/pmset.txt 2>&1
cp /etc/profile /etc/paths /etc/hosts etc/ 2>/dev/null
cp -R /etc/paths.d etc/ 2>/dev/null
lpstat -p > etc/printers.txt 2>&1
networksetup -listallnetworkservices > etc/network-services.txt 2>&1
networksetup -listpreferredwirelessnetworks en0 > etc/wifi.txt 2>&1
crontab -l > etc/crontab.txt 2>/dev/null

echo "done: $OUT ($(find . -type f | wc -l | tr -d ' ') files)"
