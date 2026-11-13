#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
manual "Export app data that a file copy cannot carry" "$@" <<'EOF'
Only for the apps you use. Save exports under ~/migrate/ so they travel with the home directory.
  - Raycast: run "Export Settings & Data", save the .rayconfig (password protected).
  - BetterTouchTool: Presets > Export.
  - iStat Menus, Bartender, Rectangle: Settings > Export.
  - Make sure license keys are reachable from the new Mac.
Machine-specific exports: LOCAL.md, section L1.
EOF
pause
finish
