# Helpers for step scripts (bin/NN-OLD|NEW-name.sh). Sourced, not run.
# Step numbers give the execution order across both Macs; the hundreds digit is the phase.
# Flags handled here: -n/--dry-run (print what the step does and exit), -y/--yes (no prompts).
. "$(dirname "${BASH_SOURCE[0]}")/../conf/kit.conf"

SELF=$(basename "$0")
STEP_ID=${SELF%%-*}
STEP_ROLE=$(echo "$SELF" | cut -d- -f2)
YES=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    -y | --yes) YES=1 ;;
    -n | --dry-run | --dry) DRY=1 ;;
  esac
done
CHECK_FAILED=0

say() { printf '%s\n' "$@"; }
die() { echo "ERROR: $*" >&2; exit 1; }
hw_uuid() { ioreg -d2 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/ {print $4}'; }
has_fda() { ls "$HOME/Library/Application Support/com.apple.TCC" >/dev/null 2>&1; }

banner() {
  echo
  echo "==> Step $STEP_ID ($STEP_ROLE Mac): $1"
  echo "    Details: MACOS-MIGRATE.md, \"Step $STEP_ID\""
  echo
}

# OLD steps run on the Mac recorded by 110-OLD-prepare.sh; NEW steps on any other Mac.
role_guard() {
  case "$STEP_ROLE" in
    OLD)
      case "$SELF" in *-OLD-prepare.sh) return ;; esac
      [ "$(hw_uuid)" = "${OLD_UUID:-}" ] ||
        die "this Mac is not recorded as the old Mac. If you are migrating FROM this Mac, run bin/110-OLD-prepare.sh first."
      ;;
    NEW)
      [ -n "${OLD_UUID:-}" ] ||
        die "conf/kit.local.conf has no OLD_UUID. Copy the repository from the old Mac (bin/150-OLD-handover.sh prints how)."
      [ "$(hw_uuid)" != "$OLD_UUID" ] || die "this is the old Mac; NEW steps run on the new Mac."
      ;;
  esac
}

confirm() {
  [ "$YES" = 1 ] && return
  printf 'Proceed? [y/N] '
  read -r ans < /dev/tty || die "no terminal for the prompt: use -y (or ssh -t)."
  case "$ans" in
    y | Y | yes) ;;
    *) echo "aborted"; exit 1 ;;
  esac
}

pause() {
  [ "$YES" = 1 ] && return
  printf 'Press Enter when done (Ctrl-C to abort) '
  read -r _ < /dev/tty || die "no terminal for the prompt: use -y (or ssh -t)."
}

# step "Title" <<EOF ... EOF : automated step. Prints what it will do, then asks to proceed.
step() {
  banner "$1"
  cat
  echo
  [ "$DRY" = 1 ] && exit 0
  role_guard
  confirm
}

# manual "Title" <<EOF ... EOF : manual step. Prints the instructions; nothing is changed.
manual() {
  banner "$1 [manual]"
  cat
  echo
  [ "$DRY" = 1 ] && exit 0
  role_guard
}

# check "description" command... : report ok/FAIL; checks_done aborts if any failed.
check() {
  desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  ok    $desc"
  else
    echo "  FAIL  $desc"
    CHECK_FAILED=1
  fi
}
checks_done() { [ "$CHECK_FAILED" = 0 ] || die "fix the failed checks, then re-run $SELF."; }

# Print the step(s) that follow this one. Scripts sharing a number (310a, 310b) are alternatives.
finish() {
  echo
  echo "Done: $SELF"
  cur=${STEP_ID%[a-z]}
  nxt=""
  for f in $(cd "$BIN" && ls | grep '^[0-9]' | LC_ALL=C sort); do
    n=${f%%-*}
    n=${n%[a-z]}
    if [ -z "$nxt" ] && [ "$n" -gt "$cur" ]; then nxt=$n; fi
    if [ -n "$nxt" ] && [ "$n" = "$nxt" ]; then
      r=$(echo "$f" | cut -d- -f2)
      if [ "$r" = "$STEP_ROLE" ]; then echo "Next: bin/$f"; else echo "Next: bin/$f  (on the $r Mac)"; fi
    fi
  done
  [ -n "$nxt" ] || echo "That was the last step."
}
