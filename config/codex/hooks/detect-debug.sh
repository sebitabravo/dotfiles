#!/usr/bin/env bash
# PostToolUse: report likely debug leftovers in the current diff. This is a
# reminder only; it never tries to undo an already completed tool call.
set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

cat >/dev/null
DIFF="$(git diff --unified=0 2>/dev/null || true)"
[ -z "$DIFF" ] && exit 0

if printf '%s' "$DIFF" \
  | grep -Ei '^\+[^+]*(console[.]log|console[.]debug|debugger;|var_dump[[:space:]]*[(]|dd[[:space:]]*[(]|binding[.]pry|pdb[.]set_trace|breakpoint[[:space:]]*[(])' \
  | grep -Ev '^\+[[:space:]]*(#|//|/[*]|[*]|<!--|--)' \
  | grep -Eq '.*'; then
  jq -nc \
    '{systemMessage:"The current diff contains a likely debug statement. Inspect it before completion and remove it unless it is intentional and covered by project conventions."}'
fi
