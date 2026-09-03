#!/usr/bin/env bash
# UserPromptSubmit dispatcher. Claude runs matching hooks in parallel; JSON
# array order is not a dependency graph. Secret detection therefore runs first
# here, and no prompt consumer is called when it blocks.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
HOOK_DIR="${CLAUDE_PROMPT_DISPATCHER_HOOK_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"
SECRET_HOOK="$HOOK_DIR/secret-detect.sh"
[ -r "$SECRET_HOOK" ] || {
  printf '[user-prompt-dispatcher] BLOCKED: missing secret detector: %s\n' "$SECRET_HOOK" >&2
  exit 2
}

# This is the security barrier. Its stderr is intentionally preserved so the
# user receives the actionable detector message, but no side-effecting hook is
# reached on a non-zero result.
printf '%s' "$INPUT" | "$SECRET_HOOK"
SECRET_RC=$?
[ "$SECRET_RC" -eq 0 ] || exit "$SECRET_RC"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/user-prompt-dispatcher.XXXXXX") || exit 2
trap 'rm -rf -- "$TMP_DIR"' EXIT HUP INT TERM
CONTEXTS=()

collect_hook_output() {
  local label="$1" hook="$2" hook_arg="${3:-}" rc context
  local output_file="$TMP_DIR/$label.out" error_file="$TMP_DIR/$label.err"

  if [ -n "$hook_arg" ]; then
    printf '%s' "$INPUT" | "$hook" "$hook_arg" >"$output_file" 2>"$error_file"
  else
    printf '%s' "$INPUT" | "$hook" >"$output_file" 2>"$error_file"
  fi
  rc=$?
  cat "$error_file" >&2
  [ "$rc" -eq 0 ] || return "$rc"

  if [ ! -s "$output_file" ]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1 &&
    jq -e 'type == "object" and (.hookSpecificOutput | type == "object")' "$output_file" >/dev/null 2>&1; then
    context=$(jq -r '.hookSpecificOutput.additionalContext // empty' "$output_file" 2>/dev/null || true)
    [ -n "$context" ] && CONTEXTS+=("$context")
  else
    # Preserve unexpected output as an observable diagnostic instead of
    # fabricating a JSON hook response or silently discarding it.
    cat "$output_file" >&2
  fi
}

run_optional_command() {
  local label="$1" command_name="$2" rc context
  local output_file="$TMP_DIR/$label.out" error_file="$TMP_DIR/$label.err"
  command -v "$command_name" >/dev/null 2>&1 || return 0
  if printf '%s' "$INPUT" | "$command_name" prompt-hook >"$output_file" 2>"$error_file"; then
    rc=0
  else
    rc=$?
  fi
  cat "$error_file" >&2
  if [ "$rc" -ne 0 ]; then
    # CodeGraph enriches context but is not a safety barrier. A stale index,
    # unavailable daemon, or provider-side hiccup must not turn an optional
    # UserPromptSubmit integration into a hard prompt block; the mandatory
    # secret barrier and project preflight still run independently.
    printf '[user-prompt-dispatcher] optional %s failed (rc=%s); continuing without its context.\n' \
      "$label" "$rc" >&2
    return 0
  fi
  if [ -s "$output_file" ] && command -v jq >/dev/null 2>&1 &&
    jq -e 'type == "object" and (.hookSpecificOutput | type == "object")' "$output_file" >/dev/null 2>&1; then
    context=$(jq -r '.hookSpecificOutput.additionalContext // empty' "$output_file" 2>/dev/null || true)
    [ -n "$context" ] && CONTEXTS+=("$context")
  elif [ -s "$output_file" ]; then
    cat "$output_file" >&2
  fi
  return 0
}

collect_hook_output automatic-workflow.sh "$HOOK_DIR/automatic-workflow.sh" || exit $?
collect_hook_output activate-convergence-on-apply.sh "$HOOK_DIR/activate-convergence-on-apply.sh" || exit $?
run_optional_command codegraph codegraph || exit $?
collect_hook_output project-integrations-check.sh "$HOOK_DIR/project-integrations-check.sh" || exit $?

if [ -r "$HOOK_DIR/herdr-agent-state.sh" ]; then
  collect_hook_output herdr-agent-state.sh "$HOOK_DIR/herdr-agent-state.sh" session || exit $?
fi

if [ "${#CONTEXTS[@]}" -gt 0 ] && command -v jq >/dev/null 2>&1; then
  jq -nc --arg context "$(printf '%s\n\n' "${CONTEXTS[@]}")" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$context}}'
fi
exit 0
