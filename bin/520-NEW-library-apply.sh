#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
# shellcheck disable=SC2088
R="~/${REPO#"$HOME"/}"
step "Apply the staged ~/Library" "$@" <<EOF
Must run over SSH while you are logged OUT of this Mac's console (Apple menu > Log Out).
From another machine, for example the old Mac after logging in there again:

  ssh -t $(id -un)@$(scutil --get LocalHostName).local $R/bin/$SELF

Saves the current ~/Library/Preferences to ~/migrate/backup-<time>, then copies the staged
tree into ~/Library (sandbox containers excluded).
EOF

U=$(id -un)
[ "$(stat -f %Su /dev/console)" != "$U" ] || die "$U is logged in at the console. Log out, then run this over SSH as shown above."
[ -d "$STAGE/Library/Preferences" ] || die "nothing staged in $STAGE: run step 510 first."
B="$DATA/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$B" && cp -Rp "$HOME/Library/Preferences" "$B/"
killall -u "$U" cfprefsd 2>/dev/null
"$RSYNC" -aHXN --filter=-x_com.apple.macl --exclude '/Containers/' "$STAGE/Library/" "$HOME/Library/"
say "rsync exit code: $?; previous Preferences saved in $B"
killall -u "$U" cfprefsd usernoted 2>/dev/null
say "" "Now log in at the console. Open nothing before running the next step."
finish
