#!/usr/bin/env bash
# Optional receipt-driven development for staged changes.
# Evidence commands are executed as argv (`rdd.sh receipt -- npm test`), never
# through eval, so shell metacharacters cannot become a second command layer.
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run RDD inside a Git repository." >&2
  exit 1
}

STATE="$ROOT/.codex-rdd"
ENABLED="$STATE/enabled"
FROZEN="$STATE/frozen.hash"
RECEIPT="$STATE/receipt.json"

sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256
  else
    sha256sum
  fi
}

hash_staged() {
  {
    git diff --cached --binary
    git diff --cached --name-status
    git diff --cached --stat
  } | sha256 | awk '{print $1}'
}

require_enabled() {
  if [ ! -f "$ENABLED" ]; then
    echo "RDD is off. Run: $0 on" >&2
    exit 1
  fi
}

write_json() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required to write RDD receipts." >&2
    exit 1
  }
  jq -n "$@"
}

command_name="${1:-status}"
shift || true

case "$command_name" in
  on)
    mkdir -p "$STATE"
    : > "$ENABLED"
    echo "RDD enabled at $STATE"
    echo "Add .codex-rdd/ to the repository's .gitignore if this state should stay local."
    ;;
  off)
    rm -f "$ENABLED" "$FROZEN" "$RECEIPT"
    rmdir "$STATE" 2>/dev/null || true
    echo "RDD disabled. Existing repository files were not changed."
    ;;
  status)
    if [ -f "$ENABLED" ]; then
      echo "RDD enabled"
    else
      echo "RDD off"
    fi
    [ -f "$FROZEN" ] && echo "frozen hash: $(cat "$FROZEN")"
    [ -f "$RECEIPT" ] && echo "receipt: $RECEIPT"
    ;;
  freeze)
    require_enabled
    mkdir -p "$STATE"
    HASH="$(hash_staged)"
    printf '%s\n' "$HASH" > "$FROZEN"
    write_json --arg hash "$HASH" --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{hash:$hash,generated_at:$generated_at,staged_files:[]}' > "$STATE/frozen.json"
    git diff --cached --name-only > "$STATE/staged-files.txt"
    echo "Frozen staged diff: $HASH"
    ;;
  verify)
    require_enabled
    [ -f "$FROZEN" ] || { echo "No frozen staged diff. Run: $0 freeze" >&2; exit 1; }
    CURRENT="$(hash_staged)"
    EXPECTED="$(cat "$FROZEN")"
    if [ "$CURRENT" = "$EXPECTED" ]; then
      echo "RDD verify: pass ($CURRENT)"
    else
      echo "RDD verify: fail" >&2
      echo "expected: $EXPECTED" >&2
      echo "current:  $CURRENT" >&2
      exit 1
    fi
    ;;
  receipt)
    require_enabled
    [ -f "$FROZEN" ] || { echo "No frozen staged diff. Run: $0 freeze" >&2; exit 1; }
    [ "${1:-}" = "--" ] || { echo "Usage: $0 receipt -- <evidence-command> [args...]" >&2; exit 2; }
    shift
    [ "$#" -gt 0 ] || { echo "An evidence command is required." >&2; exit 2; }
    if "$@"; then
      RESULT="pass"
      EXIT_CODE=0
    else
      EXIT_CODE=$?
      RESULT="fail"
    fi
    COMMAND_TEXT="$*"
    HASH="$(hash_staged)"
    write_json --arg result "$RESULT" --arg command "$COMMAND_TEXT" --arg hash "$HASH" \
      --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson exit_code "$EXIT_CODE" \
      '{result:$result,command:$command,staged_hash:$hash,exit_code:$exit_code,generated_at:$generated_at}' > "$RECEIPT"
    echo "RDD receipt: $RESULT ($RECEIPT)"
    exit "$EXIT_CODE"
    ;;
  *)
    echo "Usage: $0 {on|off|status|freeze|verify|receipt -- <command> [args...]}" >&2
    exit 2
    ;;
esac
