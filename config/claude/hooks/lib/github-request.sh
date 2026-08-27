#!/usr/bin/env bash
# github-request.sh — bounded GitHub CLI calls for read-only hooks.
#
# The hook has a short outer timeout, but a stalled gh process must still be
# bounded here. Completion is signaled by a status file written only after gh
# returns; an empty ps/pgrep result is not proof that a child finished.

GH_REQUEST_TIMEOUT_SECONDS=2

_gh_process_tree_pids() {
  local frontier="$1" all_pids="$1" pid children next

  while [ -n "$frontier" ]; do
    next=""
    for pid in $frontier; do
      children=$(pgrep -P "$pid" 2>/dev/null || true)
      [ -n "$children" ] && {
        next="$next $children"
        all_pids="$all_pids $children"
      }
    done
    frontier=$next
  done

  printf '%s' "$all_pids"
}

gh_request() {
  local result_file status_file gh_pid elapsed_tenths request_rc tree_pids tp

  if command -v timeout >/dev/null 2>&1; then
    timeout "$GH_REQUEST_TIMEOUT_SECONDS" gh "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$GH_REQUEST_TIMEOUT_SECONDS" gh "$@"
    return $?
  fi

  result_file=$(mktemp "${TMPDIR:-/tmp}/project-integrations-check.XXXXXX") || return 125
  status_file=$(mktemp "${TMPDIR:-/tmp}/project-integrations-check-status.XXXXXX") || {
    rm -f "$result_file"
    return 125
  }
  (
    gh "$@"
    request_rc=$?
    printf '%s\n' "$request_rc" >"$status_file"
    exit "$request_rc"
  ) >"$result_file" 2>&1 &
  gh_pid=$!
  elapsed_tenths=0
  while [ ! -s "$status_file" ]; do
    if [ "$elapsed_tenths" -ge $((GH_REQUEST_TIMEOUT_SECONDS * 10)) ]; then
      tree_pids=$(_gh_process_tree_pids "$gh_pid")
      for tp in $tree_pids; do kill -TERM "$tp" >/dev/null 2>&1 || true; done
      sleep 0.2
      for tp in $tree_pids; do kill -KILL "$tp" >/dev/null 2>&1 || true; done
      wait "$gh_pid" >/dev/null 2>&1 || true
      rm -f "$result_file" "$status_file"
      return 124
    fi
    sleep 0.1
    elapsed_tenths=$((elapsed_tenths + 1))
  done

  wait "$gh_pid" >/dev/null 2>&1 || true
  request_rc=$(cat "$status_file" 2>/dev/null) || {
    rm -f "$result_file" "$status_file"
    return 125
  }
  cat "$result_file"
  rm -f "$result_file" "$status_file"
  return "$request_rc"
}
