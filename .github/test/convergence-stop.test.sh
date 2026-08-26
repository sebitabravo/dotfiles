#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/convergence-stop.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/convergence-stop-test.XXXXXX")
trap 'find "$TMP" -type f -delete; find "$TMP" -depth -type d -empty -delete 2>/dev/null || true' EXIT

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/.claude/convergence" "$TMP/openspec/changes/example-change"
git -C "$TMP" init -q

cat >"$TMP/bin/openspec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case " $* " in
  *" status --change "*)
    jq -n --arg root "$PWD/openspec/changes/example-change" '{changeRoot:$root,artifacts:{tasks:{status:"done"}}}'
    ;;
  *" instructions apply --change "*)
    if [ "${OPEN_SPEC_STATE:-ready}" = blocked ]; then
      jq -n '{state:"blocked",missingArtifacts:["tasks"],progress:{remaining:1}}'
    else
      jq -n --argjson remaining "${OPEN_SPEC_REMAINING:-0}" '{state:"ready",progress:{remaining:$remaining}}'
    fi
    ;;
  *" validate "*)
    [ "${OPEN_SPEC_VALIDATE:-pass}" = pass ]
    ;;
  *)
    printf '%s\n' '{}'
    ;;
esac
EOF
chmod +x "$TMP/bin/openspec"

cat >"$TMP/test.sh" <<'EOF'
#!/usr/bin/env bash
exit "${VERIFY_RC:-0}"
EOF
chmod +x "$TMP/test.sh"

cat >"$TMP/.claude/convergence/example-change.receipt" <<'EOF'
CHANGE: example-change
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0
EOF
printf '%s\n' 'example-change' >"$TMP/.claude/convergence.active"

run_hook() {
  (cd "$TMP" && printf '%s' "${1:-{}}" | env \
    HOME="$TMP/home" \
    PATH="$TMP/bin:$PATH" \
    VERIFY_RC="${VERIFY_RC:-0}" \
    OPEN_SPEC_STATE="${OPEN_SPEC_STATE:-ready}" \
    OPEN_SPEC_REMAINING="${OPEN_SPEC_REMAINING:-0}" \
    OPEN_SPEC_VALIDATE="${OPEN_SPEC_VALIDATE:-pass}" \
    "$HOOK")
}

expect_rc() {
  local expected=$1
  shift
  local actual
  set +e
  "$@"
  actual=$?
  set -e
  [ "$actual" -eq "$expected" ] || {
    printf 'expected rc=%s, got rc=%s\n' "$expected" "$actual" >&2
    return 1
  }
}

printf '%s\n' '== no active marker is a no-op'
mv "$TMP/.claude/convergence.active" "$TMP/.claude/convergence.active.off"
run_hook
mv "$TMP/.claude/convergence.active.off" "$TMP/.claude/convergence.active"

printf '%s\n' '== pending OpenSpec tasks block'
expect_rc 2 env OPEN_SPEC_REMAINING=2 VERIFY_RC=0 bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" PATH="$1/bin:$PATH" OPEN_SPEC_REMAINING="$2" "$3"' sh "$TMP" 2 "$HOOK"

printf '%s\n' '== blocked artifact state blocks'
expect_rc 2 env OPEN_SPEC_STATE=blocked bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" PATH="$1/bin:$PATH" OPEN_SPEC_STATE=blocked "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== failed native verification blocks'
expect_rc 2 env VERIFY_RC=1 bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" PATH="$1/bin:$PATH" VERIFY_RC=1 "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== failed validation blocks'
expect_rc 2 env OPEN_SPEC_VALIDATE=fail bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" PATH="$1/bin:$PATH" OPEN_SPEC_VALIDATE=fail "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== stop_hook_active does not turn a failing gate green'
expect_rc 2 env VERIFY_RC=1 bash -c 'cd "$2" && printf "%s" "$1" | env HOME="$2/home" PATH="$2/bin:$PATH" VERIFY_RC=1 "$3"' sh '{"stop_hook_active":true}' "$TMP" "$HOOK"

printf '%s\n' '== complete change passes with fresh native verification'
run_hook

printf '%s\n' 'PASS: convergence stop gate fixtures'
