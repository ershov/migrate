#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Prepare the new Mac" "$@" <<'EOF'
Installs Rosetta, creates ~/.ssh, sets the login shell to the one used on the old Mac.
Then asks you to enable remote access and checks that this Mac matches the old one
(user name, home path) and can reach it over SSH.
EOF

softwareupdate --install-rosetta --agree-to-license
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
OLD_SHELL=$(awk '/^UserShell:/ {print $2}' "$STATE/system.txt")
NOW_SHELL=$(dscl . -read "/Users/$(id -un)" UserShell | awk '{print $2}')
[ "$NOW_SHELL" = "$OLD_SHELL" ] || chsh -s "$OLD_SHELL"

say "" "Now, by hand, in System Settings:" \
  "  1. General > Sharing > Remote Login: on. Click (i): allow access for your user only," \
  "     and turn on \"Allow full disk access for remote users\"." \
  "  2. Privacy & Security > Full Disk Access: add this terminal app, then restart the terminal." \
  "  3. Connect AC power." ""
pause
say "old Mac: macOS $(awk '/^ProductVersion:/ {print $2}' "$STATE/system.txt"); this Mac: macOS $(sw_vers -productVersion)"
check "same user name as on the old Mac" grep -q "^user=$(id -un) " "$STATE/system.txt"
check "same home path as on the old Mac" grep -q "home=$HOME\$" "$STATE/system.txt"
check "Command Line Tools are installed" xcode-select -p
check "Remote Login is on" nc -z -G 1 localhost 22
check "this terminal has Full Disk Access" has_fda
check "old Mac answers over SSH ($OLD_HOST)" $SSH "$OLD_USER@$OLD_HOST" true
checks_done
finish
