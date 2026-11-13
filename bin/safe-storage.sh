#!/bin/bash
# Optional: carry browser/Electron "Safe Storage" keys so copied profiles stay logged in.
# export: old Mac, GUI terminal (one keychain prompt per item). import: new Mac, before first app launch.
. "$(dirname "$0")/../conf/kit.conf"
F="$STATE/safe-storage.tsv"
items() {
  security dump-keychain "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null |
    awk -F'"' '/^keychain:|^class:/ {a=""} /"acct"<blob>=/ {a=$4} /"svce"<blob>=/ && /Safe Storage/ {print a "|" $4}' | sort -u
}
case "${1:-}" in
list)
  items ;;
export)
  umask 077
  : > "$F"
  items | while IFS='|' read -r acct svc; do
    pw=$(security find-generic-password -a "$acct" -s "$svc" -w 2>/dev/null) || { echo "skipped: $svc"; continue; }
    printf '%s\t%s\t%s\n' "$acct" "$svc" "$pw" >> "$F"
    echo "exported: $svc"
  done ;;
import)
  while IFS=$'\t' read -r acct svc pw; do
    if security find-generic-password -a "$acct" -s "$svc" >/dev/null 2>&1; then
      echo "already present, skipped: $svc"
      continue
    fi
    security add-generic-password -a "$acct" -s "$svc" -w "$pw" && echo "imported: $svc"
  done < "$F" ;;
*)
  echo "usage: $0 list|export|import"; exit 1 ;;
esac
