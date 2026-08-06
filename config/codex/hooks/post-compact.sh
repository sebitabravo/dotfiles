#!/usr/bin/env bash
# PostCompact: restore durable operating constraints without requesting hidden
# reasoning or assuming that optional memory tools are installed.
set -u

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    '{systemMessage:"Context was compacted. Re-read the summary, inspect current files and git status, recover decisions and pending work, and verify state before continuing. Use Engram only if its MCP tools are actually available."}'
fi
