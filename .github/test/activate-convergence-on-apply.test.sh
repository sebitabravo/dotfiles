#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/activate-convergence-on-apply.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/activate-convergence-test.XXXXXX")
trap 'find "$TMP" -type f -delete; find "$TMP" -depth -type d -empty -delete 2>/dev/null || true' EXIT

mkdir -p "$TMP/bin" "$TMP/.claude" "$TMP/openspec"
git -C "$TMP" init -q
cat >"$TMP/bin/openspec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${OPEN_SPEC_START_LIST:-one}" = one ]; then
  jq -n '{changes:[{name:"example-change"}]}'
else
  jq -n '{changes:[]}'
fi
EOF
chmod +x "$TMP/bin/openspec"
cat >"$TMP/bin/start" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >"$PWD/start-arg"
if [ "${START_FAIL:-false}" = true ]; then
  echo 'start failed' >&2
  exit 1
fi
EOF
chmod +x "$TMP/bin/start"

payload() {
  jq -nc --arg cwd "$TMP" --arg prompt "$1" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$prompt}'
}

printf '%s\n' '== unrelated prompt is a no-op'
payload 'hola' | env PATH="$TMP/bin:$PATH" CLAUDE_CONVERGENCE_START="$TMP/bin/start" "$HOOK"
[ ! -e "$TMP/start-arg" ]

printf '%s\n' '== explicit /opsx:apply activates selected change'
payload '/opsx:apply example-change' | env PATH="$TMP/bin:$PATH" CLAUDE_CONVERGENCE_START="$TMP/bin/start" "$HOOK"
[ "$(cat "$TMP/start-arg")" = example-change ]

printf '%s\n' '== one active change is auto-selected'
find "$TMP" -type f -name start-arg -delete
payload '/opsx:apply' | env PATH="$TMP/bin:$PATH" CLAUDE_CONVERGENCE_START="$TMP/bin/start" "$HOOK"
[ "$(cat "$TMP/start-arg")" = example-change ]

printf '%s\n' '== activation failure blocks prompt processing'
set +e
payload '/opsx:apply example-change' | env PATH="$TMP/bin:$PATH" CLAUDE_CONVERGENCE_START="$TMP/bin/start" START_FAIL=true "$HOOK" >/dev/null 2>"$TMP/error"
RC=$?
set -e
[ "$RC" -eq 2 ]
grep -Fq 'no se pudo activar el gate' "$TMP/error"

printf '%s\n' 'PASS: automatic convergence activation fixtures'
