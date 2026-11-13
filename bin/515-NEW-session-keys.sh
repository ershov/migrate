#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Optional: import browser and Electron session keys" "$@" <<'EOF'
Only if 145-OLD-session-keys.sh was run. Writes the exported "... Safe Storage" items into
this Mac's login keychain. Must happen before the affected apps are launched here for
the first time; items that already exist are skipped.
EOF

[ -f "$STATE/safe-storage.tsv" ] || die "no $STATE/safe-storage.tsv: nothing was exported on the old Mac."
bash "$BIN/safe-storage.sh" import
finish
