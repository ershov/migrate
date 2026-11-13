#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Homebrew: clean install" "$@" <<'EOF'
Alternative to 310a; run only one of them.
Runs the official Homebrew installer and installs GNU rsync. Formulae are then
downloaded fresh by step 410. Slower; use it when the Macs run different macOS versions.
EOF

[ ! -e /opt/homebrew/bin/brew ] || die "Homebrew is already installed here."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1
/opt/homebrew/bin/brew install rsync
check "brew runs" /opt/homebrew/bin/brew --version
check "GNU rsync is installed" test -x "$RSYNC"
checks_done
finish
