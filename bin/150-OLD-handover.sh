#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
H="$(scutil --get LocalHostName).local"
# shellcheck disable=SC2088
R="~/${REPO#"$HOME"/}"
manual "Hand over to the new Mac" "$@" <<EOF
On the NEW Mac, first boot:
  1. Setup Assistant: skip Migration Assistant / "Transfer your data".
  2. Complete MDM enrolment. The account must be "$(id -un)" with home $HOME.
  3. Re-enrol the SSO authenticator. Install macOS updates (this Mac runs $(sw_vers -productVersion)).
  4. Change no settings yet; copied settings will overwrite them.

Connect the two Macs with a Thunderbolt cable. Then type on the NEW Mac:

  xcode-select --install          # wait until the installer has finished
  mkdir -p ${R%/*} ~/migrate ~/.ssh && chmod 700 ~/.ssh
  rsync -a --exclude .tmp $(id -un)@$H:${REPO#"$HOME"/} ${R%/*}/
  rsync -a $(id -un)@$H:migrate/state ~/migrate/
  $R/bin/210-NEW-prepare.sh

If $H does not resolve there, use this Mac's Thunderbolt Bridge address instead
(ipconfig getifaddr bridge0) and put it into OLD_HOST in conf/kit.local.conf on the new Mac.
Keep this Mac logged in until 210-NEW-prepare.sh has passed on the new Mac.
EOF
pause
finish
