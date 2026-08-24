#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/.github/test/check-runtime-parity.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/runtime-parity-test.XXXXXX")
RUNTIME="$TMP/.claude"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mkdir -p "$RUNTIME"

initial_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$initial_json" | jq -e '.parity == false and .failures == 16' >/dev/null || fail 'un runtime vacío debe reportar dieciséis diferencias'

if CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --strict >/dev/null 2>&1; then
  fail '--strict debe fallar con runtime incompleto'
fi

for relative in hooks/activate-convergence-on-apply.sh hooks/automatic-workflow.sh hooks/automatic-workflow-stop.sh hooks/secret-detect.sh hooks/convergence-stop.sh hooks/compact-resume.py hooks/lib/test-runner.sh hooks/lib/automatic-workflow-state.sh hooks/task-contract.sh scripts/convergence-start.sh scripts/validate-task-roadmap.py skills/automatic-task-orchestrator/SKILL.md settings.json; do
  mkdir -p "$RUNTIME/$(dirname "$relative")"
  cp "$ROOT/config/claude/$relative" "$RUNTIME/$relative"
done

complete_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json --strict)
printf '%s' "$complete_json" | jq -e '.parity == true and .failures == 0' >/dev/null || fail 'runtime copiado desde la fuente debe pasar'

jq --arg duplicate "$HOME/.claude/hooks/automatic-workflow.sh" \
  '.hooks.UserPromptSubmit += [{hooks: [{type: "command", command: $duplicate, timeout: 10}]}]' \
  "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
duplicate_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$duplicate_json" | jq -e \
  '[.results[] | select(.path | startswith("UserPromptSubmit:")) | select(.status == "DRIFT" and (.detail | contains("exactamente uno")))] | length == 1' \
  >/dev/null || fail 'aliases tilde/absoluto duplicados deben reportar DRIFT'
cp "$ROOT/config/claude/settings.json" "$RUNTIME/settings.json"

chmod u-x "$RUNTIME/hooks/task-contract.sh"
mode_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$mode_json" | jq -e '[.results[] | select(.path == "hooks/task-contract.sh" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un hook no ejecutable debe reportar DRIFT'
chmod u+x "$RUNTIME/hooks/task-contract.sh"

chmod u-x "$RUNTIME/hooks/compact-resume.py"
python_mode_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$python_mode_json" | jq -e '[.results[] | select(.path == "hooks/compact-resume.py" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un hook Python no ejecutable debe reportar DRIFT'
chmod u+x "$RUNTIME/hooks/compact-resume.py"

before=$(shasum -a 256 "$RUNTIME/hooks/convergence-stop.sh" | awk '{print $1}')
echo '# runtime-only line' >>"$RUNTIME/hooks/convergence-stop.sh"
drift_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$drift_json" | jq -e '[.results[] | select(.path == "hooks/convergence-stop.sh" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un archivo driftado debe reportar DRIFT'

after=$(shasum -a 256 "$RUNTIME/hooks/convergence-stop.sh" | awk '{print $1}')
[ "$before" != "$after" ] || fail 'el fixture no pudo generar drift'

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" >/dev/null 2>&1 || true
still=$(shasum -a 256 "$RUNTIME/hooks/convergence-stop.sh" | awk '{print $1}')
[ "$after" = "$still" ] || fail 'la auditoría debe ser de solo lectura'

echo 'PASS: runtime parity detecta missing/drift, valida igualdad y no modifica el runtime'
