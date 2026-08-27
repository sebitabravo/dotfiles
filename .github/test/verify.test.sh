#!/usr/bin/env bash
# shellcheck disable=SC2016 # The assertion intentionally matches a literal shell variable.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
VERIFY="$ROOT/.github/verify.sh"
DEFAULTS="$ROOT/config/macos/defaults.sh"

[ -f "$DEFAULTS" ] || {
  printf 'FAIL: authoritative macOS defaults source is missing: %s\n' "$DEFAULTS" >&2
  exit 1
}
bash -n "$VERIFY"
grep -Fq 'DEFAULTS_SH="$ROOT/config/macos/defaults.sh"' "$VERIFY" ||
  {
    printf 'FAIL: verify.sh does not resolve the authoritative defaults source\n' >&2
    exit 1
  }

printf '%s\n' 'PASS: verify.sh resolves config/macos/defaults.sh'
