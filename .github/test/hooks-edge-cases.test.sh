#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK_ROOT="${HOOK_ROOT:-$ROOT/config/claude}"
QA="$HOOK_ROOT/hooks/qa-checklist.sh"
GAUNTLET="$HOOK_ROOT/hooks/gauntlet-stop.sh"
HANDOFF_START="$HOOK_ROOT/hooks/handoff-session-start.py"
HANDOFF_STOP="$HOOK_ROOT/hooks/handoff-stop.sh"
PENDING="$HOOK_ROOT/hooks/stop-check-pending.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hooks-edge-cases.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT

PROJECT="$TMP/repo with spaces"
mkdir -p "$PROJECT/src" "$PROJECT/tests" "$PROJECT/.claude"
git -C "$PROJECT" init -q
git -C "$PROJECT" config user.email hooks@example.invalid
git -C "$PROJECT" config user.name hooks-edge-cases
printf '%s\n' 'print("normal CLI output")' >"$PROJECT/src/cli tool.py"
printf '%s\n' 'test' >"$PROJECT/tests/cli tool_test.py"
git -C "$PROJECT" add .
git -C "$PROJECT" commit -qm initial
EXPECTED_ROOT=$(git -C "$PROJECT" rev-parse --show-toplevel)

payload() {
  jq -nc --arg cwd "$PROJECT" --arg session "$1" --arg transcript "$TMP/transcript" \
    '{hook_event_name:"Stop",cwd:$cwd,session_id:$session,transcript_path:$transcript}'
}

printf '%s\n' '== hooks honor payload cwd and preserve paths with spaces'
printf '%s\n' 'print("normal CLI output")' >>"$PROJECT/src/cli tool.py"
qa_output=$(cd /tmp && payload qa-space | bash "$QA" 2>&1)
[ -z "$qa_output" ] || { printf '%s\\n' "$qa_output" >&2; exit 1; }

printf '%s\n' 'breakpoint()' >>"$PROJECT/src/cli tool.py"
qa_output=$(cd /tmp && payload qa-debug | bash "$QA" 2>&1)
printf '%s' "$qa_output" | grep -Fq '[qa-checklist] Debug statements detected:'
printf '%s' "$qa_output" | grep -Fq 'src/cli tool.py'
if printf '%s' "$qa_output" | grep -Fq 'src/cli'; then
  printf '%s' "$qa_output" | grep -Fq 'src/cli tool.py' || exit 1
fi

gauntlet_output=$(cd /tmp && payload gauntlet-space | CLAUDE_SKIP_TEST_RUN=1 bash "$GAUNTLET" 2>&1)
[ -z "$gauntlet_output" ] || { printf '%s\n' "$gauntlet_output" >&2; exit 1; }

printf '%s\n' '== handoff archives never overwrite prior handoffs'
printf '%s\n' 'old archive' >"$PROJECT/HANDOFF.md.archived"
printf '%s\n' 'first handoff' >"$PROJECT/HANDOFF.md"
handoff_output=$(cd /tmp && payload handoff-1 | /usr/bin/python3 "$HANDOFF_START")
printf '%s' "$handoff_output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null
[ "$(cat "$PROJECT/HANDOFF.md.archived")" = 'old archive' ]
printf '%s\n' 'second handoff' >"$PROJECT/HANDOFF.md"
handoff_output=$(cd /tmp && payload handoff-2 | /usr/bin/python3 "$HANDOFF_START")
printf '%s' "$handoff_output" | jq -e '.hookSpecificOutput.additionalContext | contains("second handoff")' >/dev/null
[ "$(cat "$PROJECT/HANDOFF.md.archived")" = 'old archive' ]
archive_count=$(find "$PROJECT" -maxdepth 1 -type f -name 'HANDOFF.md.archived.*' | wc -l | tr -d ' ')
[ "$archive_count" -eq 2 ]
grep -R -Fq 'first handoff' "$PROJECT"/HANDOFF.md.archived.*
grep -R -Fq 'second handoff' "$PROJECT"/HANDOFF.md.archived.*

printf '%s\n' '== stop hooks use project cwd from payload'
rm -f "$PROJECT/HANDOFF.md" "$PROJECT"/HANDOFF.md.archived.*
head -c 200001 /dev/zero >"$TMP/transcript"
printf '%s\n' 'existing handoff' >"$PROJECT/HANDOFF.md"
rm -f "${TMPDIR:-/tmp}/claude-handoff-hint-handoff-existing-$$" "${TMPDIR:-/tmp}/claude-handoff-hint-handoff-needed-$$"
handoff_hint=$(cd /tmp && payload handoff-existing-$$ | bash "$HANDOFF_STOP" 2>&1)
[ -z "$handoff_hint" ]
rm -f "$PROJECT/HANDOFF.md"
handoff_hint=$(cd /tmp && payload handoff-needed-$$ | bash "$HANDOFF_STOP" 2>&1)
printf '%s' "$handoff_hint" | grep -Fq 'Run /handoff'

printf '%s\n' 'pending' >>"$PROJECT/src/cli tool.py"
pending_output=$(cd /tmp && payload pending-$$ | bash "$PENDING" 2>&1)
printf '%s' "$pending_output" | grep -Fq "PENDING CHANGES in $EXPECTED_ROOT:"

printf '%s\n' 'PASS: hook edge cases for payload cwd, path safety, debug detection, and handoff archival'
