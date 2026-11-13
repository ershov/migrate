#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Fetch the final snapshot" "$@" <<'EOF'
Run after 220-OLD-freeze.sh: the old Mac must sit at its login window.
Copies the old Mac's ~/migrate/state to this Mac.
EOF

old_logged_out() { [ "$($SSH "$OLD_USER@$OLD_HOST" 'stat -f %Su /dev/console')" != "$OLD_USER" ]; }
check "old Mac is logged out of the console" old_logged_out
checks_done
/usr/bin/rsync -a -e "$SSH" "$OLD_USER@$OLD_HOST:${STATE#"$HOME"/}/" "$STATE/" || exit 1
finish
