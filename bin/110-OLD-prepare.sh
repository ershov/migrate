#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Prepare the old Mac" "$@" <<'EOF'
Records this Mac as the old Mac in conf/kit.local.conf (hardware UUID and host name).
Installs GNU rsync with Homebrew if it is missing.
Then asks you to enable remote access and checks the result.
EOF

L="$CONF/kit.local.conf"
touch "$L"
grep -vE '^(OLD_UUID|OLD_HOST)=' "$L" > "$L.tmp"
{
  cat "$L.tmp"
  echo "OLD_UUID=$(hw_uuid)"
  echo "OLD_HOST=$(scutil --get LocalHostName).local"
} > "$L"
rm -f "$L.tmp"
[ -x "$RSYNC" ] || brew install rsync

say "" "Now, by hand, in System Settings:" \
  "  1. General > Sharing > Remote Login: on. Click (i): allow access for your user only," \
  "     and turn on \"Allow full disk access for remote users\"." \
  "  2. Privacy & Security > Full Disk Access: add this terminal app, then restart the terminal." \
  "  3. Connect AC power." ""
pause
check "GNU rsync is installed" test -x "$RSYNC"
check "Remote Login is on" nc -z -G 1 localhost 22
check "this terminal has Full Disk Access" has_fda
checks_done
finish
