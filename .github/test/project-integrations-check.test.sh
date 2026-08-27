#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/project-integrations-check.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/project-integrations-check-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  git -C "$dir" config core.hooksPath /dev/null
  printf '%s\n' '.codegraph/' >"$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m init
  git -C "$dir" remote add origin https://github.com/testuser/testrepo.git
}

run_hook() {
  local cwd="$1" event="${2:-SessionStart}" session_id="${3:-test-session}"
  jq -nc --arg cwd "$cwd" --arg event "$event" --arg session_id "$session_id" \
    '{hook_event_name:$event,cwd:$cwd,session_id:$session_id}' | "$HOOK"
}

MOCK_INDEX="$TMP/mock-index"
mkdir -p "$MOCK_INDEX"
MOCK_CODEGRAPH="$TMP/codegraph"
cat >"$MOCK_CODEGRAPH" <<EOF
#!/usr/bin/env bash
echo '{"initialized":true,"indexPath":"$MOCK_INDEX"}'
EOF
chmod +x "$MOCK_CODEGRAPH"
MOCK_CLAUDE_CONFIG="$TMP/claude.json"
printf '%s' '{"mcpServers":{"codegraph":{"command":"codegraph"}}}' >"$MOCK_CLAUDE_CONFIG"

# Every ordinary fixture represents a repo owned by the test user. This keeps
# the existing parser/maintainability cases meaningful after the real owner
# gate is enabled; the explicit no-remote/non-GitHub/non-admin cases below
# replace or remove this origin and use their own fake gh.
DEFAULT_GH_BIN="$TMP/default-owner-gh"
DEFAULT_GH_MARKER="$TMP/default-owner-gh-calls"
mkdir -p "$DEFAULT_GH_BIN"
cat >"$DEFAULT_GH_BIN/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$DEFAULT_GH_MARKER"
if [ "\$1" = "auth" ] && [ "\$2" = "status" ]; then
  exit 0
