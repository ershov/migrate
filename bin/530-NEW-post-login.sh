#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Restore per-host preferences and login items" "$@" <<'EOF'
Run in the first GUI session after step 520.
Imports per-host preferences from the snapshot (menu bar spacing, modifier-key remaps,
trackpad, Control Center modules, screenshot options), re-creates login items (macOS asks
once to let the terminal control System Events) and restarts Control Center.
EOF

say "== per-host preferences"
python3 - "$STATE/byhost" <<'EOF'
import os, plistlib, subprocess, sys, tempfile
src = sys.argv[1]
SKIP_KEYS = ('com.apple.gms.', 'IRServiceToken')
APPLE_OK = {'GlobalPreferences', 'com.apple.controlcenter', 'com.apple.screencapture'}
for name in sorted(os.listdir(src)):
    if not name.endswith('.plist'):
        continue
    dom = name[:-6]
    if dom.endswith('.ShipIt') or (dom.startswith('com.apple.') and dom not in APPLE_OK):
        continue
    with open(os.path.join(src, name), 'rb') as f:
        d = {k: v for k, v in plistlib.load(f).items() if not k.startswith(SKIP_KEYS)}
    if not d:
        continue
    with tempfile.NamedTemporaryFile(suffix='.plist', delete=False) as t:
        plistlib.dump(d, t)
    target = '-g' if dom == 'GlobalPreferences' else dom
    rc = subprocess.run(['defaults', '-currentHost', 'import', target, t.name]).returncode
    os.unlink(t.name)
    print(f"  {dom}: {len(d)} keys {'ok' if rc == 0 else 'FAILED'}")
EOF

say "== login items"
CUR=$(osascript -e 'tell application "System Events" to get the path of every login item')
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || { echo "  app missing, skipped: $p"; continue; }
  case "$CUR" in *"$p"*) continue ;; esac
  osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$p\", hidden:false}" >/dev/null &&
    echo "  added: $p"
done < "$STATE/apps/login-items.txt"

say "== checks"
say "  symbolic hotkeys: now $(defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys 2>/dev/null | grep -c enabled), old Mac $(plutil -p "$STATE/defaults/com.apple.symbolichotkeys.plist" 2>/dev/null | grep -c enabled)"
say "  menu bar spacing: $(defaults -currentHost read -g NSStatusItemSpacing 2>/dev/null)"

killall ControlCenter SystemUIServer 2>/dev/null
say "" "Now log out and back in once: per-host settings and login items become active."
finish
