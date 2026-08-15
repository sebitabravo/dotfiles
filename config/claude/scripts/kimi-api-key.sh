#!/bin/sh
set -eu

key_file="${KIMI_API_KEY_FILE:-$HOME/.config/claude/kimi.key}"

if [ ! -r "$key_file" ]; then
  printf '%s\n' "Kimi key file not found: $key_file" >&2
  exit 1
fi

tr -d '\r\n' < "$key_file"