fi
if [ "\$1" = "api" ]; then
  case "\$2" in
    repos/*/branches/*/protection)
      printf '%s' '{"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"required_status_checks":{"contexts":["ci"],"checks":[]}}'
      ;;
    repos/*)
      printf '%s' '{"permissions":{"admin":true},"default_branch":"main","delete_branch_on_merge":true}'
      ;;
  esac
fi
EOF
chmod +x "$DEFAULT_GH_BIN/gh"
PATH="$DEFAULT_GH_BIN:$PATH"

run_hook_healthy_deps() {
  CODEGRAPH_BIN="$MOCK_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" run_hook "$1" "${2:-SessionStart}"
}

printf '%s\n' '== gh request timeout does not depend on ps/pgrep completion inspection'
TIMEOUT_REPO="$TMP/timeout-gh-repo"
new_repo "$TIMEOUT_REPO"
TIMEOUT_GH_BIN="$TMP/timeout-gh-bin"
TIMEOUT_INSPECTOR_BIN="$TMP/timeout-inspectors"
mkdir -p "$TIMEOUT_GH_BIN" "$TIMEOUT_INSPECTOR_BIN"
cat >"$TIMEOUT_GH_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = auth ] && [ "$2" = status ]; then
  exec sleep 30
  exit 0
fi
exit 1
EOF
cat >"$TIMEOUT_INSPECTOR_BIN/ps" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"$TIMEOUT_INSPECTOR_BIN/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$TIMEOUT_GH_BIN/gh" "$TIMEOUT_INSPECTOR_BIN/ps" "$TIMEOUT_INSPECTOR_BIN/pgrep"
timeout_start=$(date +%s)
timeout_output=$(PATH="$TIMEOUT_GH_BIN:$TIMEOUT_INSPECTOR_BIN:$PATH" \
  CODEGRAPH_BIN="$MOCK_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  run_hook "$TIMEOUT_REPO" SessionStart timeout-session 2>&1)
timeout_rc=$?
timeout_end=$(date +%s)
timeout_elapsed=$((timeout_end - timeout_start))
[ "$timeout_rc" -eq 0 ]
[ "$timeout_elapsed" -lt 10 ]
printf '%s\n' "$timeout_output" | grep -Fq 'NOT_APPLICABLE'

# A PATH with jq but WITHOUT pandoc, so claude_md_import_candidates falls
# back to the awk heuristic even on a host (like this dev machine) that has
# pandoc installed — the fallback path needs its own coverage, not just the
# pandoc-primary path every other test below exercises by default.
REAL_JQ=$(command -v jq)
FALLBACK_BIN="$TMP/fallback-bin"
mkdir -p "$FALLBACK_BIN"
ln -s "$REAL_JQ" "$FALLBACK_BIN/jq"
FALLBACK_PATH="$DEFAULT_GH_BIN:$FALLBACK_BIN:/usr/bin:/bin"
if command -v pandoc >/dev/null 2>&1; then
  PATH="$FALLBACK_PATH" command -v pandoc >/dev/null 2>&1 && {
    echo 'FAIL: fallback PATH still resolves pandoc, cannot test the awk fallback in isolation' >&2
    exit 1
  }
fi
run_hook_fallback_parser() {
  PATH="$FALLBACK_PATH" run_hook "$1" "${2:-SessionStart}"
}

# A PATH where `pandoc` resolves but is BROKEN (present, on PATH, yet fails
# or emits garbage) — proves claude_md_import_candidates checks pandoc's
# actual exit status and output validity, not just `command -v pandoc`,
# before trusting its result. Real jq stays available (both for the harness
# building its JSON input and for the hook's own fallback path).
BROKEN_PANDOC_EXIT_BIN="$TMP/broken-pandoc-exit-bin"
mkdir -p "$BROKEN_PANDOC_EXIT_BIN"
cat >"$BROKEN_PANDOC_EXIT_BIN/pandoc" <<'EOF'
#!/usr/bin/env bash
echo 'pandoc: fatal error' >&2
exit 1
EOF
chmod +x "$BROKEN_PANDOC_EXIT_BIN/pandoc"
BROKEN_PANDOC_EXIT_PATH="$BROKEN_PANDOC_EXIT_BIN:$DEFAULT_GH_BIN:$FALLBACK_BIN:/usr/bin:/bin"
run_hook_broken_pandoc_exit() {
  PATH="$BROKEN_PANDOC_EXIT_PATH" run_hook "$1" "${2:-SessionStart}"
}

BROKEN_PANDOC_JSON_BIN="$TMP/broken-pandoc-json-bin"
mkdir -p "$BROKEN_PANDOC_JSON_BIN"
cat >"$BROKEN_PANDOC_JSON_BIN/pandoc" <<'EOF'
#!/usr/bin/env bash
printf '%s' 'not valid json at all'
exit 0
EOF
chmod +x "$BROKEN_PANDOC_JSON_BIN/pandoc"
BROKEN_PANDOC_JSON_PATH="$BROKEN_PANDOC_JSON_BIN:$DEFAULT_GH_BIN:$FALLBACK_BIN:/usr/bin:/bin"
run_hook_broken_pandoc_json() {
  PATH="$BROKEN_PANDOC_JSON_PATH" run_hook "$1" "${2:-SessionStart}"
}

BROKEN_PANDOC_SHAPE_BIN="$TMP/broken-pandoc-shape-bin"
mkdir -p "$BROKEN_PANDOC_SHAPE_BIN"
cat >"$BROKEN_PANDOC_SHAPE_BIN/pandoc" <<'EOF'
#!/usr/bin/env bash
printf '%s' '{}'
exit 0
EOF
chmod +x "$BROKEN_PANDOC_SHAPE_BIN/pandoc"
BROKEN_PANDOC_SHAPE_PATH="$BROKEN_PANDOC_SHAPE_BIN:$DEFAULT_GH_BIN:$FALLBACK_BIN:/usr/bin:/bin"
run_hook_broken_pandoc_shape() {
  PATH="$BROKEN_PANDOC_SHAPE_PATH" run_hook "$1" "${2:-SessionStart}"
}

printf '%s\n' '== healthy scope (AGENTS.md + CLAUDE.md symlink, no candidates) is silent on SessionStart'
HEALTHY="$TMP/healthy"
new_repo "$HEALTHY"
printf '# Agents\n' >"$HEALTHY/AGENTS.md"
ln -s AGENTS.md "$HEALTHY/CLAUDE.md"
git -C "$HEALTHY" add AGENTS.md CLAUDE.md
git -C "$HEALTHY" commit -q -m agents
healthy_out=$(run_hook_healthy_deps "$HEALTHY" SessionStart)
[ -z "$healthy_out" ]

printf '%s\n' '== root MISSING (no AGENTS.md, no CLAUDE.md, no README.md)'
MISSING="$TMP/missing"
new_repo "$MISSING"
out=$(run_hook "$MISSING")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): MISSING'

printf '%s\n' '== root LEGACY_README_ONLY (README.md but no AGENTS.md/CLAUDE.md)'
LEGACY="$TMP/legacy"
new_repo "$LEGACY"
printf '# Legacy project\n' >"$LEGACY/README.md"
git -C "$LEGACY" add README.md
git -C "$LEGACY" commit -q -m readme
out=$(run_hook "$LEGACY")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): LEGACY_README_ONLY'

printf '%s\n' '== root AGENTS_ONLY (AGENTS.md exists, no CLAUDE.md bridge at all)'
AGENTS_ONLY="$TMP/agents-only"
new_repo "$AGENTS_ONLY"
printf '# Agents\n' >"$AGENTS_ONLY/AGENTS.md"
git -C "$AGENTS_ONLY" add AGENTS.md
git -C "$AGENTS_ONLY" commit -q -m agents-only
out=$(run_hook "$AGENTS_ONLY")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): AGENTS_ONLY'

printf '%s\n' '== root CLAUDE_ONLY (plain CLAUDE.md, no AGENTS.md, not a symlink)'
CLAUDE_ONLY="$TMP/claude-only"
new_repo "$CLAUDE_ONLY"
printf '# Claude notes\n' >"$CLAUDE_ONLY/CLAUDE.md"
git -C "$CLAUDE_ONLY" add CLAUDE.md
git -C "$CLAUDE_ONLY" commit -q -m claude-only
out=$(run_hook "$CLAUDE_ONLY")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): CLAUDE_ONLY'

printf '%s\n' '== root DIVERGED (AGENTS.md and a plain unrelated CLAUDE.md, no import)'
DIVERGED="$TMP/diverged"
new_repo "$DIVERGED"
printf '# Agents\n' >"$DIVERGED/AGENTS.md"
printf '# Claude-only notes, unrelated to AGENTS.md\n' >"$DIVERGED/CLAUDE.md"
git -C "$DIVERGED" add AGENTS.md CLAUDE.md
git -C "$DIVERGED" commit -q -m diverged
out=$(run_hook "$DIVERGED")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root READY via @AGENTS.md import NOT on the first line'
IMPORT_HEADER="$TMP/import-header"
new_repo "$IMPORT_HEADER"
printf '# Agents\n' >"$IMPORT_HEADER/AGENTS.md"
printf '# Claude-specific notes\n\n@AGENTS.md\n\n## Claude Code\nUse plan mode.\n' >"$IMPORT_HEADER/CLAUDE.md"
git -C "$IMPORT_HEADER" add AGENTS.md CLAUDE.md
git -C "$IMPORT_HEADER" commit -q -m import-header
out=$(run_hook_healthy_deps "$IMPORT_HEADER" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root DIVERGED: @AGENTS.md inside an inline code span is prose, not an import'
INLINE_SPAN="$TMP/inline-span"
new_repo "$INLINE_SPAN"
printf '# Agents\n' >"$INLINE_SPAN/AGENTS.md"
printf 'Use `@AGENTS.md` literally to bridge.\n' >"$INLINE_SPAN/CLAUDE.md"
git -C "$INLINE_SPAN" add AGENTS.md CLAUDE.md
git -C "$INLINE_SPAN" commit -q -m inline-span
out=$(run_hook "$INLINE_SPAN")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root READY via @./AGENTS.md relative import (not the literal string "AGENTS.md")'
RELATIVE_IMPORT="$TMP/relative-import"
new_repo "$RELATIVE_IMPORT"
printf '# Agents\n' >"$RELATIVE_IMPORT/AGENTS.md"
printf '@./AGENTS.md\n' >"$RELATIVE_IMPORT/CLAUDE.md"
git -C "$RELATIVE_IMPORT" add AGENTS.md CLAUDE.md
git -C "$RELATIVE_IMPORT" commit -q -m relative-import
out=$(run_hook_healthy_deps "$RELATIVE_IMPORT" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root DIVERGED: @AGENTS.md inside a DOUBLE-backtick inline span is still prose'
DOUBLE_SPAN="$TMP/double-span"
new_repo "$DOUBLE_SPAN"
printf '# Agents\n' >"$DOUBLE_SPAN/AGENTS.md"
printf 'Use ``@AGENTS.md`` literally.\n' >"$DOUBLE_SPAN/CLAUDE.md"
git -C "$DOUBLE_SPAN" add AGENTS.md CLAUDE.md
git -C "$DOUBLE_SPAN" commit -q -m double-span
out=$(run_hook "$DOUBLE_SPAN")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root DIVERGED: @AGENTS.md inside a tilde-fenced (~~~) code block is still prose'
TILDE_FENCE="$TMP/tilde-fence"
new_repo "$TILDE_FENCE"
printf '# Agents\n' >"$TILDE_FENCE/AGENTS.md"
printf '~~~\n@AGENTS.md\n~~~\n' >"$TILDE_FENCE/CLAUDE.md"
git -C "$TILDE_FENCE" add AGENTS.md CLAUDE.md
git -C "$TILDE_FENCE" commit -q -m tilde-fence
out=$(run_hook "$TILDE_FENCE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root READY via an absolute-path import (not resolved relative to CWD)'
ABSOLUTE_IMPORT="$TMP/absolute-import"
new_repo "$ABSOLUTE_IMPORT"
printf '# Agents\n' >"$ABSOLUTE_IMPORT/AGENTS.md"
printf '@%s/AGENTS.md\n' "$ABSOLUTE_IMPORT" >"$ABSOLUTE_IMPORT/CLAUDE.md"
git -C "$ABSOLUTE_IMPORT" add AGENTS.md CLAUDE.md
git -C "$ABSOLUTE_IMPORT" commit -q -m absolute-import
out=$(run_hook_healthy_deps "$ABSOLUTE_IMPORT" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root READY via a ~/... home-relative import (HOME faked to the repo itself)'
TILDE_IMPORT="$TMP/tilde-import"
new_repo "$TILDE_IMPORT"
printf '# Agents\n' >"$TILDE_IMPORT/AGENTS.md"
printf '@~/AGENTS.md\n' >"$TILDE_IMPORT/CLAUDE.md"
git -C "$TILDE_IMPORT" add AGENTS.md CLAUDE.md
git -C "$TILDE_IMPORT" commit -q -m tilde-import
out=$(HOME="$TILDE_IMPORT" run_hook_healthy_deps "$TILDE_IMPORT" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root DIVERGED: @AGENTS.md inside an EIGHT-backtick inline span is still prose (variable-length delimiter, not a fixed cascade)'
EIGHT_BACKTICK="$TMP/eight-backtick"
new_repo "$EIGHT_BACKTICK"
printf '# Agents\n' >"$EIGHT_BACKTICK/AGENTS.md"
printf 'Use ````````@AGENTS.md```````` literally.\n' >"$EIGHT_BACKTICK/CLAUDE.md"
git -C "$EIGHT_BACKTICK" add AGENTS.md CLAUDE.md
git -C "$EIGHT_BACKTICK" commit -q -m eight-backtick
out=$(run_hook "$EIGHT_BACKTICK")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root DIVERGED: a shorter closing fence (~~~) cannot close a longer opener (~~~~), so the import stays swallowed by the still-open fence'
FENCE_LEN_MISMATCH="$TMP/fence-len-mismatch"
new_repo "$FENCE_LEN_MISMATCH"
printf '# Agents\n' >"$FENCE_LEN_MISMATCH/AGENTS.md"
printf '~~~~\n@AGENTS.md\n~~~\nstill fenced, closer was too short\n' >"$FENCE_LEN_MISMATCH/CLAUDE.md"
git -C "$FENCE_LEN_MISMATCH" add AGENTS.md CLAUDE.md
git -C "$FENCE_LEN_MISMATCH" commit -q -m fence-len-mismatch
out=$(run_hook "$FENCE_LEN_MISMATCH")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root DIVERGED: a tilde line cannot close a backtick fence, even mid-block'
FENCE_CHAR_MISMATCH="$TMP/fence-char-mismatch"
new_repo "$FENCE_CHAR_MISMATCH"
printf '# Agents\n' >"$FENCE_CHAR_MISMATCH/AGENTS.md"
printf '```\n~~~\n@AGENTS.md\n```\n' >"$FENCE_CHAR_MISMATCH/CLAUDE.md"
git -C "$FENCE_CHAR_MISMATCH" add AGENTS.md CLAUDE.md
git -C "$FENCE_CHAR_MISMATCH" commit -q -m fence-char-mismatch
out=$(run_hook "$FENCE_CHAR_MISMATCH")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root READY: a fence opener with an info string (```js) closes normally, and the import after it counts'
FENCE_INFO_STRING="$TMP/fence-info-string"
new_repo "$FENCE_INFO_STRING"
printf '# Agents\n' >"$FENCE_INFO_STRING/AGENTS.md"
printf '```js\nconst x = 1;\n```\n\n@AGENTS.md\n' >"$FENCE_INFO_STRING/CLAUDE.md"
git -C "$FENCE_INFO_STRING" add AGENTS.md CLAUDE.md
git -C "$FENCE_INFO_STRING" commit -q -m fence-info-string
out=$(run_hook_healthy_deps "$FENCE_INFO_STRING" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root READY: an opener indented 4+ spaces is NOT a CommonMark fence, so the import after it is real'
FENCE_OPENER_OVERINDENT="$TMP/fence-opener-overindent"
new_repo "$FENCE_OPENER_OVERINDENT"
printf '# Agents\n' >"$FENCE_OPENER_OVERINDENT/AGENTS.md"
printf '    ```\n@AGENTS.md\n    ```\n' >"$FENCE_OPENER_OVERINDENT/CLAUDE.md"
git -C "$FENCE_OPENER_OVERINDENT" add AGENTS.md CLAUDE.md
git -C "$FENCE_OPENER_OVERINDENT" commit -q -m fence-opener-overindent
out=$(run_hook_healthy_deps "$FENCE_OPENER_OVERINDENT" SessionStart)
[ -z "$out" ]

printf '%s\n' '== root DIVERGED: a closer indented 4+ spaces cannot close the fence, so the import stays swallowed'
FENCE_CLOSER_OVERINDENT="$TMP/fence-closer-overindent"
new_repo "$FENCE_CLOSER_OVERINDENT"
printf '# Agents\n' >"$FENCE_CLOSER_OVERINDENT/AGENTS.md"
printf '```\ncode\n    ```\n@AGENTS.md\n' >"$FENCE_CLOSER_OVERINDENT/CLAUDE.md"
git -C "$FENCE_CLOSER_OVERINDENT" add AGENTS.md CLAUDE.md
git -C "$FENCE_CLOSER_OVERINDENT" commit -q -m fence-closer-overindent
out=$(run_hook "$FENCE_CLOSER_OVERINDENT")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root DIVERGED: @AGENTS.md inside a MULTI-LINE inline code span (opener and closer on separate lines) is still prose'
MULTILINE_SPAN="$TMP/multiline-span"
new_repo "$MULTILINE_SPAN"
printf '# Agents\n' >"$MULTILINE_SPAN/AGENTS.md"
printf '`\n@AGENTS.md\n`\n' >"$MULTILINE_SPAN/CLAUDE.md"
git -C "$MULTILINE_SPAN" add AGENTS.md CLAUDE.md
git -C "$MULTILINE_SPAN" commit -q -m multiline-span
out=$(run_hook "$MULTILINE_SPAN")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root DIVERGED: @AGENTS.md alone in a plain 4-space-indented code block (no fence marker at all) is not a real import'
INDENTED_CODE_ONLY="$TMP/indented-code-only"
new_repo "$INDENTED_CODE_ONLY"
printf '# Agents\n' >"$INDENTED_CODE_ONLY/AGENTS.md"
printf '    @AGENTS.md\n' >"$INDENTED_CODE_ONLY/CLAUDE.md"
git -C "$INDENTED_CODE_ONLY" add AGENTS.md CLAUDE.md
git -C "$INDENTED_CODE_ONLY" commit -q -m indented-code-only
out=$(run_hook "$INDENTED_CODE_ONLY")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== root READY: content right after a closed fence (no blank line separator) is a fresh block, not a lazy continuation of the fenced code'
POST_FENCE_RESET="$TMP/post-fence-reset"
new_repo "$POST_FENCE_RESET"
printf '# Agents\n' >"$POST_FENCE_RESET/AGENTS.md"
printf '```\ncode\n```\n    ```\n@AGENTS.md\n    ```\n' >"$POST_FENCE_RESET/CLAUDE.md"
git -C "$POST_FENCE_RESET" add AGENTS.md CLAUDE.md
git -C "$POST_FENCE_RESET" commit -q -m post-fence-reset
out=$(run_hook_healthy_deps "$POST_FENCE_RESET" SessionStart)
[ -z "$out" ]

printf '%s\n' '== awk fallback parser (pandoc/jq hidden from PATH): still gets fence + post-fence-reset right'
out=$(run_hook_fallback_parser "$POST_FENCE_RESET")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== awk fallback parser: also correctly excludes a plain 4-space-indented block with no fence marker (indented-code detection is not limited to fence-shaped lines)'
out=$(run_hook_fallback_parser "$INDENTED_CODE_ONLY")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: consecutive indented-code lines stay excluded, not just the first line'
MULTILINE_INDENTED_CODE="$TMP/multiline-indented-code"
new_repo "$MULTILINE_INDENTED_CODE"
printf '# Agents\n' >"$MULTILINE_INDENTED_CODE/AGENTS.md"
printf '    code before\n    @AGENTS.md\n    code after\n' >"$MULTILINE_INDENTED_CODE/CLAUDE.md"
git -C "$MULTILINE_INDENTED_CODE" add AGENTS.md CLAUDE.md
git -C "$MULTILINE_INDENTED_CODE" commit -q -m multiline-indented-code
out=$(run_hook_fallback_parser "$MULTILINE_INDENTED_CODE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: blockquote prose remains prose, but indented code inside `>` stays excluded'
BLOCKQUOTE_INDENTED_CODE="$TMP/blockquote-indented-code"
new_repo "$BLOCKQUOTE_INDENTED_CODE"
printf '# Agents\n' >"$BLOCKQUOTE_INDENTED_CODE/AGENTS.md"
printf '>     @AGENTS.md\n' >"$BLOCKQUOTE_INDENTED_CODE/CLAUDE.md"
git -C "$BLOCKQUOTE_INDENTED_CODE" add AGENTS.md CLAUDE.md
git -C "$BLOCKQUOTE_INDENTED_CODE" commit -q -m blockquote-indented-code
out=$(run_hook_fallback_parser "$BLOCKQUOTE_INDENTED_CODE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

BLOCKQUOTE_PROSE="$TMP/blockquote-prose"
new_repo "$BLOCKQUOTE_PROSE"
printf '# Agents\n' >"$BLOCKQUOTE_PROSE/AGENTS.md"
printf '> @AGENTS.md\n' >"$BLOCKQUOTE_PROSE/CLAUDE.md"
git -C "$BLOCKQUOTE_PROSE" add AGENTS.md CLAUDE.md
git -C "$BLOCKQUOTE_PROSE" commit -q -m blockquote-prose
out=$(run_hook_fallback_parser "$BLOCKQUOTE_PROSE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== awk fallback parser: quote-like backticks inside a plain fence do not close it'
FENCE_WITH_QUOTE_LIKE_CONTENT="$TMP/fence-with-quote-like-content"
new_repo "$FENCE_WITH_QUOTE_LIKE_CONTENT"
printf '# Agents\n' >"$FENCE_WITH_QUOTE_LIKE_CONTENT/AGENTS.md"
printf '```\n> ```\n@AGENTS.md\n```\n' >"$FENCE_WITH_QUOTE_LIKE_CONTENT/CLAUDE.md"
git -C "$FENCE_WITH_QUOTE_LIKE_CONTENT" add AGENTS.md CLAUDE.md
git -C "$FENCE_WITH_QUOTE_LIKE_CONTENT" commit -q -m fence-with-quote-like-content
out=$(run_hook_fallback_parser "$FENCE_WITH_QUOTE_LIKE_CONTENT")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: a deeper nested blockquote marker cannot close a shallower quote fence'
NESTED_QUOTE_FENCE="$TMP/nested-quote-fence"
new_repo "$NESTED_QUOTE_FENCE"
printf '# Agents\n' >"$NESTED_QUOTE_FENCE/AGENTS.md"
printf '> ```\n> > ```\n> @AGENTS.md\n> ```\n' >"$NESTED_QUOTE_FENCE/CLAUDE.md"
git -C "$NESTED_QUOTE_FENCE" add AGENTS.md CLAUDE.md
git -C "$NESTED_QUOTE_FENCE" commit -q -m nested-quote-fence
out=$(run_hook_fallback_parser "$NESTED_QUOTE_FENCE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: list padding preserves indented code semantics'
LIST_INDENTED_CODE="$TMP/list-indented-code"
new_repo "$LIST_INDENTED_CODE"
printf '# Agents\n' >"$LIST_INDENTED_CODE/AGENTS.md"
printf -- '-     @AGENTS.md\n' >"$LIST_INDENTED_CODE/CLAUDE.md"
git -C "$LIST_INDENTED_CODE" add AGENTS.md CLAUDE.md
git -C "$LIST_INDENTED_CODE" commit -q -m list-indented-code
out=$(run_hook_fallback_parser "$LIST_INDENTED_CODE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: list prose imports remain prose, including tab padding'
LIST_PROSE="$TMP/list-prose"
new_repo "$LIST_PROSE"
printf '# Agents\n' >"$LIST_PROSE/AGENTS.md"
printf -- '- @AGENTS.md\n' >"$LIST_PROSE/CLAUDE.md"
git -C "$LIST_PROSE" add AGENTS.md CLAUDE.md
git -C "$LIST_PROSE" commit -q -m list-prose
out=$(run_hook_fallback_parser "$LIST_PROSE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== awk fallback parser: a same-level list sibling is not content of a preceding list-item fence'
LIST_FENCE_SIBLING="$TMP/list-fence-sibling"
new_repo "$LIST_FENCE_SIBLING"
printf '# Agents\n' >"$LIST_FENCE_SIBLING/AGENTS.md"
printf -- '- ```\n- @AGENTS.md\n- ```\n' >"$LIST_FENCE_SIBLING/CLAUDE.md"
git -C "$LIST_FENCE_SIBLING" add AGENTS.md CLAUDE.md
git -C "$LIST_FENCE_SIBLING" commit -q -m list-fence-sibling
out=$(run_hook_fallback_parser "$LIST_FENCE_SIBLING")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== awk fallback parser: nested list/blockquote containers preserve prose boundaries'
NESTED_LIST_FENCE_PROSE="$TMP/nested-list-fence-prose"
new_repo "$NESTED_LIST_FENCE_PROSE"
printf '# Agents\n' >"$NESTED_LIST_FENCE_PROSE/AGENTS.md"
printf -- '- > ```\n  - > @AGENTS.md\n  - > ```\n- > after\n' >"$NESTED_LIST_FENCE_PROSE/CLAUDE.md"
git -C "$NESTED_LIST_FENCE_PROSE" add AGENTS.md CLAUDE.md
git -C "$NESTED_LIST_FENCE_PROSE" commit -q -m nested-list-fence-prose
out=$(run_hook_fallback_parser "$NESTED_LIST_FENCE_PROSE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

QUOTE_LIST_TAB="$TMP/quote-list-tab"
new_repo "$QUOTE_LIST_TAB"
printf '# Agents\n' >"$QUOTE_LIST_TAB/AGENTS.md"
printf '> - \t@AGENTS.md\n' >"$QUOTE_LIST_TAB/CLAUDE.md"
git -C "$QUOTE_LIST_TAB" add AGENTS.md CLAUDE.md
git -C "$QUOTE_LIST_TAB" commit -q -m quote-list-tab
out=$(run_hook_fallback_parser "$QUOTE_LIST_TAB")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: a tab counts as four-column indentation for code blocks'
TAB_INDENTED_CODE="$TMP/tab-indented-code"
new_repo "$TAB_INDENTED_CODE"
printf '# Agents\n' >"$TAB_INDENTED_CODE/AGENTS.md"
printf '\t@AGENTS.md\n' >"$TAB_INDENTED_CODE/CLAUDE.md"
git -C "$TAB_INDENTED_CODE" add AGENTS.md CLAUDE.md
git -C "$TAB_INDENTED_CODE" commit -q -m tab-indented-code
out=$(run_hook_fallback_parser "$TAB_INDENTED_CODE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): DIVERGED'

printf '%s\n' '== awk fallback parser: an unindented block after indented code is processed as prose'
INDENTED_CODE_THEN_PROSE="$TMP/indented-code-then-prose"
new_repo "$INDENTED_CODE_THEN_PROSE"
printf '# Agents\n' >"$INDENTED_CODE_THEN_PROSE/AGENTS.md"
printf '    code before\n\n@AGENTS.md\n' >"$INDENTED_CODE_THEN_PROSE/CLAUDE.md"
git -C "$INDENTED_CODE_THEN_PROSE" add AGENTS.md CLAUDE.md
git -C "$INDENTED_CODE_THEN_PROSE" commit -q -m indented-code-then-prose
out=$(run_hook_fallback_parser "$INDENTED_CODE_THEN_PROSE")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== pandoc present on PATH but its process exits non-zero: falls back to awk instead of silently trusting empty/no output'
BROKEN_PANDOC_EXIT_IMPORT="$TMP/broken-pandoc-exit-import"
new_repo "$BROKEN_PANDOC_EXIT_IMPORT"
printf '# Agents\n' >"$BROKEN_PANDOC_EXIT_IMPORT/AGENTS.md"
printf '@AGENTS.md\n' >"$BROKEN_PANDOC_EXIT_IMPORT/CLAUDE.md"
git -C "$BROKEN_PANDOC_EXIT_IMPORT" add AGENTS.md CLAUDE.md
git -C "$BROKEN_PANDOC_EXIT_IMPORT" commit -q -m broken-pandoc-exit-import
out=$(run_hook_broken_pandoc_exit "$BROKEN_PANDOC_EXIT_IMPORT")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== pandoc present on PATH but emits invalid JSON: falls back to awk instead of trusting garbage output'
BROKEN_PANDOC_JSON_IMPORT="$TMP/broken-pandoc-json-import"
new_repo "$BROKEN_PANDOC_JSON_IMPORT"
printf '# Agents\n' >"$BROKEN_PANDOC_JSON_IMPORT/AGENTS.md"
printf '@AGENTS.md\n' >"$BROKEN_PANDOC_JSON_IMPORT/CLAUDE.md"
git -C "$BROKEN_PANDOC_JSON_IMPORT" add AGENTS.md CLAUDE.md
git -C "$BROKEN_PANDOC_JSON_IMPORT" commit -q -m broken-pandoc-json-import
out=$(run_hook_broken_pandoc_json "$BROKEN_PANDOC_JSON_IMPORT")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== pandoc emits valid JSON with the wrong shape: falls back to awk instead of trusting a non-AST object'
BROKEN_PANDOC_SHAPE_IMPORT="$TMP/broken-pandoc-shape-import"
new_repo "$BROKEN_PANDOC_SHAPE_IMPORT"
printf '# Agents\n' >"$BROKEN_PANDOC_SHAPE_IMPORT/AGENTS.md"
printf '@AGENTS.md\n' >"$BROKEN_PANDOC_SHAPE_IMPORT/CLAUDE.md"
git -C "$BROKEN_PANDOC_SHAPE_IMPORT" add AGENTS.md CLAUDE.md
git -C "$BROKEN_PANDOC_SHAPE_IMPORT" commit -q -m broken-pandoc-shape-import
out=$(run_hook_broken_pandoc_shape "$BROKEN_PANDOC_SHAPE_IMPORT")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): READY'

printf '%s\n' '== root BROKEN_SYMLINK with AGENTS.md present (points elsewhere)'
BROKEN="$TMP/broken"
new_repo "$BROKEN"
printf '# Agents\n' >"$BROKEN/AGENTS.md"
ln -s AGENTS-typo.md "$BROKEN/CLAUDE.md"
git -C "$BROKEN" add AGENTS.md CLAUDE.md
git -C "$BROKEN" commit -q -m broken
out=$(run_hook "$BROKEN")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): BROKEN_SYMLINK'

printf '%s\n' '== root BROKEN_SYMLINK with NO AGENTS.md at all (previously misreported as CLAUDE_ONLY)'
BROKEN_NO_AGENTS="$TMP/broken-no-agents"
new_repo "$BROKEN_NO_AGENTS"
ln -s missing.md "$BROKEN_NO_AGENTS/CLAUDE.md"
git -C "$BROKEN_NO_AGENTS" add CLAUDE.md
git -C "$BROKEN_NO_AGENTS" commit -q -m broken-no-agents
out=$(run_hook "$BROKEN_NO_AGENTS")
printf '%s' "$out" | grep -Fq 'Agent instructions (root): BROKEN_SYMLINK'
printf '%s' "$out" | grep -qF 'Agent instructions (root): CLAUDE_ONLY' && {
  echo 'FAIL: still misreports broken symlink as CLAUDE_ONLY' >&2
  exit 1
}

printf '%s\n' '== scoped candidate: README.md-only signal, scanned at SessionStart'
SCOPED="$TMP/scoped"
new_repo "$SCOPED"
printf '# Agents\n' >"$SCOPED/AGENTS.md"
ln -s AGENTS.md "$SCOPED/CLAUDE.md"
mkdir -p "$SCOPED/docs"
printf '# Docs\n' >"$SCOPED/docs/README.md"
git -C "$SCOPED" add AGENTS.md CLAUDE.md docs/README.md
git -C "$SCOPED" commit -q -m scoped
out=$(run_hook "$SCOPED" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq 'docs/ (README.md)'

printf '%s\n' '== scoped candidate: __tests__ directory name signal, no README.md needed'
TESTS_SCOPE="$TMP/tests-scope"
new_repo "$TESTS_SCOPE"
printf '# Agents\n' >"$TESTS_SCOPE/AGENTS.md"
ln -s AGENTS.md "$TESTS_SCOPE/CLAUDE.md"
mkdir -p "$TESTS_SCOPE/__tests__"
printf 'test("x", () => {});\n' >"$TESTS_SCOPE/__tests__/example.test.js"
git -C "$TESTS_SCOPE" add AGENTS.md CLAUDE.md __tests__/example.test.js
git -C "$TESTS_SCOPE" commit -q -m tests-scope
out=$(run_hook "$TESTS_SCOPE" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq '__tests__/ (test-suite directory)'

printf '%s\n' '== scoped candidate: Supabase Edge Function directory, no README.md needed'
SUPABASE="$TMP/supabase-scope"
new_repo "$SUPABASE"
printf '# Agents\n' >"$SUPABASE/AGENTS.md"
ln -s AGENTS.md "$SUPABASE/CLAUDE.md"
mkdir -p "$SUPABASE/supabase/functions/vulcan-detect"
printf 'export default () => {};\n' >"$SUPABASE/supabase/functions/vulcan-detect/index.ts"
git -C "$SUPABASE" add AGENTS.md CLAUDE.md supabase/functions/vulcan-detect/index.ts
git -C "$SUPABASE" commit -q -m supabase-scope
out=$(run_hook "$SUPABASE" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq 'supabase/functions/vulcan-detect/ (Supabase Edge Function)'

printf '%s\n' '== scoped candidate: package.json manifest signal'
MANIFEST="$TMP/manifest-scope"
new_repo "$MANIFEST"
printf '# Agents\n' >"$MANIFEST/AGENTS.md"
ln -s AGENTS.md "$MANIFEST/CLAUDE.md"
mkdir -p "$MANIFEST/packages/widget"
printf '{"name":"widget"}' >"$MANIFEST/packages/widget/package.json"
git -C "$MANIFEST" add AGENTS.md CLAUDE.md packages/widget/package.json
git -C "$MANIFEST" commit -q -m manifest-scope
out=$(run_hook "$MANIFEST" SessionStart)
printf '%s' "$out" | grep -Fq 'packages/widget/ (package.json)'

printf '%s\n' '== untracked directories are never reported (tracked-only, not name-based pruning)'
UNTRACKED="$TMP/untracked-scope"
new_repo "$UNTRACKED"
printf '# Agents\n' >"$UNTRACKED/AGENTS.md"
ln -s AGENTS.md "$UNTRACKED/CLAUDE.md"
git -C "$UNTRACKED" add AGENTS.md CLAUDE.md
git -C "$UNTRACKED" commit -q -m untracked-scope
mkdir -p "$UNTRACKED/node_modules/some-pkg"
printf '# Some package\n' >"$UNTRACKED/node_modules/some-pkg/README.md"
out=$(run_hook "$UNTRACKED" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 0 subdirectory'

printf '%s\n' '== a directory that already has its own scope AGENTS.md is not re-flagged'
BRIDGED_SCOPE="$TMP/bridged-scope"
new_repo "$BRIDGED_SCOPE"
printf '# Agents\n' >"$BRIDGED_SCOPE/AGENTS.md"
ln -s AGENTS.md "$BRIDGED_SCOPE/CLAUDE.md"
mkdir -p "$BRIDGED_SCOPE/docs"
printf '# Docs\n' >"$BRIDGED_SCOPE/docs/README.md"
printf '# Docs agents\n' >"$BRIDGED_SCOPE/docs/AGENTS.md"
ln -s AGENTS.md "$BRIDGED_SCOPE/docs/CLAUDE.md"
git -C "$BRIDGED_SCOPE" add AGENTS.md CLAUDE.md docs/README.md docs/AGENTS.md docs/CLAUDE.md
git -C "$BRIDGED_SCOPE" commit -q -m bridged-scope
out=$(run_hook_healthy_deps "$BRIDGED_SCOPE" SessionStart)
[ -z "$out" ]

printf '%s\n' '== a nested scope with AGENTS.md but no CLAUDE.md bridge is still flagged'
NESTED_AGENTS_ONLY="$TMP/nested-agents-only"
new_repo "$NESTED_AGENTS_ONLY"
printf '# Agents\n' >"$NESTED_AGENTS_ONLY/AGENTS.md"
ln -s AGENTS.md "$NESTED_AGENTS_ONLY/CLAUDE.md"
mkdir -p "$NESTED_AGENTS_ONLY/__tests__"
printf '# Test scope agents\n' >"$NESTED_AGENTS_ONLY/__tests__/AGENTS.md"
git -C "$NESTED_AGENTS_ONLY" add AGENTS.md CLAUDE.md __tests__/AGENTS.md
git -C "$NESTED_AGENTS_ONLY" commit -q -m nested-agents-only
out=$(run_hook "$NESTED_AGENTS_ONLY" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq '__tests__/ (AGENTS.md exists but Claude Code will not read it on its own'

printf '%s\n' '== a nested scope with CLAUDE.md but no AGENTS.md is still flagged (CLAUDE_ONLY is not silenced at scope level either)'
NESTED_CLAUDE_ONLY="$TMP/nested-claude-only"
new_repo "$NESTED_CLAUDE_ONLY"
printf '# Agents\n' >"$NESTED_CLAUDE_ONLY/AGENTS.md"
ln -s AGENTS.md "$NESTED_CLAUDE_ONLY/CLAUDE.md"
mkdir -p "$NESTED_CLAUDE_ONLY/__tests__"
printf '# Test scope notes, Claude only\n' >"$NESTED_CLAUDE_ONLY/__tests__/CLAUDE.md"
git -C "$NESTED_CLAUDE_ONLY" add AGENTS.md CLAUDE.md __tests__/CLAUDE.md
git -C "$NESTED_CLAUDE_ONLY" commit -q -m nested-claude-only
out=$(run_hook "$NESTED_CLAUDE_ONLY" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq '__tests__/ (CLAUDE.md exists without AGENTS.md'

printf '%s\n' '== a nested scope with a BROKEN CLAUDE.md symlink is still flagged, not silently accepted'
NESTED_BROKEN="$TMP/nested-broken"
new_repo "$NESTED_BROKEN"
printf '# Agents\n' >"$NESTED_BROKEN/AGENTS.md"
ln -s AGENTS.md "$NESTED_BROKEN/CLAUDE.md"
mkdir -p "$NESTED_BROKEN/__tests__"
printf '# Test scope agents\n' >"$NESTED_BROKEN/__tests__/AGENTS.md"
ln -s missing.md "$NESTED_BROKEN/__tests__/CLAUDE.md"
git -C "$NESTED_BROKEN" add AGENTS.md CLAUDE.md __tests__/AGENTS.md __tests__/CLAUDE.md
git -C "$NESTED_BROKEN" commit -q -m nested-broken
out=$(run_hook "$NESTED_BROKEN" SessionStart)
printf '%s' "$out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'
printf '%s' "$out" | grep -Fq '__tests__/ (CLAUDE.md is a symlink but its target does not exist'

printf '%s\n' '== scope scan does not run on UserPromptSubmit, only the cheap root check does'
NO_SCAN_ON_PROMPT="$TMP/no-scan-on-prompt"
new_repo "$NO_SCAN_ON_PROMPT"
printf '# Agents\n' >"$NO_SCAN_ON_PROMPT/AGENTS.md"
ln -s AGENTS.md "$NO_SCAN_ON_PROMPT/CLAUDE.md"
mkdir -p "$NO_SCAN_ON_PROMPT/docs"
printf '# Docs\n' >"$NO_SCAN_ON_PROMPT/docs/README.md"
git -C "$NO_SCAN_ON_PROMPT" add AGENTS.md CLAUDE.md docs/README.md
git -C "$NO_SCAN_ON_PROMPT" commit -q -m no-scan-on-prompt
prompt_out=$(run_hook_healthy_deps "$NO_SCAN_ON_PROMPT" UserPromptSubmit)
[ -z "$prompt_out" ]
# No GitHub ownership was ever established for this repo/session, but the
# local CodeGraph check is unconditional -- only GitHub branch-hygiene is
# owner-gated. Output still stays silent because codegraph reports healthy.
NO_OWNER_PROMPT_CALLS="$TMP/no-owner-prompt-codegraph-calls"
NO_OWNER_PROMPT_CODEGRAPH="$TMP/no-owner-prompt-codegraph"
cat >"$NO_OWNER_PROMPT_CODEGRAPH" <<EOF
#!/usr/bin/env bash
printf '%s\n' called >>"$NO_OWNER_PROMPT_CALLS"
printf '%s' '{"initialized":true,"indexPath":"$MOCK_INDEX"}'
EOF
chmod +x "$NO_OWNER_PROMPT_CODEGRAPH"
prompt_out=$(CODEGRAPH_BIN="$NO_OWNER_PROMPT_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  run_hook "$NO_SCAN_ON_PROMPT" UserPromptSubmit no-owner-prompt-session)
[ -z "$prompt_out" ]
[ -e "$NO_OWNER_PROMPT_CALLS" ]
session_out=$(run_hook_healthy_deps "$NO_SCAN_ON_PROMPT" SessionStart)
printf '%s' "$session_out" | grep -Fq 'Scoped-instruction candidates (scanned at SessionStart only): 1 subdirectory'

printf '%s\n' '== paths with spaces are handled correctly'
SPACEY="$TMP/spacey scope"
new_repo "$SPACEY"
printf '# Agents\n' >"$SPACEY/AGENTS.md"
ln -s AGENTS.md "$SPACEY/CLAUDE.md"
mkdir -p "$SPACEY/my docs"
printf '# My docs\n' >"$SPACEY/my docs/README.md"
git -C "$SPACEY" add AGENTS.md CLAUDE.md "my docs/README.md"
git -C "$SPACEY" commit -q -m spacey
out=$(run_hook "$SPACEY" SessionStart)
printf '%s' "$out" | grep -Fq 'my docs/ (README.md)'

# Repo hygiene (GitHub, owner-only) fixtures. A fake `gh` on a restricted PATH
# is the same style already used above for fake pandoc: it never touches the
# network, so these scenarios are deterministic and offline. Each fake `gh`
# also drops a marker file when the branches/.../protection endpoint is
# called, so "does this stay NOT_APPLICABLE without even checking protection"
# is a real assertion, not just an assumption about short-circuiting.
new_github_repo() {
  local dir="$1" remote_url="${2:-https://github.com/testuser/testrepo.git}"
  new_repo "$dir"
  git -C "$dir" remote set-url origin "$remote_url"
}

make_fake_gh() {
  local bin_dir="$1" auth_ok="$2" is_admin="$3" protected="$4" delete_on_merge="$5" marker="$6" default_branch="${7-main}"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$marker.calls"
if [ "\$1" = "auth" ] && [ "\$2" = "status" ]; then
  [ "$auth_ok" = "1" ] && exit 0 || exit 1
fi
if [ "\$1" = "api" ]; then
  case "\$2" in
    */branches/*/protection)
      : >"$marker"
      if [ "$protected" = "1" ]; then
        printf '%s' '{"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"required_status_checks":{"contexts":[],"checks":[{"context":"ci","app_id":123}]}}'
      else
        printf '%s' '{"message":"Branch not protected"}'
        exit 1
      fi
      ;;
    repos/*)
      [ "$auth_ok" = "1" ] || exit 1
      printf '{"permissions":{"admin":$is_admin},"default_branch":"$default_branch","delete_branch_on_merge":$delete_on_merge}'
      ;;
  esac
fi
EOF
  chmod +x "$bin_dir/gh"
}

printf '%s\n' '== repo hygiene: no GitHub remote at all never invokes gh'
NO_REMOTE="$TMP/hygiene-no-remote"
new_repo "$NO_REMOTE"
git -C "$NO_REMOTE" remote remove origin
NO_REMOTE_GH_BIN="$TMP/hygiene-no-remote-gh-marker"
NO_REMOTE_MARKER="$TMP/hygiene-no-remote-marker"
make_fake_gh "$NO_REMOTE_GH_BIN" 1 true 1 true "$NO_REMOTE_MARKER"
out=$(PATH="$NO_REMOTE_GH_BIN:$PATH" run_hook "$NO_REMOTE" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
[ ! -e "$NO_REMOTE_MARKER" ]
[ ! -e "$NO_REMOTE_MARKER.calls" ]

printf '%s\n' '== repo hygiene: non-GitHub remote never invokes gh'
NON_GITHUB="$TMP/hygiene-non-github"
new_repo "$NON_GITHUB"
git -C "$NON_GITHUB" remote set-url origin https://gitlab.com/testuser/testrepo.git
NON_GITHUB_GH_BIN="$TMP/hygiene-non-github-gh-marker"
NON_GITHUB_MARKER="$TMP/hygiene-non-github-marker"
make_fake_gh "$NON_GITHUB_GH_BIN" 1 true 1 true "$NON_GITHUB_MARKER"
out=$(PATH="$NON_GITHUB_GH_BIN:$PATH" run_hook "$NON_GITHUB" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
[ ! -e "$NON_GITHUB_MARKER" ]
[ ! -e "$NON_GITHUB_MARKER.calls" ]

printf '%s\n' '== a hostname containing github.com but not GitHub never invokes gh'
SPOOFED_HOST="$TMP/hygiene-spoofed-host"
new_repo "$SPOOFED_HOST"
git -C "$SPOOFED_HOST" remote set-url origin https://evilgithub.com/testuser/testrepo.git
SPOOFED_HOST_GH_BIN="$TMP/hygiene-spoofed-host-gh"
SPOOFED_HOST_MARKER="$TMP/hygiene-spoofed-host-marker"
make_fake_gh "$SPOOFED_HOST_GH_BIN" 1 true 1 true "$SPOOFED_HOST_MARKER"
out=$(PATH="$SPOOFED_HOST_GH_BIN:$PATH" run_hook "$SPOOFED_HOST" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
[ ! -e "$SPOOFED_HOST_MARKER" ]
[ ! -e "$SPOOFED_HOST_MARKER.calls" ]

printf '%s\n' '== repo hygiene: gh not authenticated stays NOT_APPLICABLE'
UNAUTH="$TMP/hygiene-unauth"
new_github_repo "$UNAUTH"
UNAUTH_GH_BIN="$TMP/hygiene-unauth-gh"
UNAUTH_MARKER="$TMP/hygiene-unauth-marker"
make_fake_gh "$UNAUTH_GH_BIN" 0 true 1 true "$UNAUTH_MARKER"
out=$(PATH="$UNAUTH_GH_BIN:$PATH" run_hook "$UNAUTH" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
[ ! -e "$UNAUTH_MARKER" ]
! grep -Fq 'api repos/' "$UNAUTH_MARKER.calls"
! grep -Fq '/protection' "$UNAUTH_MARKER.calls"

printf '%s\n' '== repo hygiene: authenticated but not the repo admin stays NOT_APPLICABLE, never checks branch protection'
NON_ADMIN="$TMP/hygiene-non-admin"
new_github_repo "$NON_ADMIN"
NON_ADMIN_GH_BIN="$TMP/hygiene-non-admin-gh"
NON_ADMIN_MARKER="$TMP/hygiene-non-admin-marker"
make_fake_gh "$NON_ADMIN_GH_BIN" 1 false 1 true "$NON_ADMIN_MARKER"
out=$(PATH="$NON_ADMIN_GH_BIN:$PATH" run_hook "$NON_ADMIN" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
[ ! -e "$NON_ADMIN_MARKER" ]
! grep -Fq '/protection' "$NON_ADMIN_MARKER.calls"

printf '%s\n' '== non-admin still runs local maintainability checks (only branch protection is owner-gated)'
NON_ADMIN_CODEGRAPH="$TMP/hygiene-non-admin-codegraph"
NON_ADMIN_OPENSPEC="$TMP/hygiene-non-admin-openspec"
NON_ADMIN_LOCAL_CALLS="$TMP/hygiene-non-admin-local-calls"
cat >"$NON_ADMIN_CODEGRAPH" <<EOF
#!/usr/bin/env bash
printf '%s\n' codegraph >>"$NON_ADMIN_LOCAL_CALLS"
printf '%s' '{"initialized":true,"indexPath":"$TMP/mock-index"}'
EOF
cat >"$NON_ADMIN_OPENSPEC" <<EOF
#!/usr/bin/env bash
printf '%s\n' openspec >>"$NON_ADMIN_LOCAL_CALLS"
exit 0
EOF
chmod +x "$NON_ADMIN_CODEGRAPH" "$NON_ADMIN_OPENSPEC"
out=$(CODEGRAPH_BIN="$NON_ADMIN_CODEGRAPH" OPENSPEC_BIN="$NON_ADMIN_OPENSPEC" \
  PATH="$NON_ADMIN_GH_BIN:$PATH" run_hook "$NON_ADMIN" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): NOT_APPLICABLE'
printf '%s' "$out" | grep -Fq 'CodeGraph: READY'
grep -Fqx codegraph "$NON_ADMIN_LOCAL_CALLS"

printf '%s\n' '== repo hygiene: admin with unprotected branch and no auto-delete reports MISSING with specific gaps'
ADMIN_MISSING="$TMP/hygiene-admin-missing"
new_github_repo "$ADMIN_MISSING"
ADMIN_MISSING_GH_BIN="$TMP/hygiene-admin-missing-gh"
ADMIN_MISSING_MARKER="$TMP/hygiene-admin-missing-marker"
make_fake_gh "$ADMIN_MISSING_GH_BIN" 1 true 0 false "$ADMIN_MISSING_MARKER"
out=$(PATH="$ADMIN_MISSING_GH_BIN:$PATH" run_hook "$ADMIN_MISSING" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): MISSING'
printf '%s' "$out" | grep -Fq 'allows force-push'
printf '%s' "$out" | grep -Fq 'allows deletion'
printf '%s' "$out" | grep -Fq 'no required status check'
printf '%s' "$out" | grep -Fq 'not auto-deleted'
[ -e "$ADMIN_MISSING_MARKER" ]

printf '%s\n' '== admin metadata without a default branch reports UNAVAILABLE and never checks protection'
ADMIN_NO_DEFAULT="$TMP/hygiene-admin-no-default"
new_github_repo "$ADMIN_NO_DEFAULT"
ADMIN_NO_DEFAULT_GH_BIN="$TMP/hygiene-admin-no-default-gh"
ADMIN_NO_DEFAULT_MARKER="$TMP/hygiene-admin-no-default-marker"
make_fake_gh "$ADMIN_NO_DEFAULT_GH_BIN" 1 true 1 true "$ADMIN_NO_DEFAULT_MARKER" ''
out=$(PATH="$ADMIN_NO_DEFAULT_GH_BIN:$PATH" run_hook "$ADMIN_NO_DEFAULT" SessionStart)
printf '%s' "$out" | grep -Fq 'Repo hygiene (GitHub, owner-only): UNAVAILABLE'
[ ! -e "$ADMIN_NO_DEFAULT_MARKER" ]
! grep -Fq '/protection' "$ADMIN_NO_DEFAULT_MARKER.calls"

printf '%s\n' '== repo hygiene: admin with everything configured reports READY and stays silent when combined with other healthy integrations'
ADMIN_READY="$TMP/hygiene-admin-ready"
new_repo "$ADMIN_READY"
printf '# Agents\n' >"$ADMIN_READY/AGENTS.md"
ln -s AGENTS.md "$ADMIN_READY/CLAUDE.md"
git -C "$ADMIN_READY" add AGENTS.md CLAUDE.md
git -C "$ADMIN_READY" commit -q -m agents
git -C "$ADMIN_READY" remote set-url origin 'https://github.com/testuser/test.repo.git'
ADMIN_READY_GH_BIN="$TMP/hygiene-admin-ready-gh"
ADMIN_READY_MARKER="$TMP/hygiene-admin-ready-marker"
make_fake_gh "$ADMIN_READY_GH_BIN" 1 true 1 true "$ADMIN_READY_MARKER"
silent_out=$(CODEGRAPH_BIN="$MOCK_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" PATH="$ADMIN_READY_GH_BIN:$PATH" run_hook "$ADMIN_READY" SessionStart)
[ -z "$silent_out" ]
[ -e "$ADMIN_READY_MARKER" ]

printf '%s\n' '== an owned SessionStart authorizes only the same project/session UserPromptSubmit'
OWNER_PROMPT="$TMP/hygiene-owner-prompt"
new_github_repo "$OWNER_PROMPT"
printf '# Agents\n' >"$OWNER_PROMPT/AGENTS.md"
ln -s AGENTS.md "$OWNER_PROMPT/CLAUDE.md"
git -C "$OWNER_PROMPT" add AGENTS.md CLAUDE.md
git -C "$OWNER_PROMPT" commit -q -m agents
OWNER_PROMPT_INDEX="$TMP/owner-prompt-index"
mkdir -p "$OWNER_PROMPT_INDEX"
OWNER_PROMPT_CODEGRAPH="$TMP/owner-prompt-codegraph"
OWNER_PROMPT_CODEGRAPH_CALLS="$TMP/owner-prompt-codegraph-calls"
cat >"$OWNER_PROMPT_CODEGRAPH" <<EOF
#!/usr/bin/env bash
printf '%s\n' called >>"$OWNER_PROMPT_CODEGRAPH_CALLS"
printf '%s' '{"initialized":true,"indexPath":"$OWNER_PROMPT_INDEX"}'
EOF
chmod +x "$OWNER_PROMPT_CODEGRAPH"
OWNER_PROMPT_GH_BIN="$TMP/owner-prompt-gh"
OWNER_PROMPT_MARKER="$TMP/owner-prompt-marker"
make_fake_gh "$OWNER_PROMPT_GH_BIN" 1 true 1 true "$OWNER_PROMPT_MARKER"
OWNER_PROMPT_SESSION='owner-prompt-session'
session_out=$(CODEGRAPH_BIN="$OWNER_PROMPT_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  PATH="$OWNER_PROMPT_GH_BIN:$PATH" run_hook "$OWNER_PROMPT" SessionStart "$OWNER_PROMPT_SESSION")
[ -z "$session_out" ]
gh_calls_before=$(wc -l <"$OWNER_PROMPT_MARKER.calls")
codegraph_calls_before=$(wc -l <"$OWNER_PROMPT_CODEGRAPH_CALLS")
[ "$gh_calls_before" -eq 3 ]
prompt_out=$(CODEGRAPH_BIN="$OWNER_PROMPT_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  PATH="$OWNER_PROMPT_GH_BIN:$PATH" run_hook "$OWNER_PROMPT" UserPromptSubmit "$OWNER_PROMPT_SESSION")
[ -z "$prompt_out" ]
gh_calls_after=$(wc -l <"$OWNER_PROMPT_MARKER.calls")
codegraph_calls_after=$(wc -l <"$OWNER_PROMPT_CODEGRAPH_CALLS")
[ "$gh_calls_after" -eq "$gh_calls_before" ]
[ "$codegraph_calls_after" -gt "$codegraph_calls_before" ]

# A session/remote mismatch only invalidates the cached GitHub-hygiene
# authorization -- it must NOT also disable the local, unconditional
# CodeGraph/OpenSpec/AGENTS.md checks (that was the exact regression this
# suite caught). Both still run and produce silent output (all healthy),
# and gh is never invoked again in either case: repo hygiene is
# SessionStart-only regardless of the local checks' own outcome.
codegraph_calls_before_mismatch="$codegraph_calls_after"
prompt_out=$(CODEGRAPH_BIN="$OWNER_PROMPT_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  PATH="$OWNER_PROMPT_GH_BIN:$PATH" run_hook "$OWNER_PROMPT" UserPromptSubmit wrong-session)
[ -z "$prompt_out" ]
[ "$(wc -l <"$OWNER_PROMPT_CODEGRAPH_CALLS")" -gt "$codegraph_calls_before_mismatch" ]
[ "$(wc -l <"$OWNER_PROMPT_MARKER.calls")" -eq "$gh_calls_after" ]

git -C "$OWNER_PROMPT" remote set-url origin 'https://github.com/other-user/other-repo.git'
codegraph_calls_before_remote_change=$(wc -l <"$OWNER_PROMPT_CODEGRAPH_CALLS")
prompt_out=$(CODEGRAPH_BIN="$OWNER_PROMPT_CODEGRAPH" CLAUDE_CONFIG="$MOCK_CLAUDE_CONFIG" \
  PATH="$OWNER_PROMPT_GH_BIN:$PATH" run_hook "$OWNER_PROMPT" UserPromptSubmit "$OWNER_PROMPT_SESSION")
[ -z "$prompt_out" ]
[ "$(wc -l <"$OWNER_PROMPT_CODEGRAPH_CALLS")" -gt "$codegraph_calls_before_remote_change" ]
[ "$(wc -l <"$OWNER_PROMPT_MARKER.calls")" -eq "$gh_calls_after" ]

printf '%s\n' 'PASS: AGENTS.md/CLAUDE.md root and scoped-instruction detection stays read-only and accurate'
