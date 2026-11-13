#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
manual "Clean up" "$@" <<'EOF'
On this Mac:
  rm -f ~/migrate/state/safe-storage.tsv ~/.ssh/cm-*
  rm -rf ~/migrate/stage ~/migrate/backup-*      # after a week without surprises
  Turn Remote Login off if you do not use it.
On the old Mac: keep it untouched for 1-2 weeks as the fallback. Before returning it:
  sign out of Apple ID, deregister the SSO authenticator, then follow IT's wipe procedure.
Machine-specific leftovers: LOCAL.md, section L6.
When this Mac is settled, make it the starting point for the next migration:
  bin/110-OLD-prepare.sh, then bin/120-OLD-inventory.sh.
EOF
pause
finish
