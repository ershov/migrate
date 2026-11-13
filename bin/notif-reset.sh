#!/bin/bash
# Remove an app's notification registration from ncprefs and the usernoted DB so it re-prompts.
# Usage: notif-reset.sh <bundle-id> ...   (terminal needs Full Disk Access)
[ $# -gt 0 ] || { echo "usage: $0 bundle-id ..."; exit 1; }
DB="$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db"
NC="$HOME/Library/Preferences/com.apple.ncprefs.plist"
. "$(dirname "$0")/../conf/kit.conf"
B="$DATA/backup-notif-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$B"
cp "$DB" "$B/usernoted-db" || { echo "usernoted DB unreadable: give this terminal Full Disk Access"; exit 1; }
cp "$NC" "$B/ncprefs.plist"
for id in "$@"; do
  [ "$(osascript -e "application id \"$id\" is running" 2>/dev/null)" = true ] &&
    osascript -e "tell application id \"$id\" to quit"
done
sleep 3
killall usernoted 2>/dev/null
sleep 1
python3 - "$DB" "$NC" "$@" <<'EOF'
import plistlib, sqlite3, sys
db, nc, ids = sys.argv[1], sys.argv[2], [i.lower() for i in sys.argv[3:]]
with open(nc, 'rb') as f:
    d = plistlib.load(f)
before = len(d.get('apps', []))
d['apps'] = [a for a in d.get('apps', []) if a.get('bundle-id', '').lower() not in ids]
with open(nc, 'wb') as f:
    plistlib.dump(d, f, fmt=plistlib.FMT_BINARY)
con = sqlite3.connect(db)
rows = sum(con.execute('delete from app where lower(identifier)=?', (i,)).rowcount for i in ids)
con.commit()
print(f"ncprefs entries removed: {before - len(d['apps'])}; usernoted rows removed: {rows}")
EOF
killall usernoted cfprefsd 2>/dev/null
echo "Relaunch the app and trigger a notification; answer Allow. Backup: $B"
