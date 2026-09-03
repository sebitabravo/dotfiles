#!/bin/sh
set -eu

key_file="${GLM_API_KEY_FILE:-$HOME/.config/claude/glm.key}"

if [ ! -r "$key_file" ]; then
  printf '%s\n' "GLM key file not found: $key_file" >&2
  exit 1
fi

tr -d '\r\n' <"$key_file"
