#!/usr/bin/env bash
# PreCompact: leave a small, current orientation hint for the compaction pass.
set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

STATUS="$(git status --short 2>/dev/null | head -40 || true)"
if [ -z "$STATUS" ]; then
  STATUS="working tree clean"
fi

CONTEXT="Before compaction, preserve the active goal, decisions, failed attempts, pending work, and verification evidence. Current git status:\n${STATUS}"
jq -nc --arg message "$CONTEXT" '{systemMessage:$message}'
