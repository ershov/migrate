#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Freeze the old Mac" "$@" <<'EOF'
Takes the final snapshot. Afterwards you quit all apps and log out, so every preference
file on disk is complete while the new Mac copies from this one.
EOF

bash "$BIN/capture.sh" "$STATE" || exit 1
say "" "Now, by hand:" \
  "  1. Quit all apps." \
  "  2. Apple menu > Log Out. Do NOT restart or shut down: FileVault would block SSH." \
  "  3. Leave this Mac on AC power with the lid open."
finish
