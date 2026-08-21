#!/usr/bin/env bash
# Runner local del gate para el instalador y wrappers de shell. No se versiona:
# este repo instala configuracion y no debe copiar sus pruebas al HOME.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALL="$ROOT/install.sh"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"

cleanup() {
  rm -rf -- "$TMP_HOME"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_directory() {
  [ -d "$1" ] || fail "expected directory: $1"
}

assert_not_symlink() {
  [ ! -L "$1" ] || fail "expected independent copy, got symlink: $1"
}

assert_not_exists() {
  [ ! -e "$1" ] || [ -L "$1" ] || fail "expected path to stay undeployed: $1"
}

assert_equal() {
  cmp -s -- "$1" "$2" || fail "files differ: $1 vs $2"
}

printf '%s\n' '== install.sh syntax =='
bash -n "$INSTALL"

printf '%s\n' '== install.sh shellcheck =='
shellcheck "$INSTALL"

printf '%s\n' '== install.sh rejects unknown arguments =='
INVALID_HOME="$TMP_HOME/invalid-home"
mkdir -p "$INVALID_HOME"
set +e
HOME="$INVALID_HOME" bash "$INSTALL" --dryrun >"$TMP_HOME/invalid.log" 2>&1
invalid_rc=$?
set -e
[ "$invalid_rc" -eq 2 ] || fail "unknown argument returned $invalid_rc instead of 2"
assert_not_exists "$INVALID_HOME/.zshrc"

printf '%s\n' '== install.sh fails closed on incomplete checkout =='
INCOMPLETE_ROOT="$TMP_HOME/incomplete-repo"
INCOMPLETE_HOME="$TMP_HOME/incomplete-home"
mkdir -p "$INCOMPLETE_ROOT" "$INCOMPLETE_HOME"
cp "$INSTALL" "$INCOMPLETE_ROOT/install.sh"
set +e
HOME="$INCOMPLETE_HOME" bash "$INCOMPLETE_ROOT/install.sh" >"$TMP_HOME/incomplete.log" 2>&1
incomplete_rc=$?
set -e
[ "$incomplete_rc" -eq 1 ] || fail "incomplete checkout returned $incomplete_rc instead of 1"
assert_not_exists "$INCOMPLETE_HOME/.zshrc"

TEST_HOME="$TMP_HOME/home"
mkdir -p -- \
  "$TEST_HOME/.config/ghostty" \
  "$TEST_HOME/.claude" \
  "$TEST_HOME/.claude/hooks" \
  "$TEST_HOME/.claude/skills/pptx/node_modules"

# Symlinks managed by an earlier installer version must migrate to copies.
ln -s -- "$ROOT/.zshrc" "$TEST_HOME/.zshrc"
ln -s -- "$ROOT/config/claude/agents" "$TEST_HOME/.claude/agents"

# Conflicting local files must be backed up before replacement.
printf '%s\n' 'local zprofile' >"$TEST_HOME/.zprofile"
printf '%s\n' 'local Claude instructions' >"$TEST_HOME/.claude/CLAUDE.md"

# A stale file under a managed directory must be removed by rsync --delete.
printf '%s\n' 'stale managed file' >"$TEST_HOME/.config/ghostty/stale.conf"
printf '%s\n' 'local Ghostty config' >"$TEST_HOME/.config/ghostty/config.ghostty"

# User-local state outside the managed set must survive installation.
printf '%s\n' 'local identity' >"$TEST_HOME/.gitconfig.local"
printf '%s\n' 'unmanaged marker' >"$TEST_HOME/local-marker"
printf '%s\n' 'runtime dependency' >"$TEST_HOME/.claude/skills/pptx/node_modules/.keep"
printf '%s\n' 'runtime rollback' >"$TEST_HOME/.claude/hooks/example.sh.backup.20260821000000"

printf '%s\n' '== isolated installation =='
HOME="$TEST_HOME" bash "$INSTALL" >"$TMP_HOME/install.log"

printf '%s\n' '== independent copies =='
assert_file "$TEST_HOME/.zshrc"
assert_not_symlink "$TEST_HOME/.zshrc"
assert_equal "$ROOT/.zshrc" "$TEST_HOME/.zshrc"
assert_directory "$TEST_HOME/.claude/agents"
assert_not_symlink "$TEST_HOME/.claude/agents"
assert_file "$TEST_HOME/.claude/agents/backend-architect.md"
assert_file "$TEST_HOME/.config/ghostty/config.ghostty"
assert_not_symlink "$TEST_HOME/.config/ghostty"
assert_not_exists "$TEST_HOME/.claude/hooks/automatic-workflow-stop.test.sh"
assert_not_exists "$TEST_HOME/.claude/scripts/check-runtime-parity.test.sh"

printf '%s\n' '== symlink migration and backups =='
assert_file "$TEST_HOME/.zprofile"
assert_not_symlink "$TEST_HOME/.zprofile"
assert_equal "$ROOT/.zprofile" "$TEST_HOME/.zprofile"
assert_file "$TEST_HOME/.claude/CLAUDE.md"
assert_not_symlink "$TEST_HOME/.claude/CLAUDE.md"
assert_equal "$ROOT/config/claude/CLAUDE.md" "$TEST_HOME/.claude/CLAUDE.md"

zprofile_backup=$(find "$TEST_HOME" -maxdepth 1 -name '.zprofile.backup.*' -type f -print -quit)
[ -n "$zprofile_backup" ] || fail 'missing .zprofile backup'
grep -qxF 'local zprofile' "$zprofile_backup" || fail 'wrong .zprofile backup content'

claude_backup=$(find "$TEST_HOME/.claude" -maxdepth 1 -name 'CLAUDE.md.backup.*' -type f -print -quit)
[ -n "$claude_backup" ] || fail 'missing Claude instructions backup'
grep -qxF 'local Claude instructions' "$claude_backup" || fail 'wrong Claude backup content'

printf '%s\n' '== managed cleanup and local preservation =='
[ ! -e "$TEST_HOME/.config/ghostty/stale.conf" ] || fail 'stale managed file survived'
stale_backup=$(find "$TEST_HOME/.dotfiles-backups" -path '*/.config/ghostty/stale.conf' -type f -print -quit)
[ -n "$stale_backup" ] || fail 'deleted managed file was not backed up'
grep -qxF 'stale managed file' "$stale_backup" || fail 'wrong deleted-file backup content'
ghostty_backup=$(find "$TEST_HOME/.dotfiles-backups" -path '*/.config/ghostty/config.ghostty' -type f -print -quit)
[ -n "$ghostty_backup" ] || fail 'replaced managed file was not backed up'
grep -qxF 'local Ghostty config' "$ghostty_backup" || fail 'wrong replaced-file backup content'
assert_file "$TEST_HOME/.gitconfig.local"
grep -qxF 'local identity' "$TEST_HOME/.gitconfig.local" || fail 'local git identity changed'
assert_file "$TEST_HOME/local-marker"
grep -qxF 'unmanaged marker' "$TEST_HOME/local-marker" || fail 'unmanaged local file changed'
assert_file "$TEST_HOME/.claude/skills/pptx/node_modules/.keep"
grep -qxF 'runtime dependency' "$TEST_HOME/.claude/skills/pptx/node_modules/.keep" || fail 'runtime node_modules changed'
assert_file "$TEST_HOME/.claude/hooks/example.sh.backup.20260821000000"
grep -qxF 'runtime rollback' "$TEST_HOME/.claude/hooks/example.sh.backup.20260821000000" || fail 'runtime backup changed'

printf '%s\n' '== idempotent reinstall =='
HOME="$TEST_HOME" bash "$INSTALL" >"$TMP_HOME/reinstall.log"
if grep -q '  BACKUP ' "$TMP_HOME/reinstall.log"; then
  fail 'idempotent reinstall created a new backup'
fi

printf '%s\n' 'PASS: install.sh syntax, shellcheck, isolated install, symlink migration, backups, cleanup, and local preservation'

printf '%s\n' '== Claude provider wrapper =='
WRAPPER_HOME="$TMP_HOME/wrapper-home"
WRAPPER_BIN="$TMP_HOME/wrapper-bin"
mkdir -p "$WRAPPER_HOME/.claude" "$WRAPPER_BIN"
for overlay in deepseek glm kimi minimax openrouter ollama qwen; do
  printf '{}\n' >"$WRAPPER_HOME/.claude/$overlay.settings.json"
done
cat >"$WRAPPER_BIN/claude" <<'EOF'
#!/usr/bin/env bash
printf 'base_url=%s\n' "${ANTHROPIC_BASE_URL-unset}"
printf 'args='; printf '<%s>' "$@"; printf '\n'
EOF
chmod +x "$WRAPPER_BIN/claude"

WRAPPER_FUNCTION="$TMP_HOME/claude-wrapper.zsh"
sed -n '/^claude() {/,/^}/p' "$ROOT/.zshrc" >"$WRAPPER_FUNCTION"

wrapper_output=$(HOME="$WRAPPER_HOME" PATH="$WRAPPER_BIN:$PATH" ANTHROPIC_BASE_URL='https://stale.invalid' \
  zsh -f -c 'source "$1"; claude --deepseek -p hola' zsh "$WRAPPER_FUNCTION")
printf '%s' "$wrapper_output" | grep -qxF 'base_url=unset'
printf '%s' "$wrapper_output" | grep -qxF "args=<--settings><$WRAPPER_HOME/.claude/deepseek.settings.json><-p><hola>"

set +e
wrapper_error=$(HOME="$WRAPPER_HOME" PATH="$WRAPPER_BIN:$PATH" \
  zsh -f -c 'source "$1"; claude --deepseek --glm -p hola' zsh "$WRAPPER_FUNCTION" 2>&1)
wrapper_rc=$?
set -e
[ "$wrapper_rc" -eq 2 ] || fail "multiple providers returned $wrapper_rc instead of 2"
printf '%s' "$wrapper_error" | grep -qxF 'claude: selecciona un solo provider por invocacion'

printf '%s\n' 'PASS: Claude wrapper isolates provider env, routes one overlay, and rejects ambiguous provider flags'
