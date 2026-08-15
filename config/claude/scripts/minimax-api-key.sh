#!/bin/sh
set -eu

key_file="${MINIMAX_API_KEY_FILE:-$HOME/.config/claude/minimax.key}"

if [ ! -r "$key_file" ]; then
  printf '%s\n' "MiniMax key file not found: $key_file" >&2
  exit 1
fi

tr -d '\r\n' < "$key_file"
