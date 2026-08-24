#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
VALIDATE="$ROOT/.github/validate.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

suite_count=0
while IFS= read -r suite; do
  [ -n "$suite" ] || continue
  [ -f "$ROOT/$suite" ] || fail "validate.sh declares a missing suite: $suite"
  suite_count=$((suite_count + 1))
done < <(
  awk '
    $0 == "SUITES=(" { inside = 1; next }
    inside && $0 == ")" { exit }
    inside && $1 ~ /^\.github\/test\// { print $1 }
  ' "$VALIDATE"
)

[ "$suite_count" -gt 0 ] || fail 'validate.sh has no registered suites'
if grep -Eq 'CONFIG VALID|SKIPPED|not present \(local suite\)' "$VALIDATE"; then
  fail 'validate.sh still contains a partial-success path for skipped suites'
fi
grep -q 'VALIDATION BLOCKED: required suite is missing' "$VALIDATE" \
  || fail 'validate.sh does not block a missing declared suite'
grep -q 'VALIDATION BLOCKED: shellcheck is required' "$VALIDATE" \
  || fail 'validate.sh does not block missing lint coverage'

# Ejecuta el guard real con una copia mínima del árbol: no basta con que el
# mensaje exista, una suite declarada que falte debe detener la validación.
TMP=$(mktemp -d "${TMPDIR:-/tmp}/validate-contract.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.github/test" "$TMP/config"
ln -s -- "$ROOT/config/claude" "$TMP/config/claude"
for tool in \
  check-provider-runtime-parity.sh \
  check-runtime-parity.sh \
  check-skill-deps.sh \
  compare-task-roadmaps.sh \
  doctor.sh \
  smoke-automatic-workflow.sh \
  smoke-claude-hook-engine.sh; do
  cp "$ROOT/.github/test/$tool" "$TMP/.github/test/$tool"
done
awk '
  $0 == "SUITES=(" {
    print
    print "  .github/test/__missing-contract-suite__.test.sh"
    next
  }
  { print }
' "$VALIDATE" >"$TMP/.github/validate.sh"

set +e
missing_output=$(bash "$TMP/.github/validate.sh" 2>&1)
missing_rc=$?
set -e
[ "$missing_rc" -eq 2 ] || fail "missing suite returned exit $missing_rc instead of 2"
printf '%s\n' "$missing_output" | grep -q 'VALIDATION BLOCKED: required suite is missing' \
  || fail 'missing suite did not block validation'

printf 'PASS: validate.sh registers %s existing suites and has no skipped-suite green path\n' "$suite_count"
