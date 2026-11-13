#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Optional: export browser and Electron session keys" "$@" <<'EOF'
Reads every "... Safe Storage" item from the login keychain into
~/migrate/state/safe-storage.tsv, so copied browser and app profiles stay logged in.
macOS asks for your login password once per item. The file is sensitive.
Skip this step if you prefer to sign in again everywhere.
EOF

bash "$BIN/safe-storage.sh" export
finish
