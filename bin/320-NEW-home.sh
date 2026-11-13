#!/bin/bash
. "$(dirname "$0")/../lib/step.sh"
step "Pull the home directory" "$@" <<'EOF'
Copies everything under ~ from the old Mac with rsync, except ~/Library and the entries
in conf/excludes-home.txt. Existing files with the same name are overwritten; nothing is
deleted. Safe to re-run. Can take a long time; the Mac is kept awake.
EOF

[ -x "$RSYNC" ] || die "missing $RSYNC: run step 310 first."
caffeinate -i "$RSYNC" $RSYNC_OPTS -e "$SSH" --rsync-path="$RSYNC" \
  --exclude-from="$CONF/excludes-home.txt" "$OLD_USER@$OLD_HOST:./" "$HOME/"
say "rsync exit code: $? (0 = complete; 23/24 = some files could not be read, see the messages)"
finish
