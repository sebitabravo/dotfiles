#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/privacy-review.sh"

run_hook() {
  jq -nc --arg command "$1" '{tool_name:"Bash",tool_input:{command:$command}}' |
    bash "$HOOK"
}

assert_pass() {
  local output
  output=$(run_hook "$1" 2>&1)
  [[ -z "$output" ]] || {
    printf 'expected pass for %s, got: %s\n' "$1" "$output" >&2
    return 1
  }
}

assert_blocked_redacted() {
  local command=$1 forbidden=$2 output rc
  set +e
  output=$(run_hook "$command" 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]] || {
    printf 'expected block for %s, rc=%s output=%s\n' "$command" "$rc" "$output" >&2
    return 1
  }
  [[ "$output" != *"$forbidden"* ]] || {
    printf 'private value was echoed back\n' >&2
    return 1
  }
  [[ "$output" == *'BLOCKED'* ]]
}

assert_blocked_opaque() {
  local command=$1 output rc
  set +e
  output=$(run_hook "$command" 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]] || {
    printf 'expected opaque body source to block for %s, rc=%s output=%s\n' "$command" "$rc" "$output" >&2
    return 1
  }
  [[ "$output" == *'BLOCKED'* ]] || {
    printf 'expected opaque body source block message for %s, got: %s\n' "$command" "$output" >&2
    return 1
  }
}

assert_pass 'gh pr create --body "Use <project-path> and user@example.com"'
assert_pass 'gh issue edit 1 --body "Reviewed inline body"'
assert_pass 'gh release create v1 --notes "Reviewed inline notes"'
assert_pass 'gh api repos/acme/project/issues -F body="Reviewed inline body"'
assert_pass 'gh issue list'
assert_pass 'git status'

assert_blocked_redacted 'gh pr create --body "/Users/privateuser/project"' '/Users/privateuser'
assert_blocked_redacted 'gh issue comment 1 --body "contact person@corp.cl"' 'person@corp.cl'
assert_blocked_redacted 'gh api repos/acme/project/issues -f body=/home/privateuser/project' '/home/privateuser'

token="ghp_$(printf '%040d' 0)"
assert_blocked_redacted "gh pr create --body $token" "$token"

# File/stdin-backed publication is opaque to this command-only hook.  These
# commands must not be treated as reviewed merely because their source path is
# visible while the bytes that will be published are not.
assert_blocked_opaque 'gh pr create --body-file payload.md'
assert_blocked_opaque 'gh issue create --body-file=payload.md'
assert_blocked_opaque 'gh pr edit 1 --body-file payload.md'
assert_blocked_opaque 'gh issue edit 1 --body-file=payload.md'
assert_blocked_opaque 'gh release create v1 --notes-file notes.md'
assert_blocked_opaque 'gh gist create secret.txt'
assert_blocked_opaque 'gh api repos/acme/project/issues -F body=@payload.json'
assert_blocked_opaque "gh api repos/acme/project/issues -F 'body=@payload.json'"
assert_blocked_opaque 'gh pr create -F payload.md'
assert_blocked_opaque 'gh issue edit 1 -F payload.md'
assert_blocked_opaque 'gh release create v1 -F notes.md'
assert_blocked_opaque 'gh pr comment 1 --body-file payload.md'
assert_blocked_opaque "gh pr create '--body-file' payload.md"
assert_blocked_redacted 'gh --repo acme/project pr create --body "/Users/privateuser/project"' '/Users/privateuser'

set +e
input_output=$(run_hook 'gh api repos/acme/project/issues --input payload.json' 2>&1)
input_rc=$?
set -e
[[ $input_rc -eq 2 && "$input_output" == *'command-only review cannot verify'* ]]

printf 'privacy-review tests: PASS\n'
