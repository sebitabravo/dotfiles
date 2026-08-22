#!/usr/bin/env bash
# SessionStart/UserPromptSubmit hook — verifies project-local CodeGraph and
# OpenSpec projects, the AGENTS.md/CLAUDE.md bridge, and (owner-only) GitHub
# repo hygiene, all used by the SDD workflow.
#
# CodeGraph, OpenSpec, and the AGENTS.md/CLAUDE.md bridge are pure local,
# read-only filesystem checks and always run, regardless of GitHub ownership
# or remote host. Only the GitHub branch-hygiene check is owner-gated: a
# GitHub admin snapshot is established at SessionStart, and UserPromptSubmit
# reuses that snapshot for the same project/session without a network call.
#
# This hook is deliberately read-only. `codegraph init` creates project files,
# so the hook reports the exact remediation instead of silently mutating an
# arbitrary repository.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')

if command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
  EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
else
  CWD=""
  EVENT=""
  SESSION_ID=""
fi

CWD="${PROJECT_ROOT:-${CWD:-${PWD:-}}}"
[ -d "$CWD" ] || exit 0

PROJECT_ROOT_RESOLVED=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$PROJECT_ROOT_RESOLVED" ] && CWD="$PROJECT_ROOT_RESOLVED"

[ -d "$CWD" ] || exit 0

case "$EVENT" in
  SessionStart|UserPromptSubmit) ;;
  *) EVENT="UserPromptSubmit" ;;
esac

# GitHub CLI has no portable per-request timeout on a stock macOS install.
# Prefer coreutils when present, otherwise inspect the real child process and
# kill it ourselves. The SessionStart hook has a 10s outer timeout, so a
# bounded request is required here; otherwise a stalled network call can make
# the entire hook appear broken.
GH_REQUEST_TIMEOUT_SECONDS=2
gh_request() {
  local result_file gh_pid elapsed_tenths request_rc process_state

  if command -v timeout >/dev/null 2>&1; then
    timeout "$GH_REQUEST_TIMEOUT_SECONDS" gh "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$GH_REQUEST_TIMEOUT_SECONDS" gh "$@"
    return $?
  fi

  result_file=$(mktemp "${TMPDIR:-/tmp}/project-integrations-check.XXXXXX") || return 125
  gh "$@" >"$result_file" 2>/dev/null &
  gh_pid=$!
  elapsed_tenths=0
  while :; do
    process_state=$(ps -o state= -p "$gh_pid" 2>/dev/null | tr -d '[:space:]')
    case "$process_state" in
      ""|Z*) break ;;
    esac
    if [ "$elapsed_tenths" -ge $((GH_REQUEST_TIMEOUT_SECONDS * 10)) ]; then
      kill "$gh_pid" >/dev/null 2>&1 || true
      wait "$gh_pid" >/dev/null 2>&1 || true
      rm -f "$result_file"
      return 124
    fi
    sleep 0.1
    elapsed_tenths=$((elapsed_tenths + 1))
  done

  wait "$gh_pid"
  request_rc=$?
  cat "$result_file"
  rm -f "$result_file"
  return "$request_rc"
}

