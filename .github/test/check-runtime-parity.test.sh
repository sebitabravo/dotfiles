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
printf '%s' "$initial_json" | jq -e '.parity == false and .failures == 17' >/dev/null || fail 'un runtime vacío debe reportar diecisiete diferencias'

if CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --strict >/dev/null 2>&1; then
  fail '--strict debe fallar con runtime incompleto'
fi

for relative in hooks/secret-detect.sh hooks/user-prompt-dispatcher.sh hooks/validate-safe-ops.sh hooks/quality-gate.sh hooks/protect-tests.sh hooks/protect-codegraph-tracking.sh hooks/privacy-review.sh hooks/detect-debug.sh hooks/handoff-stop.sh hooks/check-auto-save-stash.sh hooks/handoff-session-start.py hooks/compact-resume.py hooks/lib/test-runner.sh skills/handoff/SKILL.md settings.json; do
  mkdir -p "$RUNTIME/$(dirname "$relative")"
  cp "$ROOT/config/claude/$relative" "$RUNTIME/$relative"
done

complete_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json --strict)
printf '%s' "$complete_json" | jq -e '.parity == true and .failures == 0' >/dev/null || fail 'runtime copiado desde la fuente debe pasar'

jq '.hooks.RuntimeOnlyEvent = [{hooks: [{type: "command", command: "runtime-only-hook"}]}]' \
  "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
runtime_only_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json --strict)
printf '%s' "$runtime_only_json" | jq -e '.parity == true and .failures == 0' >/dev/null ||
  fail 'runtime-only de otro evento no debe romper parity gestionada'

# Convivencia: gentle-ai registra su propio hook dentro de un evento gestionado.
# Una entrada ajena no es drift de este repo — lo suyo sigue estando.
jq '.hooks.Stop += [{hooks: [{type: "command", command: "gentle-ai review stop-hook"}]}]' \
  "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
foreign_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json --strict)
printf '%s' "$foreign_json" | jq -e '.parity == true and .failures == 0' >/dev/null ||
  fail 'un hook de otro instalador en un evento gestionado no debe reportar drift'
cp "$ROOT/config/claude/settings.json" "$RUNTIME/settings.json"

# Lo que sí es drift: que falte en el runtime un hook que la fuente declara.
jq '.hooks.Stop = []' "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
missing_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$missing_json" | jq -e '[.results[] | select(.path == "hooks" and .status == "DRIFT")] | length == 1' >/dev/null ||
  fail 'un hook declarado por la fuente que falta en el runtime debe reportar DRIFT'
cp "$ROOT/config/claude/settings.json" "$RUNTIME/settings.json"

jq --arg duplicate "$HOME/.claude/hooks/user-prompt-dispatcher.sh" \
  '.hooks.UserPromptSubmit += [{hooks: [{type: "command", command: $duplicate, timeout: 10}]}]' \
  "$RUNTIME/settings.json" >"$RUNTIME/settings.json.tmp"
mv -- "$RUNTIME/settings.json.tmp" "$RUNTIME/settings.json"
duplicate_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$duplicate_json" | jq -e \
  '[.results[] | select(.path | startswith("UserPromptSubmit:")) | select(.status == "DRIFT" and (.detail | contains("exactamente uno")))] | length == 1' \
  >/dev/null || fail 'aliases tilde/absoluto duplicados deben reportar DRIFT'
cp "$ROOT/config/claude/settings.json" "$RUNTIME/settings.json"

chmod u-x "$RUNTIME/hooks/detect-debug.sh"
mode_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$mode_json" | jq -e '[.results[] | select(.path == "hooks/detect-debug.sh" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un hook no ejecutable debe reportar DRIFT'
chmod u+x "$RUNTIME/hooks/detect-debug.sh"

chmod u-x "$RUNTIME/hooks/compact-resume.py"
python_mode_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$python_mode_json" | jq -e '[.results[] | select(.path == "hooks/compact-resume.py" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un hook Python no ejecutable debe reportar DRIFT'
chmod u+x "$RUNTIME/hooks/compact-resume.py"

before=$(shasum -a 256 "$RUNTIME/hooks/handoff-stop.sh" | awk '{print $1}')
echo '# runtime-only line' >>"$RUNTIME/hooks/handoff-stop.sh"
drift_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$drift_json" | jq -e '[.results[] | select(.path == "hooks/handoff-stop.sh" and .status == "DRIFT")] | length == 1' >/dev/null || fail 'un archivo driftado debe reportar DRIFT'

after=$(shasum -a 256 "$RUNTIME/hooks/handoff-stop.sh" | awk '{print $1}')
[ "$before" != "$after" ] || fail 'el fixture no pudo generar drift'

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" >/dev/null 2>&1 || true
still=$(shasum -a 256 "$RUNTIME/hooks/handoff-stop.sh" | awk '{print $1}')
[ "$after" = "$still" ] || fail 'la auditoría debe ser de solo lectura'

echo 'PASS: runtime parity detecta missing/drift, valida igualdad y no modifica el runtime'
