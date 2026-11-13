#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Restore power settings; list settings to redo by hand" "$@" <<'EOF'
Applies the old Mac's display-sleep and sleep timers (battery and AC) with sudo pmset.
Then lists the settings that are bound to hardware and must be redone by hand.
EOF

awk '/^Battery Power/ {f = "-b"} /^AC Power/ {f = "-c"} $1 == "displaysleep" || $1 == "sleep" {print f, $1, $2}' \
  "$STATE/etc/pmset.txt" | while read -r flag key value; do
  echo "pmset $flag $key $value"
  sudo pmset "$flag" "$key" "$value"
done

say "" "By hand:" \
  "  - Displays: resolution/scaling, arrangement, Night Shift." \
  "  - Sound input/output devices." \
  "  - Wallpaper, if the copied one did not apply." \
  "  - Menu bar order, if it differs: Cmd-drag, or bin/statusitems.sh." \
  "  - Sandboxed apps and other per-app items: LOCAL.md, section L5." ""
pause
finish