github_repo_slug() {
  local remote_url="$1" path owner repo

  case "$remote_url" in
    https://github.com/*) path=${remote_url#https://github.com/} ;;
    http://github.com/*) path=${remote_url#http://github.com/} ;;
    git://github.com/*) path=${remote_url#git://github.com/} ;;
    ssh://git@github.com/*) path=${remote_url#ssh://git@github.com/} ;;
    git@github.com:*) path=${remote_url#git@github.com:} ;;
    *) return 1 ;;
  esac

  path=${path%%\?*}
  path=${path%%\#*}
  path=${path%/}
  case "$path" in
    *.git) path=${path%.git} ;;
  esac

  owner=${path%%/*}
  repo=${path#*/}
  [ -n "$owner" ] || return 1
  [ "$repo" != "$path" ] || return 1
  case "$repo" in
    ""|*/*) return 1 ;;
  esac
  printf '%s/%s' "$owner" "$repo"
}

owner_state_key() {
  local value="$1" digest
  if command -v shasum >/dev/null 2>&1; then
    digest=$(printf '%s' "$value" | shasum -a 256 2>/dev/null | awk '{print $1}' || true)
    [ -n "$digest" ] && { printf '%s' "$digest"; return; }
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    digest=$(printf '%s' "$value" | sha256sum 2>/dev/null | awk '{print $1}' || true)
    [ -n "$digest" ] && { printf '%s' "$digest"; return; }
  fi
  printf '%s' "$value" | cksum | awk '{print $1}'
}

OWNER_STATE_FILE=""
if [ -n "$SESSION_ID" ]; then
  OWNER_STATE_FILE="${TMPDIR:-/tmp}/project-integrations-check-owner.$(owner_state_key "$CWD|$SESSION_ID")"
fi

owner_state_matches() {
  local current_root current_remote current_repo
  [ -n "$OWNER_STATE_FILE" ] && [ -f "$OWNER_STATE_FILE" ] || return 1
  current_root=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
  [ "$current_root" = "$CWD" ] || return 1
  current_remote=$(git -C "$CWD" remote get-url origin 2>/dev/null || true)
  current_repo=$(github_repo_slug "$current_remote" 2>/dev/null || true)
  [ -n "$current_repo" ] || return 1
  grep -Fqx -- "root=$CWD" "$OWNER_STATE_FILE" 2>/dev/null || return 1
  grep -Fqx -- "session=$SESSION_ID" "$OWNER_STATE_FILE" 2>/dev/null || return 1
  grep -Fqx -- "repo=$current_repo" "$OWNER_STATE_FILE" 2>/dev/null
}

write_owner_state() {
  local state_tmp
  [ -n "$OWNER_STATE_FILE" ] || return 1
  umask 077
  state_tmp=$(mktemp "${OWNER_STATE_FILE}.tmp.XXXXXX" 2>/dev/null) || return 1
  {
    printf 'root=%s\n' "$CWD"
    printf 'session=%s\n' "$SESSION_ID"
    printf 'repo=%s\n' "$REPO_SLUG"
  } >"$state_tmp" || {
    rm -f "$state_tmp"
    return 1
  }
  mv -f "$state_tmp" "$OWNER_STATE_FILE"
}

# This gate protects ONLY the GitHub branch-hygiene check below
# (repo_hygiene_state) -- CodeGraph, OpenSpec, and the AGENTS.md/CLAUDE.md
# bridge are pure local, read-only filesystem checks with no relationship to
# who owns the repo on GitHub, and must keep running unconditionally exactly
# as they did before this check existed. Gating them on GitHub admin status
# would silently disable them for every non-GitHub remote (GitLab, a local-
# only repo) and for every GitHub repo without a `gh` session, which is a
# regression, not the behavior asked for.
#
# Ownership is established once at SessionStart and cached only for the exact
# Git root/repository/session pair; UserPromptSubmit reuses that cache
# instead of making a network call, but never exits early on a cache miss --
# doing so would also (accidentally) skip the cheap, always-local AGENTS.md
# root check on every prompt until a fresh SessionStart re-establishes it.
OWNER_GATE_STATE="NOT_APPLICABLE"
OWNER_NOT_APPLICABLE_REASON=""
GH_REMOTE_URL=""
REPO_SLUG=""
REPO_META=""
REPO_IS_ADMIN="false"
if [ "$EVENT" = "SessionStart" ] && git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  GH_REMOTE_URL=$(git -C "$CWD" remote get-url origin 2>/dev/null || true)
  REPO_SLUG=$(github_repo_slug "$GH_REMOTE_URL" 2>/dev/null || true)
  if [ -z "$REPO_SLUG" ]; then
    OWNER_NOT_APPLICABLE_REASON="there is no valid GitHub origin remote."
  elif ! command -v gh >/dev/null 2>&1; then
    OWNER_NOT_APPLICABLE_REASON="the gh CLI is not installed."
  elif ! command -v jq >/dev/null 2>&1; then
    OWNER_NOT_APPLICABLE_REASON="jq is not installed."
  elif ! gh_request auth status >/dev/null 2>&1; then
    OWNER_NOT_APPLICABLE_REASON="gh is not authenticated; no GitHub API call was made."
  else
    REPO_META=$(gh_request api "repos/$REPO_SLUG" || true)
    REPO_IS_ADMIN=$(printf '%s' "$REPO_META" | jq -r '.permissions.admin // false' 2>/dev/null || printf 'false')
    if [ "$REPO_IS_ADMIN" = "true" ]; then
      OWNER_GATE_STATE="OWNER"
      write_owner_state || true
    else
      OWNER_NOT_APPLICABLE_REASON="GitHub did not confirm permissions.admin=true; no branch-protection check was made."
    fi
  fi
elif [ "$EVENT" = "UserPromptSubmit" ] && owner_state_matches; then
  OWNER_GATE_STATE="OWNER"
fi

resolve_binary() {
  local override="$1"
  if [ -n "$override" ]; then
    printf '%s' "$override"
    return 0
  fi
  command -v "$2" 2>/dev/null || true
}

CODEGRAPH_BIN=$(resolve_binary "${CODEGRAPH_BIN:-}" codegraph)
OPENSPEC_BIN=$(resolve_binary "${OPENSPEC_BIN:-}" openspec)

codegraph_mcp_state="CONFIGURED"
codegraph_mcp_detail=""
MCP_CONFIG="${CLAUDE_CONFIG:-$HOME/.claude.json}"
if [ ! -f "$MCP_CONFIG" ] || ! jq -e '.mcpServers.codegraph.command // empty' "$MCP_CONFIG" >/dev/null 2>&1; then
  codegraph_mcp_state="NOT_CONFIGURED"
  codegraph_mcp_detail="The CodeGraph server was not found in the global Claude configuration."
fi

codegraph_state="READY"
codegraph_detail=""
if [ -z "$CODEGRAPH_BIN" ] || [ ! -x "$CODEGRAPH_BIN" ]; then
  codegraph_state="CLI_MISSING"
  codegraph_detail="The codegraph CLI was not found in PATH."
else
  CODEGRAPH_STATUS=$("$CODEGRAPH_BIN" status --json "$CWD" 2>/dev/null || true)
  CODEGRAPH_INITIALIZED=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.initialized // false' 2>/dev/null || printf 'false')
  CODEGRAPH_INDEX=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.indexPath // empty' 2>/dev/null || true)
  if [ "$CODEGRAPH_INITIALIZED" != "true" ]; then
    codegraph_state="NOT_INITIALIZED"
    codegraph_detail="The project has no initialized CodeGraph index."
  elif [ -z "$CODEGRAPH_INDEX" ] || [ ! -d "$CODEGRAPH_INDEX" ]; then
    codegraph_state="BROKEN"
    codegraph_detail="CodeGraph reports it is initialized, but its index directory is missing."
  fi
fi

codegraph_gitignore_state="NOT_APPLICABLE"
codegraph_gitignore_detail=""
if git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  CODEGRAPH_TRACKED_PATH=$(git -C "$CWD" ls-files -- .codegraph 2>/dev/null | head -n 1 || true)
  if [ -n "$CODEGRAPH_TRACKED_PATH" ]; then
    codegraph_gitignore_state="TRACKED_EXISTING"
    codegraph_gitignore_detail="CodeGraph was already versioned; that tracking is preserved and left unchanged."
  else
    CODEGRAPH_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- .codegraph/ 2>/dev/null || true)
    CODEGRAPH_IGNORE_SOURCE=${CODEGRAPH_IGNORE_MATCH%%:*}
    if [ "$CODEGRAPH_IGNORE_SOURCE" = ".gitignore" ] || [ "$CODEGRAPH_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      codegraph_gitignore_state="CONFIGURED"
    else
      codegraph_gitignore_state="NOT_CONFIGURED"
      codegraph_gitignore_detail="The project root does not ignore .codegraph/ in its .gitignore."
    fi
  fi
fi

# OpenSpec is local-only in this setup: do not add its AI planning artifacts to
# repositories unless they were already tracked. Once an openspec/ directory
# exists (or OPENSPEC_REQUIRED is enabled), validate it without initializing or
# installing anything automatically.
openspec_state="NOT_ENABLED"
openspec_detail=""
openspec_gitignore_state="NOT_APPLICABLE"
openspec_gitignore_detail=""
if [ -d "$CWD/openspec" ] || [ "${OPENSPEC_REQUIRED:-false}" = "true" ]; then
  OPENSPEC_TRACKED_PATH=$(git -C "$CWD" ls-files -- openspec 2>/dev/null | head -n 1 || true)
  if [ -n "$OPENSPEC_TRACKED_PATH" ]; then
    openspec_gitignore_state="TRACKED_EXISTING"
    openspec_gitignore_detail="OpenSpec was already versioned; that tracking is preserved and left unchanged."
  else
    OPENSPEC_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- openspec/ 2>/dev/null || true)
    OPENSPEC_IGNORE_SOURCE=${OPENSPEC_IGNORE_MATCH%%:*}
    if [ "$OPENSPEC_IGNORE_SOURCE" = ".gitignore" ] || [ "$OPENSPEC_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      openspec_gitignore_state="CONFIGURED"
    else
      openspec_gitignore_state="NOT_CONFIGURED"
      openspec_gitignore_detail="The project root does not ignore openspec/ in its .gitignore."
    fi
  fi
  if [ -z "$OPENSPEC_BIN" ] || [ ! -x "$OPENSPEC_BIN" ]; then
    openspec_state="CLI_MISSING"
    openspec_detail="The project uses OpenSpec, but the openspec CLI was not found in PATH."
  elif [ ! -d "$CWD/openspec/specs" ] || [ ! -d "$CWD/openspec/changes" ]; then
    openspec_state="NOT_INITIALIZED"
    openspec_detail="The openspec/specs + openspec/changes structure is missing."
  elif ! (cd "$CWD" && "$OPENSPEC_BIN" status --json >/dev/null 2>&1); then
    openspec_state="BROKEN"
    openspec_detail="OpenSpec is present, but openspec status --json does not pass."
  else
    openspec_state="READY"
  fi
fi

# Agent instructions (Claude Code only: AGENTS.md as the canonical source,
# CLAUDE.md as the bridge Claude Code actually reads). Detection only — never
# creates a file. README.md alone no longer counts as agent instructions.
#
# claude_md_imports_agents: Claude Code's `@path` import syntax is not limited
# to the first line of the file (docs: "reference them with @ syntax anywhere
# in your CLAUDE.md"), and import parsing skips both fenced code blocks AND
# inline code spans (`@AGENTS.md` in backticks is prose about the convention,
# not an import). CommonMark fences can open with ``` or ~~~, and inline
# spans can use ANY number of backticks as the delimiter (``@x``, ```@x```,
# ````@x````, ...) to quote text that itself contains backticks — a span
# only closes at a run of backticks of the SAME length as its opener, so a
# fixed cascade of a few sed substitutions (single, double, triple, ...)
# always misses some length. The awk function below finds the real closing
# run instead of guessing a delimiter width. Relative imports resolve
# against the directory that CONTAINS the CLAUDE.md doing the importing (not
# always the project root — a nested CLAUDE.md's imports resolve against its
# own directory); absolute paths (`/...`) and `~`-paths are used as-is. Any
# @token that resolves to the same file as AGENTS.md counts, not just the
# literal string "AGENTS.md" — `@./AGENTS.md` and `@AGENTS.md` are the same
# bridge.
claude_md_imports_agents() {
  local claude_file="$1" agents_file="$2" containing_dir="$3" candidate resolved
  [ -f "$claude_file" ] || return 1
  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    # These are case patterns matching a literal "~" prefix, not asking the
    # shell to expand it; expansion happens explicitly in the branch bodies.
    # shellcheck disable=SC2088
    case "$candidate" in
      /*) resolved="$candidate" ;;
      "~") resolved="$HOME" ;;
      "~/"*) resolved="$HOME/${candidate#\~/}" ;;
      *) resolved="$containing_dir/$candidate" ;;
    esac
    if [ -e "$resolved" ] && [ "$resolved" -ef "$agents_file" ]; then
      return 0
    fi
  done < <(claude_md_import_candidates "$claude_file")
  return 1
}

# claude_md_import_candidates: emits one @-token candidate (without the
# leading @) per line, taken only from claude_file's actual prose — never
# from a fenced code block, an indented code block, or an inline code span.
#
# Prefers pandoc (a real, spec-conformant CommonMark parser) when it and jq
# are both on PATH AND actually succeed: `pandoc -t json` gives an AST where
# Code/CodeBlock are unambiguous node types, so prose_strs below can skip
# them outright instead of hand-rolling CommonMark's block/inline boundary
# rules (fence character, length and indentation; multi-line spans; an
# indented code block that cannot interrupt an already-open paragraph; ...)
# — rules that took several rounds of one-corner-at-a-time awk patches to
# even approximate. A present-but-broken pandoc (crashes, or emits something
# that isn't valid JSON on this input) must fall back too, not silently
# return nothing: checking `command -v` alone only proves the binary exists,
# not that it can parse this specific file.
#
# Falls back to the awk heuristic when pandoc is unavailable OR pandoc's own
# run failed. jq remains a prerequisite of this hook's JSON input/output; the
# fallback models fenced code (any character/length/
# indentation), inline spans (any delimiter length, single- or multi-line),
# and indented code blocks (any content, not just fence-shaped lines) using
# the same block-boundary rule pandoc applies: a 4+-space-indented line is
# code when it starts fresh (after a blank line, a just-closed fence, or
# start-of-document), and a lazy paragraph continuation otherwise, since
# indented code cannot interrupt an already-open paragraph. Blockquote/list
# container prefixes are stripped before applying the same state machine, so
# nested code is not mistaken for prose and list siblings do not get swallowed
# by a preceding list-item fence.
claude_md_import_candidates() {
  local claude_file="$1" pandoc_json
  if command -v pandoc >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if pandoc_json=$(pandoc -f commonmark -t json -- "$claude_file" 2>/dev/null) \
      && printf '%s' "$pandoc_json" | jq -e \
        'type == "object" and (.blocks | type == "array")' >/dev/null 2>&1; then
      printf '%s' "$pandoc_json" | jq -r '
        def prose_strs:
          if type == "object" then
            if (.t? == "Code") or (.t? == "CodeBlock") then
              empty
            elif .t? == "Str" then
              .c
            else
              (.[]? | prose_strs)
            end
          elif type == "array" then
            .[] | prose_strs
          else
            empty
          end;
        prose_strs
      ' 2>/dev/null | grep -oE '(^|[[:space:](])@[A-Za-z0-9._/~-]+' | sed -E 's/^.*@//'
      return
    fi
  fi
  awk_claude_md_import_candidates "$claude_file"
}

# Fallback used when pandoc is unavailable, or pandoc failed on this specific
# file. jq remains required by the hook's input/output transport — see the doc
# comment on claude_md_import_candidates above.
awk_claude_md_import_candidates() {
  local claude_file="$1"
  awk '
      BEGIN {
        prev_blank = 1
        in_indented_code = 0
        in_blockquote = 0
        fence_container_depth = 0
        fence_list_depth = 0
        fence_list_indent = -1
        container_base_columns = 0
      }

      # CommonMark indentation is measured in columns, with a tab advancing
      # to the next four-column tab stop. Counting a leading tab as one byte
      # would miss tab-indented code blocks and could leak @AGENTS.md into
      # prose. Use this for fence indentation and indented-code detection.
      function indent_columns(text,    i, char, columns) {
        columns = 0
        for (i = 1; i <= length(text); i++) {
          char = substr(text, i, 1)
          if (char == " ") {
            columns++
          } else if (char == "\t") {
            columns += 4 - (columns % 4)
          } else {
            break
          }
        }
        return columns
      }

      # Advance a column cursor across arbitrary text. Unlike
      # indent_columns(), this counts the blockquote marker itself so tabs
      # that follow a stripped container prefix keep their original tab-stop
      # position.
      function text_columns(text, start,    i, char, columns) {
        columns = start
        for (i = 1; i <= length(text); i++) {
          char = substr(text, i, 1)
          if (char == "\t") {
            columns += 4 - (columns % 4)
          } else {
            columns++
          }
        }
        return columns
      }

      # Convert only leading tabs in stripped content to spaces relative to
      # the original column cursor. For example, the tab in `> \t@` starts at
      # column 2 and advances to column 4, leaving two inner spaces—not four.
      function normalize_leading_tabs(text, base,    i, j, char, columns, width, result) {
        columns = base
        result = ""
        for (i = 1; i <= length(text); i++) {
          char = substr(text, i, 1)
          if (char == " ") {
            result = result char
            columns++
          } else if (char == "\t") {
            width = 4 - (columns % 4)
            for (j = 1; j <= width; j++) result = result " "
            columns += width
          } else {
            break
          }
        }
        return result substr(text, i)
      }

      # Strip a sequence of CommonMark blockquote and list containers from the
      # left, regardless of their nesting order (`> -`, `- >`, and deeper
      # combinations). A single optional space belongs to a marker; extra
      # padding remains meaningful inner indentation. The depth counters and
      # absolute column cursor are reused by fence matching below.
      function strip_container_prefixes(text,    rest, prefix, leading,
                                         marker_only, padding, marker_columns,
                                         padding_columns, consume_prefix) {
        container_depth = 0
        list_depth = 0
        first_list_indent = -1
        container_base_columns = 0
        rest = text
        while (1) {
          if (match(rest, /^[[:space:]]*>[[:space:]]/) ||
              match(rest, /^[[:space:]]*>/)) {
            prefix = substr(rest, RSTART, RLENGTH)
            leading = prefix
            sub(/>.*/, "", leading)
            if (indent_columns(leading) > 3) break
            container_base_columns = text_columns(prefix, container_base_columns)
            rest = substr(rest, RSTART + RLENGTH)
            container_depth++
            continue
          }
          if (match(rest, /^[[:space:]]*[-+*][[:space:]]+/) ||
              match(rest, /^[[:space:]]*[-+*]$/)) {
            prefix = substr(rest, RSTART, RLENGTH)
            leading = prefix
            sub(/[-+*].*/, "", leading)
          } else if (match(rest, /^[[:space:]]*[0-9]+[.)][[:space:]]+/) ||
                     match(rest, /^[[:space:]]*[0-9]+[.)]$/)) {
            prefix = substr(rest, RSTART, RLENGTH)
            leading = prefix
            sub(/[0-9]+[.)].*/, "", leading)
          } else {
            break
          }
          if (indent_columns(leading) > 3) break
          if (list_depth == 0) {
            first_list_indent = container_base_columns + indent_columns(leading)
          }
          marker_only = prefix
          sub(/[[:space:]]*$/, "", marker_only)
          padding = substr(prefix, length(marker_only) + 1)
          marker_columns = text_columns(marker_only, container_base_columns)
          padding_columns = text_columns(padding, marker_columns) - marker_columns
          consume_prefix = prefix
          if (padding_columns > 4) consume_prefix = marker_only substr(padding, 1, 1)
          rest = substr(rest, length(consume_prefix) + 1)
          container_base_columns = text_columns(consume_prefix, container_base_columns)
          rest = normalize_leading_tabs(rest, container_base_columns)
          list_depth++
        }
        return normalize_leading_tabs(rest, container_base_columns)
      }

      # Consume one non-fenced line after container prefixes were stripped.
      # Keeping this in a function lets a same-level list sibling that ends a
      # list-item fence be reprocessed as the Markdown line it really is,
      # instead of being lost inside the old fence action.
      function consume_nonfence_line(text,    is_blank, lead_ws, open_match,
                                     open_run, indent_len) {
        if (in_indented_code) {
          is_blank = (text ~ /^[[:space:]]*$/)
          if (is_blank) {
            prev_blank = 1
            return
          }
          lead_ws = text
          sub(/[^[:space:]].*/, "", lead_ws)
          if (indent_columns(lead_ws) >= 4) {
            prev_blank = 0
            return
          }
          in_indented_code = 0
        }
        if (match(text, /^[[:space:]]*(```+|~~~+)/)) {
          open_match = substr(text, RSTART, RLENGTH)
          open_run = open_match
          sub(/^[[:space:]]*/, "", open_run)
          indent_len = indent_columns(substr(open_match, 1, length(open_match) - length(open_run)))
          if (indent_len <= 3) {
            fence_char = substr(open_run, 1, 1)
            fence_len = length(open_run)
            fence_container_depth = container_depth
            fence_list_depth = list_depth
            fence_list_indent = list_depth > 0 ? first_list_indent : -1
            infence = 1
            prev_blank = 0
            return
          }
        }
        # Indented code block: ANY line (not just one shaped like a fence
        # marker) indented 4+ spaces is code when it starts fresh (previous
        # line blank, a just-closed fence, or start-of-document), same rule
        # CommonMark applies uniformly regardless of what the indented
        # content looks like. An indented code block cannot INTERRUPT an
        # already-open paragraph, so when the previous line was plain text
        # this over-indented line is a lazy paragraph continuation instead
        # and must stay in buf like any other prose line.
        is_blank = (text ~ /^[[:space:]]*$/)
        lead_ws = text
        sub(/[^[:space:]].*/, "", lead_ws)
        if (!is_blank && indent_columns(lead_ws) >= 4 && prev_blank) {
          in_indented_code = 1
          prev_blank = 0
          return
        }
        buf = buf text "\n"
        prev_blank = is_blank ? 1 : 0
      }

      {
        raw_line = $0
        parsed_line = strip_container_prefixes(raw_line)
        reprocess_nonfence_line = 0
        if (infence) {
          if (fence_list_depth > 0 && first_list_indent >= 0 &&
              (first_list_indent == fence_list_indent ||
               (fence_container_depth > 0 && first_list_indent > fence_list_indent))) {
            # A list marker at the opener level starts a sibling item; it is
            # not continuation content of a fence inside the previous item.
            infence = 0
            fence_container_depth = 0
            fence_list_depth = 0
            fence_list_indent = -1
            prev_blank = 1
            line = parsed_line
            reprocess_nonfence_line = 1
          } else if (container_depth == fence_container_depth &&
                     list_depth == fence_list_depth) {
            line = parsed_line
          } else {
            # A missing/deeper container marker inside a fence is literal
            # content. Keep the raw line so its backticks cannot close the
            # outer fence prematurely; an unprefixed closer is still checked
            # by the fence action using its own indentation.
            line = raw_line
          }
        } else {
          line = parsed_line
        }
        if (container_depth > 0) {
          in_blockquote = 1
        } else if (in_blockquote) {
          # An unquoted line ends the container. Preserve prev_blank so a
          # lazy paragraph continuation remains prose, but never let an
          # indented-code block from inside the quote swallow outside text.
          in_blockquote = 0
          in_indented_code = 0
        }
        if (reprocess_nonfence_line) {
          consume_nonfence_line(line)
          next
        }
      }

      # Fence state tracks the opening character (backtick or tilde) and its
      # run length: CommonMark only closes a fence with the SAME character
      # and a run at least as long as the opener, with nothing but trailing
      # whitespace after it. A line starting with a shorter or different run
      # (or with trailing content like a language tag) is not a closer, and
      # an unclosed fence correctly swallows the rest of the document.
      # CommonMark also caps indentation at 0-3 spaces for BOTH the opener
      # and the closer: 4+ spaces of leading whitespace is an indented code
      # block, not a fence delimiter, so it must not toggle fence state.
      !infence {
        # Consecutive 4+-space lines (and blank lines between them) remain in
        # the same indented code block. `prev_blank` only detects the opener;
        # without this state, a later line such as `    @AGENTS.md` leaks back
        # into buf and produces a false READY. A non-indented nonblank line
        # ends the block and is processed as normal Markdown below.
        consume_nonfence_line(line)
        next
      }
      infence {
        lead = line
        sub(/[^[:space:]].*/, "", lead)
        closer = line
        sub(/^[[:space:]]*/, "", closer)
        sub(/[[:space:]]*$/, "", closer)
        is_close = 0
        if (indent_columns(lead) <= 3) {
          if (fence_char == "`") {
            if (closer ~ /^```+$/ && length(closer) >= fence_len) is_close = 1
          } else {
            if (closer ~ /^~~~+$/ && length(closer) >= fence_len) is_close = 1
          }
        }
        # A closed fence ends whatever block came before it, same as a
        # blank line: the content right after starts fresh, so it is never
        # a "lazy continuation" of pre-fence prose even with no blank line
        # in between — an over-indented pseudo-fence line immediately after
        # this point must be excluded as its own indented code block, not
        # kept as literal text that could accidentally pair with another
        # backtick run later in the document.
        if (is_close) {
          infence = 0
          fence_container_depth = 0
          fence_list_depth = 0
          fence_list_indent = -1
          prev_blank = 1
        }
        next
      }

      # Runs once at EOF over the whole non-fenced document joined with real
      # newlines, not per line: CommonMark code spans can contain line
      # endings, so a closing backtick run on a LATER line still closes a
      # span opened on an earlier one. Per-line stripping would miss that
      # and let an import inside a multi-line span leak through as READY.
      END { print strip_spans(buf) }

      # Strips every valid inline code span (a backtick run, content, then
      # the next backtick run of the SAME length) regardless of how many
      # backticks the span uses. A backtick run whose matching close never
      # appears anywhere in the document is not a span and is left in place,
      # same as CommonMark.
      function strip_spans(line,    result, rest, n, delim, after, closepos) {
        result = ""
        rest = line
        while (match(rest, /`+/) > 0) {
          n = RLENGTH
          result = result substr(rest, 1, RSTART - 1)
          delim = substr(rest, RSTART, n)
          after = substr(rest, RSTART + n)
          closepos = find_close(after, n)
          if (closepos > 0) {
            rest = substr(after, closepos + n)
          } else {
            result = result delim
            rest = after
          }
        }
        return result rest
      }

      # Returns the 1-based start position in s of the first backtick run
      # whose length is exactly n, or 0 if there is none.
      function find_close(s, n,    r, pos, len) {
        r = s
        pos = 0
        while (match(r, /`+/) > 0) {
          len = RLENGTH
          if (len == n) return pos + RSTART
          pos = pos + RSTART + len - 1
          r = substr(r, RSTART + len)
        }
        return 0
      }
    ' "$claude_file" \
      | grep -oE '(^|[[:space:](])@[A-Za-z0-9._/~-]+' \
      | sed -E 's/^.*@//'
}

# compute_bridge_state: same state machine for the project root AND any
# nested scope, so a symlink or import is verified with the same rigor
# everywhere — a scope-level CLAUDE.md that merely exists (broken symlink,
# misdirected symlink) is not treated as "covered" just because the file is
# present. Prints "STATE<US>DETAIL" (ASCII unit separator) on stdout.
compute_bridge_state() {
  local dir="$1" agents_md claude_md state detail target
  agents_md="$dir/AGENTS.md"
  claude_md="$dir/CLAUDE.md"
  if [ -L "$claude_md" ] && [ ! -e "$claude_md" ]; then
    state="BROKEN_SYMLINK"
    target=$(readlink "$claude_md" 2>/dev/null || true)
    detail="CLAUDE.md is a symlink but its target does not exist (target: ${target:-unresolved})."
  elif [ -f "$agents_md" ]; then
    if [ -L "$claude_md" ]; then
      if [ "$claude_md" -ef "$agents_md" ]; then
        state="READY"
        detail=""
      else
        state="BROKEN_SYMLINK"
        target=$(readlink "$claude_md" 2>/dev/null || true)
        detail="CLAUDE.md is a symlink but points elsewhere, not at AGENTS.md (target: ${target:-unresolved})."
      fi
    elif [ -f "$claude_md" ]; then
      if claude_md_imports_agents "$claude_md" "$agents_md" "$dir"; then
        state="READY"
        detail=""
      else
        state="DIVERGED"
        detail="Both AGENTS.md and CLAUDE.md exist as separate files with no bridge (symlink or @path import); they can drift apart."
      fi
    else
      state="AGENTS_ONLY"
      detail="AGENTS.md exists but Claude Code will not read it on its own: bridge it with \`ln -s AGENTS.md CLAUDE.md\` or a CLAUDE.md that imports \`@AGENTS.md\`."
    fi
  elif [ -f "$claude_md" ] || [ -L "$claude_md" ]; then
    state="CLAUDE_ONLY"
    detail="CLAUDE.md exists without AGENTS.md. Fine for a Claude-only project; if other AI tools touch this repo, AGENTS.md is the portable canonical source."
  elif [ -f "$dir/README.md" ]; then
    state="LEGACY_README_ONLY"
    detail="A README.md exists but no AGENTS.md/CLAUDE.md: agent instructions are not distinguished from human-facing docs."
  else
    state="MISSING"
    detail="No AGENTS.md, CLAUDE.md, or README.md found here."
  fi
  printf '%s\x1f%s' "$state" "$detail"
}

BRIDGE_RESULT=$(compute_bridge_state "$CWD")
instructions_root_state="${BRIDGE_RESULT%%$'\x1f'*}"
instructions_root_detail="${BRIDGE_RESULT#*$'\x1f'}"

# Scoped-instruction candidates. Signals, any one of which marks a directory
# as a real, existing scope worth an agent's attention (never "every
# directory"): its own README.md; a package/module manifest living directly
# in it; a conventional test-suite directory name; or a Supabase Edge
# Function directory. Built from `git ls-files` instead of a filesystem walk
# so ignored/untracked trees (build output, node_modules, vendored code)
# never surface and there is no artificial depth limit to trip over.
#
# This is the expensive part of the check (a full repo listing), so it only
# runs at SessionStart, not on every UserPromptSubmit; the cheap root check
# above still runs every time.
scope_candidates=()
if [ "$EVENT" = "SessionStart" ] && git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  # Plain array membership check, not `declare -A`: macOS ships bash 3.2
  # (GPLv3), which has no associative arrays, and this hook must run under it.
  scope_candidate_in_list() {
    local needle="$1" item
    for item in "${scope_candidates[@]:-}"; do
      [ "$item" = "$needle" ] && return 0
    done
    return 1
  }
  add_scope_candidate() {
    local dir="$1" bridge state
    [ -z "$dir" ] || [ "$dir" = "." ] && return
    scope_candidate_in_list "$dir" && return
    # AGENTS.md is the policy-wide canon (root and every scope), so only a
    # working bridge (READY) stops a scope from being a candidate. CLAUDE_ONLY
    # is reported at the root instead of silenced, and a nested scope gets
    # the same treatment for the same reason: a CLAUDE.md with no AGENTS.md
    # is still worth surfacing, not just a broken/misdirected symlink or an
    # AGENTS.md with no bridge at all.
    bridge=$(compute_bridge_state "$CWD/$dir")
    state="${bridge%%$'\x1f'*}"
    case "$state" in
      READY) ;;
      *) scope_candidates+=("$dir") ;;
    esac
  }
  while IFS= read -r tracked_path; do
    dir=$(dirname "$tracked_path")
    base=$(basename "$tracked_path")
    dirbase=$(basename "$dir")
    case "$base" in
      README.md|package.json|pyproject.toml|go.mod|Cargo.toml|composer.json)
        add_scope_candidate "$dir" ;;
    esac
    case "$dirbase" in
      __tests__|tests|spec) add_scope_candidate "$dir" ;;
    esac
    case "$dir" in
      *supabase/functions/*)
        func_dir=$(printf '%s\n' "$dir" | sed -E 's#^(.*supabase/functions/[^/]+).*#\1#')
        add_scope_candidate "$func_dir"
        ;;
    esac
  done < <(git -C "$CWD" ls-files)
fi
scope_candidate_count=${#scope_candidates[@]}

# Repo hygiene (GitHub): default-branch protection (no force-push, no
# deletion, at least one required status check) plus delete_branch_on_merge.
# Owner-gated and read-only: it never calls a mutating GitHub endpoint, only
# reports state and the exact `gh` commands to fix it. Ownership was already
# verified above, before any project-local maintainability check ran. The
# protection request is the only remaining GitHub API call and runs only at
# SessionStart; UserPromptSubmit reuses the owner snapshot and stays network-free.
#
# The owner gate itself is `permissions.admin` on repos/<slug>, checked
# BEFORE the branches/<default>/protection call: a contributor without admin
# rights cannot change branch protection anyway, and the user explicitly
# asked that nothing about this check even run when they are not the owner
# ("si se detecta que no soy el dueño entonces no se realice"). NOT_APPLICABLE
# counts as healthy for the silent-exit condition below, so a non-owner
# working in someone else's repo sees no noise about it, ever.
repo_hygiene_state="NOT_APPLICABLE"
repo_hygiene_detail="$OWNER_NOT_APPLICABLE_REASON"
if [ "$EVENT" = "SessionStart" ] && [ "$OWNER_GATE_STATE" = "OWNER" ]; then
  DEFAULT_BRANCH=$(printf '%s' "$REPO_META" | jq -r '.default_branch // empty' 2>/dev/null || true)
  DELETE_ON_MERGE=$(printf '%s' "$REPO_META" | jq -r '.delete_branch_on_merge // false' 2>/dev/null || printf 'false')
  if [ -n "$DEFAULT_BRANCH" ]; then
    PROTECTION=$(gh_request api "repos/$REPO_SLUG/branches/$DEFAULT_BRANCH/protection" || true)
    hygiene_gaps=()
    printf '%s' "$PROTECTION" | jq -e '.allow_force_pushes.enabled == false' >/dev/null 2>&1 ||
      hygiene_gaps+=("$DEFAULT_BRANCH allows force-push")
    printf '%s' "$PROTECTION" | jq -e '.allow_deletions.enabled == false' >/dev/null 2>&1 ||
      hygiene_gaps+=("$DEFAULT_BRANCH allows deletion")
    printf '%s' "$PROTECTION" | jq -e '((.required_status_checks.contexts // []) | length) + ((.required_status_checks.checks // []) | length) > 0' >/dev/null 2>&1 ||
      hygiene_gaps+=("no required status check before merging into $DEFAULT_BRANCH")
    [ "$DELETE_ON_MERGE" = "true" ] ||
      hygiene_gaps+=("merged branches are not auto-deleted")
    if [ "${#hygiene_gaps[@]}" -eq 0 ]; then
      repo_hygiene_state="READY"
    else
      repo_hygiene_state="MISSING"
      repo_hygiene_detail=$(IFS='; '; printf '%s' "${hygiene_gaps[*]}")
    fi
  else
    repo_hygiene_state="UNAVAILABLE"
    repo_hygiene_detail="GitHub confirmed admin access but returned no default branch."
  fi
fi

scope_candidate_reason() {
  local dir="$1" bridge state detail
  bridge=$(compute_bridge_state "$CWD/$dir")
  state="${bridge%%$'\x1f'*}"
  detail="${bridge#*$'\x1f'}"
  case "$state" in
    MISSING|LEGACY_README_ONLY)
      # No bridge was attempted at all: fall back to the structural signal
      # that made this directory a candidate in the first place.
      [ -f "$CWD/$dir/README.md" ] && { printf 'README.md'; return; }
      case "$(basename "$dir")" in
        __tests__|tests|spec) printf 'test-suite directory'; return ;;
      esac
      case "$dir" in
        *supabase/functions/*) printf 'Supabase Edge Function'; return ;;
      esac
      for manifest in package.json pyproject.toml go.mod Cargo.toml composer.json; do
        [ -f "$CWD/$dir/$manifest" ] && { printf '%s' "$manifest"; return; }
      done
      printf 'detected scope'
      ;;
    *)
      # A bridge was attempted but is broken or incomplete (BROKEN_SYMLINK,
      # DIVERGED, AGENTS_ONLY): the precise reason is more useful here than
      # the generic structural signal.
      printf '%s' "$detail"
      ;;
  esac
}

# Healthy projects produce no context noise on every prompt.
if [ "$codegraph_state" = "READY" ] && [ "$codegraph_mcp_state" = "CONFIGURED" ] &&
  { [ "$codegraph_gitignore_state" = "CONFIGURED" ] || [ "$codegraph_gitignore_state" = "TRACKED_EXISTING" ] || [ "$codegraph_gitignore_state" = "NOT_APPLICABLE" ]; } &&
  { [ "$openspec_state" = "READY" ] || [ "$openspec_state" = "NOT_ENABLED" ]; } &&
  { [ "$openspec_gitignore_state" = "CONFIGURED" ] || [ "$openspec_gitignore_state" = "TRACKED_EXISTING" ] || [ "$openspec_gitignore_state" = "NOT_APPLICABLE" ]; } &&
  [ "$instructions_root_state" = "READY" ] &&
  { [ "$EVENT" != "SessionStart" ] || [ "$scope_candidate_count" -eq 0 ]; } &&
  { [ "$repo_hygiene_state" = "READY" ] || [ "$repo_hygiene_state" = "NOT_APPLICABLE" ]; }; then
  exit 0
fi

READY_CANDIDATES_LIST=""
if [ "$scope_candidate_count" -gt 0 ]; then
  shown=0
  for c in "${scope_candidates[@]}"; do
    [ "$shown" -ge 5 ] && break
    READY_CANDIDATES_LIST="${READY_CANDIDATES_LIST}  - ${c}/ ($(scope_candidate_reason "$c"))
"
    shown=$((shown + 1))
  done
  if [ "$scope_candidate_count" -gt 5 ]; then
    READY_CANDIDATES_LIST="${READY_CANDIDATES_LIST}  - (+$((scope_candidate_count - 5)) more)
"
  fi
fi

MESSAGE=$(cat <<EOF
PROJECT PREFLIGHT: project integrations are missing or incomplete in $CWD.

CodeGraph: $codegraph_state${codegraph_detail:+ — $codegraph_detail}
CodeGraph MCP: $codegraph_mcp_state${codegraph_mcp_detail:+ — $codegraph_mcp_detail}
CodeGraph .gitignore: $codegraph_gitignore_state${codegraph_gitignore_detail:+ — $codegraph_gitignore_detail}
OpenSpec: $openspec_state${openspec_detail:+ — $openspec_detail}
OpenSpec .gitignore: $openspec_gitignore_state${openspec_gitignore_detail:+ — $openspec_gitignore_detail}
Agent instructions (root): $instructions_root_state${instructions_root_detail:+ — $instructions_root_detail}
Scoped-instruction candidates (scanned at SessionStart only): ${scope_candidate_count} subdirectory(ies) with a README.md, package/module manifest, test-suite directory name, or Supabase function directory, and no working AGENTS.md/CLAUDE.md bridge (missing, broken, or AGENTS.md/CLAUDE.md only)
${READY_CANDIDATES_LIST}
Repo hygiene (GitHub, owner-only): $repo_hygiene_state${repo_hygiene_detail:+ — $repo_hygiene_detail}

Before exploring or modifying code, do not assume these integrations are available:
1. CodeGraph: if its MCP is missing, run \`codegraph install\`; then run \`codegraph init\` inside the project and verify with \`codegraph status --json\`.
2. Git: add ".codegraph/" to the project root ".gitignore" before continuing.
3. OpenSpec: install the CLI and run "openspec init" with explicit authorization; keep "openspec/" in ".gitignore" unless it was already tracked. Then verify with "openspec status --json".
4. Agent instructions (Claude Code only): AGENTS.md is the canonical file; CLAUDE.md is the bridge Claude Code actually reads (\`ln -s AGENTS.md CLAUDE.md\`, or a CLAUDE.md that imports \`@AGENTS.md\` anywhere outside code — inline spans and fenced blocks are both ignored). A README.md alone is not agent instructions. For root or per-scope gaps above, ask the user which scope(s) they actually want AGENTS.md for and whether the content differs meaningfully from the root instructions before creating anything — do not scaffold AGENTS.md/CLAUDE.md automatically, and do not create one in every listed directory by default.
5. Repo hygiene (GitHub): only checked when \`gh\` reports you as the repo's admin/owner; a contributor on someone else's repo sees NOT_APPLICABLE and nothing else. If MISSING, fix with explicit authorization: \`gh api --method PUT repos/<owner>/<repo>/branches/<default>/protection -F "required_status_checks[strict]=true" -F "required_status_checks[contexts][]=<job>" -F "enforce_admins=true" -F "required_pull_request_reviews=null" -F "restrictions=null" -F "allow_force_pushes=false" -F "allow_deletions=false"\` and \`gh api --method PATCH repos/<owner>/<repo> -F "delete_branch_on_merge=true"\`.

Do not run those commands silently: they can create project files or change shared repo settings. Ask for authorization or report the blocker. Do not claim that CodeGraph MCP, the index, the ".codegraph/" exclusion, OpenSpec, the "openspec/" exclusion, any AGENTS.md/CLAUDE.md bridge, or the GitHub branch protection/delete-on-merge settings work until you have that evidence. Configuration/documentation questions may continue without editing code.
EOF
)

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg event "$EVENT" --arg context "$MESSAGE" \
    '{hookSpecificOutput:{hookEventName:$event,additionalContext:$context}}'
else
  printf '%s\n' "$MESSAGE" >&2
fi

exit 0
