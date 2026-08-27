#!/usr/bin/env bash
# Builds and publishes the GGA review comment (CodeRabbit style: update in place).
# Usage: ai-review-comment.sh <review-output.txt> [--publish] [--inline-plan]
#   --publish     : post or PATCH the comment via gh (needs GH_TOKEN + PR_NUMBER)
#   --inline-plan : print the per-finding path|line|sev|row plan (used by tests)
#   without flags : only generates ./comment.md (used by tests)
set -euo pipefail

INPUT="${1:?usage: ai-review-comment.sh <review-output.txt> [--publish] [--inline-plan]}"
PUBLISH=0
PLAN=0
for arg in "${@:2}"; do
  [[ "$arg" == "--publish" ]] && PUBLISH=1
  [[ "$arg" == "--inline-plan" ]] && PLAN=1
done

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT
CLEAN="$OUT_DIR/clean.md"
CONCISE="$OUT_DIR/concise.md"
BODY="$OUT_DIR/body.md"
COMMENT="$OUT_DIR/comment.md"

# 1. Strip ANSI (GGA v2.10.1 hardcodes colors; no NO_COLOR detection).
perl -pe 's/\e\[[0-9;]*m//g' "$INPUT" >"$CLEAN"

# 2. Collapse the "Files to review" list to one line. Count via awk to avoid
#    the "0\n0" bug of `grep -c ... || echo 0` (grep exits 1 when count is 0).
file_count=$(awk '/^  - /{n++} END{print n+0}' "$CLEAN")
if grep -q "^Files to review:" "$CLEAN"; then
  awk -v cnt="$file_count" '
    /^Files to review:/ {print "Files to review: " cnt " files - see Files changed tab"; skip=1; next}
    skip && (/^  - / || /^[[:space:]]*$/) {next}
    skip {skip=0}
    !skip {print}
  ' "$CLEAN" >"$CONCISE"
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
' "$CONCISE" >"$BODY"

# 4. Cap at 300 lines, then prepend the header.
head -n 300 "$BODY" >"$COMMENT"
{
  echo "## 🤖 Review (GGA)"
  echo ""
  cat "$COMMENT"
} >"$COMMENT.tmp" && mv "$COMMENT.tmp" "$COMMENT"

# Copy to the current directory so callers (and tests) can inspect it.
cp "$COMMENT" ./comment.md

# If GGA found no reviewable files (e.g. the push only touched excluded
# paths), do not pollute the PR thread with an empty comment.
if grep -q "No matching files changed in last commit" "$COMMENT"; then
  echo "no reviewable files changed, skipping comment"
  exit 0
fi

# 5. Inline plan (Claude Code/Codex/CodeRabbit style): extract path:line from
#    the severity table so CI can post line-level comments. The full table row
#    is kept as the inline body (no fragile field re-parsing).
INLINE_PLAN="$OUT_DIR/inline-plan.txt"
awk '
  /^\| (🔴|🟡|🟣) \|/ {
    loc=$4
    gsub(/`/, "", loc)
    split(loc, a, ":")
    line=a[2]
    sub(/,.*/, "", line)
    if (a[1] != "" && line ~ /^[0-9]+$/)
      print a[1] "|" line "|" $2 "|" $0
  }
' "$COMMENT" >"$INLINE_PLAN"

if [[ "$PLAN" == "1" ]]; then
  cat "$INLINE_PLAN"
  exit 0
fi

if [[ "$PUBLISH" != "1" ]]; then
  echo "comment generated (publish skipped): $(pwd)/comment.md"
  exit 0
fi

# 6. Publish: keep a single bot summary comment. Deleting previous bot review
#    comments and posting one new comment is more robust than PATCH (which the
#    issue comments API kept rejecting) and consolidates the thread.
PR="${PR_NUMBER:?PR_NUMBER required for --publish}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required for --publish}"
gh api "repos/${repo}/issues/${PR}/comments" --paginate \
  --jq '.[] | select(.user.login=="github-actions[bot]") | select(.body | startswith("## 🤖")) | .id' \
  2>/dev/null |
  while read -r old_id; do
    # Issue comments are addressed by /issues/comments/{id} (not nested under
    # the issue number). Log failures so a bot thread never silently accumulates.
    gh api -X DELETE "repos/${repo}/issues/comments/${old_id}" || echo "failed to delete old review comment ${old_id}" >&2
  done
gh pr comment "$PR" --body-file comment.md
echo "comment published: ${repo} #${PR}"

# 7. Publish inline comments on the reported lines (one per finding), after
#    removing previous bot inlines so a push never accumulates duplicates.
#    Lines not present in the PR diff are skipped (the summary table keeps them).
head_sha=$(gh api "repos/${repo}/pulls/${PR}" --jq '.head.sha' 2>/dev/null || true)
if [[ -n "$head_sha" && -s "$INLINE_PLAN" ]]; then
  gh api "repos/${repo}/pulls/${PR}/comments" --paginate \
    --jq '.[] | select(.user.login=="github-actions[bot]") | select(.body | startswith("🔴") or startswith("🟡") or startswith("🟣")) | .id' \
    2>/dev/null |
    while read -r inline_id; do
      gh api -X DELETE "repos/${repo}/pulls/comments/${inline_id}" >/dev/null 2>&1 || true
    done
  while IFS='|' read -r fpath fline sev row; do
    label="Nit"
    [[ "$sev" == "🔴" ]] && label="Important"
    [[ "$sev" == "🟣" ]] && label="Pre-existing"
    body="$(printf '%s **%s** - `%s:%s`\n%s' "$sev" "$label" "$fpath" "$fline" "$row")"
    gh api -X POST "repos/${repo}/pulls/${PR}/comments" \
      -f path="$fpath" -f line="$fline" -f commit_id="$head_sha" -f body="$body" \
      >/dev/null 2>&1 || echo "inline skipped (not in diff?): ${fpath}:${fline}" >&2
  done <"$INLINE_PLAN"
  echo "inline comments published: $(wc -l <"$INLINE_PLAN" | tr -d ' ')"
fi
