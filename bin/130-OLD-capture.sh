#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Snapshot the old Mac" "$@" <<'EOF'
Writes the migration snapshot to ~/migrate/state: Brewfile, app lists, login items,
per-host preferences, menu bar positions, shortcut backups, privacy grants, system files.
Changes nothing else. Re-run any time; it overwrites the previous snapshot.
EOF

bash "$BIN/capture.sh" "$STATE" || exit 1
check "privacy grants captured (needs Full Disk Access)" grep -q kTCCService "$STATE/tcc-user.txt"
check "login items captured" test -s "$STATE/apps/login-items.txt"
checks_done
finish
