#!/bin/bash
# List the migration steps in order. Usage: steps.sh [--check]
# --check: verify that every step has a "Step N" heading in MACOS-MIGRATE.md and vice versa.
. "$(dirname "$0")/../conf/kit.conf"
cd "$BIN" || exit 1

if [ "${1:-}" = "--check" ]; then
  if diff <(ls | grep '^[0-9]' | sed 's/-.*//' | sort) \
    <(sed -nE 's/^#+ Step ([0-9]+[a-z]?) .*/\1/p' "$REPO/MACOS-MIGRATE.md" | sort); then
    echo "guide and bin/ agree"
    exit 0
  fi
  echo "< step without guide heading   > heading without step"
  exit 1
fi

printf '%-5s %-4s %-7s %s\n' STEP MAC KIND TITLE
for f in $(ls | grep '^[0-9]' | LC_ALL=C sort); do
  id=${f%%-*}
  role=$(echo "$f" | cut -d- -f2)
  if grep -q '^manual "' "$f"; then kind=manual; else kind=auto; fi
  title=$(sed -nE 's/^(step|manual) "([^"]*)".*/\2/p' "$f" | head -1)
  printf '%-5s %-4s %-7s %s\n' "$id" "$role" "$kind" "$title"
done
echo
echo "Run them in this order, each on the Mac in the MAC column: bin/<step file>"
echo "Flags: -n, --dry-run (describe only, change nothing); -y, --yes (no prompts)"
echo "Same number with a letter (310a, 310b) = alternatives; run one."
