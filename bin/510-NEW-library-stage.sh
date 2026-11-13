#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Stage the ~/Library subset" "$@" <<'EOF'
Pulls the part of the old Mac's ~/Library selected by conf/library-rules.txt into
~/migrate/stage/Library. Nothing live is touched. Safe to re-run.
EOF

[ -x "$RSYNC" ] || die "missing $RSYNC: run step 310 first."
mkdir -p "$STAGE/Library"
caffeinate -i "$RSYNC" $RSYNC_OPTS -e "$SSH" --rsync-path="$RSYNC" \
  --filter="merge $CONF/library-rules.txt" "$OLD_USER@$OLD_HOST:Library/" "$STAGE/Library/"
say "rsync exit code: $? (0 = complete; 23/24 = some files could not be read, see the messages)"
check "preferences were staged" test -f "$STAGE/Library/Preferences/.GlobalPreferences.plist"
checks_done
finish
