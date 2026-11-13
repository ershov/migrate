#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Verify against the old Mac's snapshot" "$@" <<'EOF'
Snapshots this Mac into ~/migrate/state-new and diffs it against ~/migrate/state:
formulae, casks, apps, login items, LaunchAgents, toolchains, power settings, menu bar
items, keyboard shortcuts, per-host preferences. Changes nothing else.
EOF

NEW="$DATA/state-new"
bash "$BIN/capture.sh" "$NEW" >/dev/null
for f in brew/leaves.txt brew/taps.txt brew/casks.txt apps/applications.txt apps/user-applications.txt \
  apps/manual-apps.txt apps/login-items.txt apps/launchagents-user.txt toolchains.txt \
  etc/pmset.txt statusitems.tsv; do
  if diff -q "$STATE/$f" "$NEW/$f" >/dev/null 2>&1; then
    echo "same     $f"
  else
    echo "DIFFERS  $f"
    diff "$STATE/$f" "$NEW/$f" | head -20
  fi
done
for p in defaults/com.apple.symbolichotkeys.plist defaults/pbs.plist byhost/GlobalPreferences.plist \
  byhost/com.apple.controlcenter.plist; do
  if diff -q <(plutil -p "$STATE/$p" 2>&1) <(plutil -p "$NEW/$p" 2>&1) >/dev/null; then
    echo "same     $p"
  else
    echo "DIFFERS  $p"
    diff <(plutil -p "$STATE/$p" 2>&1) <(plutil -p "$NEW/$p" 2>&1) | head -20
  fi
done
say "" "Expected differences: cask versions, MDM apps, host-specific keys."
finish
