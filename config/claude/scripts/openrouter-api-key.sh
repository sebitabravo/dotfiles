#!/bin/sh
set -eu

key_file="${OPENROUTER_API_KEY_FILE:-$HOME/.config/claude/openrouter.key}"

if [ ! -r "$key_file" ]; then
  printf '%s\n' "OpenRouter key file not found: $key_file" >&2
  exit 1
fi

tr -d '\r\n' < "$key_file"
