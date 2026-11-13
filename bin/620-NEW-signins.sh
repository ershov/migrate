#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
manual "Sign in again" "$@" <<'EOF'
The keychain is not migrated. In this order:
  1. SSO authenticator, VPN (if not done at first boot).
  2. Browsers and chat apps: sign in, or enable sync (not needed where step 515 was used).
  3. Claude Code: run "claude", then /login, then /mcp for OAuth servers.
  4. Editors: sign in to GitHub / Settings Sync.
  5. Wi-Fi networks, Bluetooth devices, Touch ID, Apple ID.
  6. Apps that ask for a license key.
Then the machine-specific list: LOCAL.md, section L4.
EOF
pause
finish
