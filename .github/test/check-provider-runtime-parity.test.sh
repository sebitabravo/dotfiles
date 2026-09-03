#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/.github/test/check-provider-runtime-parity.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/provider-parity-test.XXXXXX")
RUNTIME="$TMP/.claude"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$RUNTIME"

initial_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$initial_json" | jq -e '.parity == false and .failures == 4' >/dev/null

if CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --strict >/dev/null 2>&1; then
  echo 'FAIL: --strict debe fallar con overlays ausentes' >&2
  exit 1
fi

for overlay in deepseek.settings.json glm.settings.json ollama.settings.json openrouter.settings.json; do
  cp "$ROOT/config/claude/$overlay" "$RUNTIME/$overlay"
done

# El runtime puede fijar el ID concreto equivalente al alias `opus`; no es
# drift funcional. El orden/formato JSON tampoco cambia la configuración.
# shellcheck disable=SC2043
for overlay in ollama.settings.json; do
  tmp_json="$RUNTIME/$overlay.tmp"
  jq -c '.env.ANTHROPIC_MODEL = .env.ANTHROPIC_DEFAULT_OPUS_MODEL' "$RUNTIME/$overlay" >"$tmp_json"
  mv "$tmp_json" "$RUNTIME/$overlay"
done

match_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json --strict)
printf '%s' "$match_json" | jq -e '.parity == true and .failures == 0' >/dev/null

before=$(shasum -a 256 "$RUNTIME/openrouter.settings.json" | awk '{print $1}')
tmp_json="$RUNTIME/openrouter.settings.json.tmp"
jq '. + {runtimeOnly: true}' "$RUNTIME/openrouter.settings.json" >"$tmp_json"
mv "$tmp_json" "$RUNTIME/openrouter.settings.json"
drift_json=$(CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" --json)
printf '%s' "$drift_json" | jq -e '[.results[] | select(.path == "openrouter.settings.json" and .status == "DRIFT")] | length == 1' >/dev/null
after=$(shasum -a 256 "$RUNTIME/openrouter.settings.json" | awk '{print $1}')
[ "$before" != "$after" ]

CLAUDE_RUNTIME_DIR="$RUNTIME" "$SCRIPT" >/dev/null 2>&1 || true
still=$(shasum -a 256 "$RUNTIME/openrouter.settings.json" | awk '{print $1}')
[ "$after" = "$still" ]

echo 'PASS: provider parity detecta missing/drift, valida igualdad y no modifica el runtime'
