#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Install applications with Homebrew" "$@" <<'EOF'
Installs every cask (and anything else still missing) from the old Mac's Brewfile, then
the casks listed in conf/Brewfile.extra. Expect sudo password prompts.
Do not launch the installed apps yet.
EOF

eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle install --no-upgrade --file="$STATE/brew/Brewfile"
brew bundle install --no-upgrade --file="$CONF/Brewfile.extra"
finish
