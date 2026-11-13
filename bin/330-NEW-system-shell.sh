#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Restore /etc/profile" "$@" <<'EOF'
Shows how /etc/profile differs from the old Mac's copy, then (after a second
confirmation) replaces it with sudo. The current file is kept as /etc/profile.before-migrate.
EOF

if diff /etc/profile "$STATE/etc/profile"; then
  say "/etc/profile is already identical."
else
  confirm
  sudo cp /etc/profile /etc/profile.before-migrate && sudo cp "$STATE/etc/profile" /etc/profile || exit 1
  say "Replaced. Open a new terminal window to pick it up."
fi
finish
