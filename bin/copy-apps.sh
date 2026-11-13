#!/bin/bash
# New Mac: copy drag-installed app bundles from the old Mac. Usage: copy-apps.sh "App Name" ...
. "$(dirname "$0")/../conf/kit.conf"
need_old_host
for a in "$@"; do
  a=${a%.app}
  if [ -e "/Applications/$a.app" ]; then echo "exists, skipped: $a"; continue; fi
  "$RSYNC" -aHXN -e "$SSH" --rsync-path="$RSYNC" "$OLD_USER@$OLD_HOST:/Applications/$a.app" /Applications/ &&
    echo "copied: $a"
done
