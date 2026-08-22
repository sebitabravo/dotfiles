#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
START="$ROOT/config/claude/scripts/convergence-start.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/convergence-start-test.XXXXXX")
trap 'find "$TMP" -type f -delete; find "$TMP" -depth -type d -empty -delete 2>/dev/null || true' EXIT

mkdir -p "$TMP/bin" "$TMP/openspec/changes/example-change"
git -C "$TMP" init -q
cat >"$TMP/bin/openspec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
jq -n --arg change "${3:-example-change}" --arg root "$PWD/openspec/changes/example-change" \
  '{changeName:$change,changeRoot:$root,artifacts:{tasks:{status:"ready"}}}'
EOF
chmod +x "$TMP/bin/openspec"

printf '%s\n' '== starts a valid OpenSpec convergence gate'
(cd "$TMP" && PATH="$TMP/bin:$PATH" "$START" example-change) >/dev/null
[ "$(cat "$TMP/.claude/convergence.active")" = example-change ]
grep -Fxq 'STATUS: PENDING' "$TMP/.claude/convergence/example-change.receipt"

printf '%s\n' '== rejects unsafe change names'
set +e
(cd "$TMP" && PATH="$TMP/bin:$PATH" "$START" '../outside') >/dev/null 2>&1
RC=$?
set -e
[ "$RC" -eq 64 ]

printf '%s\n' 'PASS: convergence start fixtures'
