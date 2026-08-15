#!/bin/sh
set -eu

key_file="${OLLAMA_API_KEY_FILE:-$HOME/.config/claude/ollama.key}"

if [ ! -r "$key_file" ]; then
  printf '%s\n' "Ollama key file not found: $key_file" >&2
  exit 1
fi

tr -d '\r\n' < "$key_file"
