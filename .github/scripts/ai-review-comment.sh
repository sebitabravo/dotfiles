#!/usr/bin/env bash
# Builds and publishes the GGA review comment (CodeRabbit style: update in place).
# Usage: ai-review-comment.sh <review-output.txt> [--publish]
#   --publish  : post or PATCH the comment via gh (needs GH_TOKEN + PR_NUMBER)
#   without it : only generates ./comment.md (used by tests)
set -euo pipefail

INPUT="${1:?usage: ai-review-comment.sh <review-output.txt> [--publish]}"
PUBLISH=0
[[ "${2:-}" == "--publish" ]] && PUBLISH=1

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
CLEAN="$OUT_DIR/clean.md"
CONCISE="$OUT_DIR/concise.md"
BODY="$OUT_DIR/body.md"
COMMENT="$OUT_DIR/comment.md"

# 1. Strip ANSI (GGA v2.10.1 hardcodes colors; no NO_COLOR detection).
perl -pe 's/\e\[[0-9;]*m//g' "$INPUT" > "$CLEAN"

# 2. Collapse the "Files to review" list to one line. Count via awk to avoid
#    the "0\n0" bug of `grep -c ... || echo 0` (grep exits 1 when count is 0).
file_count=$(awk '/^  - /{n++} END{print n+0}' "$CLEAN")
if grep -q "^Files to review:" "$CLEAN"; then
  awk -v cnt="$file_count" '
    /^Files to review:/ {print "Files to review: " cnt " files - see Files changed tab"; skip=1; next}
    skip && (/^  - / || /^[[:space:]]*$/) {next}
    skip {skip=0}
    !skip {print}
  ' "$CLEAN" > "$CONCISE"
else
  cp "$CLEAN" "$CONCISE"
fi

# 3. Remove engine noise (banner, info logs, CLI build line, trailers):
#    only the model review remains.
awk '
  /^[━]+$/ {next}
  /^[[:space:]]*Gentleman Guardian Angel/ {next}
  /^[[:space:]]*Provider-agnostic code review using AI/ {next}
  /^ℹ️/ {next}
  /^> (build|review) · / {next}
  /^[❌✅ ]*CODE REVIEW (PASSED|FAILED)$/ {next}
  /^Fix the violations listed above before committing\.$/ {next}
  /^Could not determine review status$/ {next}
  {print}
' "$CONCISE" > "$BODY"

# 4. Cap at 300 lines, then prepend the header.
head -n 300 "$BODY" > "$COMMENT"
{
  echo "## 🤖 Review (GGA)"
  echo ""
  cat "$COMMENT"
} > "$COMMENT.tmp" && mv "$COMMENT.tmp" "$COMMENT"

# Copy to the current directory so callers (and tests) can inspect it.
cp "$COMMENT" ./comment.md

if [[ "$PUBLISH" != "1" ]]; then
  echo "comment generated (publish skipped): $(pwd)/comment.md"
  exit 0
fi

# 5. Publish: update the previous bot comment in place (CodeRabbit style),
#    otherwise create a new one.
PR="${PR_NUMBER:?PR_NUMBER required for --publish}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required for --publish}"
comment_id=$(gh api "repos/${repo}/issues/${PR}/comments" \
  --jq '[.[] | select(.user.login=="github-actions[bot]") | select(.body | startswith("## 🤖"))] | last | .id' 2>/dev/null || true)
if [[ -n "$comment_id" ]]; then
  gh api -X PATCH "repos/${repo}/issues/${PR}/comments/${comment_id}" \
    -F body=@comment.md >/dev/null 2>&1 \
    || gh pr comment "$PR" --body-file comment.md
else
  gh pr comment "$PR" --body-file comment.md
fi
echo "comment published: ${repo} #${PR}"
