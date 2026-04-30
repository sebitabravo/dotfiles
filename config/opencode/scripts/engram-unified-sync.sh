#!/bin/zsh
set -euo pipefail

ENGRAM_BIN="/opt/homebrew/bin/engram"
VAULT_PATH="/Users/sebastian/Documents/Obsidian Vault"
PROJECT_NAME="opencode"
LOG_DIR="/Users/sebastian/.config/opencode/logs"
WATCH_INTERVAL="1m"

mkdir -p "$LOG_DIR"

SERVE_STARTED_BY_SCRIPT=0
SERVE_PID=""

if ! pgrep -f "engram serve" >/dev/null 2>&1; then
  "$ENGRAM_BIN" serve >>"$LOG_DIR/engram-serve.out.log" 2>>"$LOG_DIR/engram-serve.err.log" &
  SERVE_PID=$!
  SERVE_STARTED_BY_SCRIPT=1
fi

cleanup() {
  if [ "$SERVE_STARTED_BY_SCRIPT" -eq 1 ] && [ -n "$SERVE_PID" ] && kill -0 "$SERVE_PID" >/dev/null 2>&1; then
    kill "$SERVE_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

"$ENGRAM_BIN" obsidian-export --vault "$VAULT_PATH" --project "$PROJECT_NAME" --watch --interval "$WATCH_INTERVAL" >>"$LOG_DIR/engram-obsidian-sync.out.log" 2>>"$LOG_DIR/engram-obsidian-sync.err.log"
