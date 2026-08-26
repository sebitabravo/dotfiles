#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
SCRIPT="$ROOT/.github/test/doctor.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-test.XXXXXX")
HOME_DIR="$TMP/home"
RUNTIME="$HOME_DIR/.claude"
REPO="$TMP/repo"
BIN="$TMP/bin"
OUTPUT="$TMP/doctor.log"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p \
  "$RUNTIME" \
  "$HOME_DIR/.config/herdr" \
  "$REPO/config/herdr" \
  "$BIN"

# The current WIP may keep the parity helpers under .github/test instead of
# config/claude/scripts. The doctor discovers either location, while these
# fixtures exercise the same source/runtime contract.
for relative in \
  hooks/activate-convergence-on-apply.sh \
  hooks/automatic-workflow.sh \
  hooks/automatic-workflow-stop.sh \
  hooks/secret-detect.sh \
  hooks/convergence-stop.sh \
  hooks/compact-resume.py \
  hooks/lib/test-runner.sh \
  hooks/lib/automatic-workflow-state.sh \
  hooks/task-contract.sh \
  scripts/convergence-start.sh \
  scripts/validate-task-roadmap.py \
  skills/automatic-task-orchestrator/SKILL.md \
  settings.json; do
  mkdir -p "$RUNTIME/$(dirname "$relative")"
  cp -p "$ROOT/config/claude/$relative" "$RUNTIME/$relative"
done

for overlay in \
  deepseek.settings.json \
  glm.settings.json \
  ollama.settings.json \
  openrouter.settings.json; do
  cp -p "$ROOT/config/claude/$overlay" "$RUNTIME/$overlay"
done

cp -p "$ROOT/config/herdr/config.toml" "$REPO/config/herdr/config.toml"
cp -p "$ROOT/config/herdr/config.toml" "$HOME_DIR/.config/herdr/config.toml"
cp -p "$ROOT/config/claude/mcp-servers.json" "$RUNTIME/mcp-servers.json"

# Claude's user-scope config may contain runtime-only fields such as env; the
# doctor must compare managed MCP fields without requiring byte-for-byte JSON.
jq '.mcpServers.playwright.env = {}' \
  "$ROOT/config/claude/mcp-servers.json" >"$HOME_DIR/.claude.json"
chmod 600 "$HOME_DIR/.claude.json"

cat >"$BIN/claude" <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "--version ") printf '%s\n' '2.1.234 (Claude Code)' ;;
  "mcp list")
    cat <<'MCP'
codegraph: codegraph serve --mcp - ✔ Connected
context7: https://mcp.context7.com/mcp (HTTP) - ✔ Connected
playwright: npx @playwright/mcp@latest - ✔ Connected
plugin:engram:engram: engram mcp --tools=agent - ✔ Connected
MCP
    ;;
  *) exit 2 ;;
esac
EOF

cat >"$BIN/herdr" <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "--version ") printf '%s\n' 'herdr 0.8.2' ;;
  "config check") [ -f "${HERDR_CONFIG_PATH:?}" ] && printf '%s\n' 'config: ok' ;;
  "status ") printf '%s\n' 'server: running' ;;
  *) exit 2 ;;
esac
EOF

cat >"$BIN/engram" <<'EOF'
#!/usr/bin/env bash
[ "$1" = '--version' ] && printf '%s\n' 'engram 1.19.0'
EOF

cat >"$BIN/codegraph" <<'EOF'
#!/usr/bin/env bash
[ "$1" = '--version' ] && printf '%s\n' '1.5.0'
EOF

chmod +x "$BIN/claude" "$BIN/herdr" "$BIN/engram" "$BIN/codegraph"

before_user=$(shasum -a 256 "$HOME_DIR/.claude.json" | awk '{print $1}')
before_herdr=$(shasum -a 256 "$HOME_DIR/.config/herdr/config.toml" | awk '{print $1}')

if ! HOME="$HOME_DIR" PATH="$BIN:$PATH" \
  DOCTOR_CLAUDE_RUNTIME_ROOT="$RUNTIME" \
  DOCTOR_CLAUDE_USER_CONFIG="$HOME_DIR/.claude.json" \
  DOCTOR_HERDR_RUNTIME_CONFIG="$HOME_DIR/.config/herdr/config.toml" \
  bash "$SCRIPT" >"$OUTPUT" 2>&1; then
  cat "$OUTPUT" >&2
  fail 'doctor fixture should pass'
fi

grep -q 'DOCTOR PASS' "$OUTPUT" || fail 'doctor did not report PASS'
grep -q 'Herdr config parity' "$OUTPUT" || fail 'doctor omitted Herdr parity'
grep -q 'Engram' "$OUTPUT" || fail 'doctor omitted Engram'
grep -q 'Claude harness parity' "$OUTPUT" || fail 'doctor omitted Claude parity'
grep -q 'Claude provider parity' "$OUTPUT" || fail 'doctor omitted provider parity'

[ "$before_user" = "$(shasum -a 256 "$HOME_DIR/.claude.json" | awk '{print $1}')" ] \
  || fail 'doctor modified Claude user config'
[ "$before_herdr" = "$(shasum -a 256 "$HOME_DIR/.config/herdr/config.toml" | awk '{print $1}')" ] \
  || fail 'doctor modified Herdr config'

# A managed MCP drift must fail, while the extra runtime-only env object remains
# accepted by the semantic comparison.
jq '.mcpServers.context7.url = "https://mcp.invalid/mcp"' \
  "$HOME_DIR/.claude.json" >"$HOME_DIR/.claude.json.tmp"
mv "$HOME_DIR/.claude.json.tmp" "$HOME_DIR/.claude.json"
chmod 600 "$HOME_DIR/.claude.json"

set +e
HOME="$HOME_DIR" PATH="$BIN:$PATH" \
  DOCTOR_CLAUDE_SOURCE_ROOT="$ROOT/config/claude" \
  DOCTOR_REPO_ROOT="$ROOT" \
  DOCTOR_HERDR_SOURCE="$REPO/config/herdr/config.toml" \
  DOCTOR_CLAUDE_RUNTIME_ROOT="$RUNTIME" \
  DOCTOR_CLAUDE_USER_CONFIG="$HOME_DIR/.claude.json" \
  DOCTOR_HERDR_RUNTIME_CONFIG="$HOME_DIR/.config/herdr/config.toml" \
  bash "$SCRIPT" >"$TMP/drift.log" 2>&1
drift_rc=$?
set -e
[ "$drift_rc" -eq 1 ] || fail "doctor drift returned $drift_rc instead of 1"
grep -q 'definición administrada difiere' "$TMP/drift.log" \
  || fail 'doctor did not report MCP drift'

printf '%s\n' 'PASS: doctor read-only validates MCP, Claude, Herdr, Engram, permissions, parity, binaries, and drift'
