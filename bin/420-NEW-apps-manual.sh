#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
manual "Install the remaining applications" "$@" <<'EOF'
Follow LOCAL.md, section L2: Self Service apps, App Store apps, and app bundles to copy
with bin/copy-apps.sh. Do not launch the apps yet.
Apps that were in /Applications on the old Mac and are missing here:
EOF

missing() {
  while IFS= read -r a; do
    [ -e "/Applications/$a" ] || echo "  $a"
  done < "$STATE/apps/applications.txt"
}
missing
pause
say "Still missing (fine if intended):"
missing
finish
