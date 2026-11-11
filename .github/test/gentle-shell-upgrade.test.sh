#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ZSHRC="$ROOT/.zshrc"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/gentle-shell-upgrade.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

command -v zsh >/dev/null 2>&1 || fail 'zsh is required'

SNIPPET="$TMP/snippet.zsh"
awk '
  /^# Gentle Shell: / { inside = 1 }
  inside { print }
  inside && /^unset _gs_log$/ { exit }
' "$ZSHRC" >"$SNIPPET"
[ -s "$SNIPPET" ] || fail '.zshrc has no Gentle Shell upgrade block'
grep -qx 'unset _gs_log' "$SNIPPET" || fail 'Gentle Shell upgrade block is not terminated'

BIN="$TMP/bin"
CALLS="$TMP/calls.log"
LOG="$TMP/cache/gentle-shell-upgrade.log"
mkdir -p "$BIN"
: >"$CALLS"
cat >"$BIN/gentle-shell" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>'$CALLS'
printf '%s\n' 'stub upgrade output'
EOF
chmod +x "$BIN/gentle-shell"

run_shell() {
  HOME="$TMP" XDG_CACHE_HOME="$TMP/cache" PATH="$1:/usr/bin:/bin" \
    zsh -f -i -c "source '$SNIPPET'" </dev/null >"$TMP/shell.out" 2>&1
  [ ! -s "$TMP/shell.out" ] || fail "upgrade block printed to the terminal: $(cat "$TMP/shell.out")"
}

wait_for_calls() {
  local expected=$1 attempt=0
  while [ "$(wc -l <"$CALLS" | tr -d ' ')" -ne "$expected" ]; do
    attempt=$((attempt + 1))
    [ "$attempt" -le 30 ] || return 1
    sleep 0.1
  done
}

run_shell "$BIN"
wait_for_calls 1 || fail 'first interactive shell did not start the upgrade'
grep -qx 'upgrade' "$CALLS" || fail 'upgrade was not invoked as "gentle-shell upgrade"'
[ -f "$LOG" ] || fail 'upgrade output was not written to the cache log'

run_shell "$BIN"
sleep 0.3
wait_for_calls 1 || fail 'upgrade ran again within 24 hours'

touch -t 202001010000 "$LOG"
run_shell "$BIN"
wait_for_calls 2 || fail 'upgrade did not run after the log went stale'

: >"$CALLS"
rm -f -- "$LOG"
run_shell "$TMP/empty-bin"
sleep 0.3
wait_for_calls 0 || fail 'upgrade ran without gentle-shell on PATH'
[ ! -e "$LOG" ] || fail 'cache log was created without gentle-shell on PATH'

printf '%s\n' 'PASS: Gentle Shell upgrade runs in the background at most once a day'
