#!/usr/bin/env bash
# Shared state helpers for the automatic oneshot workflow.
#
# Runtime state lives under ~/.claude, not inside the project, so activating a
# task never creates files that the user could accidentally commit. A session
# may still use its explicit project-local receipt fallback when permissions
# forbid the agent from writing the administrative receipt outside the project.
# Tests can set CLAUDE_AUTOMATION_STATE_DIR to an isolated temporary directory.

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

automation_project_receipt_path() {
  local root="$1" session_id="$2" key
  key=$(automation_session_key "$session_id") || return 1
  printf '%s/RECEIPT_CONVERGENCE.%s.txt' "$root" "$key"
}

automation_generate_activation_id() {
  local generated
  if command -v openssl >/dev/null 2>&1; then
    generated=$(openssl rand -hex 16 2>/dev/null || true)
    [ -n "$generated" ] && {
      printf '%s' "$generated"
      return 0
    }
  fi

  printf '%s:%s:%s:%s' "$(date +%s%N 2>/dev/null || date +%s)" "$$" "${RANDOM:-0}" "${TMPDIR:-/tmp}" |
    shasum -a 256 | awk '{print $1}'
}

automation_state_is_valid() {
  local root="$1" session_id="$2" state_path
  state_path=$(automation_state_path "$root" "$session_id") || return 1
  [ -s "$state_path" ] || return 1
  jq -e \
    --arg root "$root" \
    --arg session_id "$session_id" \
    '.version == 1 and .root == $root and .session_id == $session_id and
     (.mode == "oneshot" or .mode == "follow_up" or .mode == "docs_only") and
     (.activation_id | type == "string" and length >= 16)' \
    "$state_path" >/dev/null 2>&1
}

automation_activation_id() {
  local root="$1" session_id="$2" state_path
  state_path=$(automation_state_path "$root" "$session_id") || return 1
  jq -r '.activation_id // empty' "$state_path" 2>/dev/null
}

automation_state_mode() {
  local root="$1" session_id="$2" state_path
  state_path=$(automation_state_path "$root" "$session_id") || return 1
  jq -r '.mode // empty' "$state_path" 2>/dev/null
}

automation_update_mode() {
  local root="$1" session_id="$2" mode="$3" state_root state_path tmp
  case "$mode" in
    oneshot | follow_up | docs_only) ;;
    *) return 1 ;;
  esac

  state_root=$(automation_state_root "$root") || return 1
  state_path=$(automation_state_path "$root" "$session_id") || return 1
  automation_state_is_valid "$root" "$session_id" || return 1

  umask 077
  tmp=$(mktemp "$state_root/.state.XXXXXX") || return 1
  if ! jq --arg mode "$mode" '.mode = $mode' "$state_path" >"$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  mv -f -- "$tmp" "$state_path"
}

automation_clear_receipts() {
  local root="$1" session_id="$2" receipt project_receipt
  receipt=$(automation_receipt_path "$root" "$session_id") || return 1
  project_receipt=$(automation_project_receipt_path "$root" "$session_id") || return 1
  rm -f -- "$receipt" "$project_receipt"
}

automation_is_active() {
  automation_state_is_valid "$1" "$2"
}

automation_activate() {
  local root="$1" session_id="$2" mode="$3" state_root state_path tmp activation_id
  state_root=$(automation_state_root "$root")
  state_path=$(automation_state_path "$root" "$session_id") || return 1

  mkdir -p "$state_root" || return 1
  if automation_state_is_valid "$root" "$session_id"; then
    # A documentation-only activation may receive a later code mutation. Keep
    # its activation binding, but make the next Stop gate executable.
    if [ "$(automation_state_mode "$root" "$session_id")" = docs_only ] && [ "$mode" = follow_up ]; then
      automation_update_mode "$root" "$session_id" follow_up || return 1
    fi
    return 0
  fi

  # A missing or malformed state starts a new activation. Old receipts are
  # evidence from a different activation and must never be reused silently.
  automation_clear_receipts "$root" "$session_id" || return 1
  rm -f -- "$state_path"
  activation_id=$(automation_generate_activation_id) || return 1

  umask 077
  tmp=$(mktemp "$state_root/.state.XXXXXX") || return 1
  if ! jq -n \
    --arg root "$root" \
    --arg session_id "$session_id" \
    --arg mode "$mode" \
    --arg activation_id "$activation_id" \
    --arg activated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{version: 1, root: $root, session_id: $session_id, mode: $mode, activation_id: $activation_id, activated_at: $activated_at}' \
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
