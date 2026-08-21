#!/usr/bin/env bash
# Shared state helpers for the automatic oneshot workflow.
#
# State lives under ~/.claude, not inside the project, so activating a task
# never creates files that the user could accidentally commit. Tests can set
# CLAUDE_AUTOMATION_STATE_DIR to an isolated temporary directory.

automation_project_key() {
  local root="$1"
  printf '%s' "$root" | shasum -a 256 | awk '{print $1}'
}

automation_state_root() {
  local root="$1"
  if [ -n "${CLAUDE_AUTOMATION_STATE_DIR:-}" ]; then
    printf '%s' "$CLAUDE_AUTOMATION_STATE_DIR"
  else
    printf '%s/automation-state/%s' "$HOME/.claude" "$(automation_project_key "$root")"
  fi
}

automation_session_key() {
  local session_id="${1:-}"
  if [ -z "$session_id" ]; then
    return 1
  fi

  session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_.-')
  [ -n "$session_id" ] || return 1
  printf '%.120s' "$session_id"
}

automation_state_path() {
  local root="$1" session_id="$2" key
  key=$(automation_session_key "$session_id") || return 1
  printf '%s/%s.json' "$(automation_state_root "$root")" "$key"
}

automation_receipt_path() {
  local root="$1" session_id="$2" key
  key=$(automation_session_key "$session_id") || return 1
  printf '%s/%s.receipt' "$(automation_state_root "$root")" "$key"
}

automation_is_active() {
  local root="$1" session_id="$2" path
  path=$(automation_state_path "$root" "$session_id") || return 1
  [ -s "$path" ]
}

automation_activate() {
  local root="$1" session_id="$2" mode="$3" state_root state_path receipt tmp
  state_root=$(automation_state_root "$root")
  state_path=$(automation_state_path "$root" "$session_id") || return 1
  receipt=$(automation_receipt_path "$root" "$session_id") || return 1

  mkdir -p "$state_root" || return 1
  if [ -s "$state_path" ]; then
    return 0
  fi

  umask 077
  tmp=$(mktemp "$state_root/.state.XXXXXX") || return 1
  if ! jq -n \
    --arg root "$root" \
    --arg session_id "$session_id" \
    --arg mode "$mode" \
    --arg receipt "$receipt" \
    --arg activated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{version: 1, root: $root, session_id: $session_id, mode: $mode, receipt: $receipt, activated_at: $activated_at}' \
    >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$state_path"
}

automation_deactivate() {
  local root="$1" session_id="$2" state_path
  state_path=$(automation_state_path "$root" "$session_id") || return 0
  rm -f "$state_path"
}
