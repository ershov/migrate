#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
manual "Grant privacy permissions" "$@" <<'EOF'
Privacy permissions cannot be migrated. This opens one Privacy & Security pane at a time
and lists the apps that were allowed on the old Mac. Enable them (use + if an app is not
listed), let the apps restart, then press Enter for the next pane.
EOF

# pane <settings anchor> <TCC service> <pane title>
pane() {
  echo
  echo "== $3"
  grep -h "^$2|" "$STATE/tcc-system.txt" "$STATE/tcc-user.txt" 2>/dev/null | awk -F'|' '$3 == 2 {print "  " $2}' | sort -u
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_$1"
  pause
}
pane Accessibility kTCCServiceAccessibility "Accessibility"
pane ScreenCapture kTCCServiceScreenCapture "Screen & System Audio Recording"
pane ListenEvent kTCCServiceListenEvent "Input Monitoring"
pane AllFiles kTCCServiceSystemPolicyAllFiles "Full Disk Access"
pane Camera kTCCServiceCamera "Camera"
pane Microphone kTCCServiceMicrophone "Microphone"
say "" "Notifications: apps ask on their first notification; click Allow."
finish
