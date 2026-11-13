#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Homebrew: copy the prefix from the old Mac (recommended)" "$@" <<'EOF'
Alternative to 310b; run only one of them.
Creates /opt/homebrew (sudo) and copies the old Mac's prefix over SSH, without Caskroom:
identical formula versions, minutes instead of an hour. Casks are installed by step 410.
EOF

[ ! -e /opt/homebrew/bin/brew ] || die "Homebrew is already installed here."
sudo mkdir -p /opt/homebrew && sudo chown "$(id -un)":admin /opt/homebrew || exit 1
$SSH "$OLD_USER@$OLD_HOST" 'tar -C /opt/homebrew --exclude ./Caskroom -cf - .' |
  caffeinate -i tar -C /opt/homebrew -xpf - || exit 1
/opt/homebrew/bin/brew doctor
check "brew runs" /opt/homebrew/bin/brew --version
check "GNU rsync is installed" test -x "$RSYNC"
checks_done
finish
