#!/usr/bin/env bash
# Gate del instalador, los wrappers de shell y las suites de hooks/scripts.
# Se versiona y corre en CI (.github/workflows/) porque, a diferencia de las
# suites bajo .github/test/, install.sh no copia nada de .github/ a ningun
# HOME -- no hay riesgo de que esto llegue al runtime de quien instala.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALL="$ROOT/install.sh"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"

# Fixture real para el --exclude='*.test.sh' de install.sh: ahora que ningun
# directorio administrado tiene sus propias suites, sin esto la aserción de
# mas abajo sería tautológica (nada que copiar, con o sin el exclude). Vive
# en el hooks/ real del repo -- copy_dir() no acepta una fuente alternativa
# -- y el trap la borra pase lo que pase.
# Each QA run gets its own excluded fixture. A fixed path let concurrent hook
# or manual runs delete/replace one another's source file while install.sh was
# between its first install and idempotence check.
EXCLUDE_FIXTURE_SEED="$(mktemp "$ROOT/config/claude/hooks/__ci_exclude_fixture.XXXXXX")"
EXCLUDE_FIXTURE="$EXCLUDE_FIXTURE_SEED.test.sh"
EXCLUDE_FIXTURE_NAME="$(basename -- "$EXCLUDE_FIXTURE")"
mv -- "$EXCLUDE_FIXTURE_SEED" "$EXCLUDE_FIXTURE"

cleanup() {
  rm -rf -- "$TMP_HOME" || true
  rm -f -- "$EXCLUDE_FIXTURE" || true
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

TEST_ONLY_CLAUDE_SCRIPTS=(
  check-provider-runtime-parity.sh
  check-runtime-parity.sh
  check-skill-deps.sh
  compare-task-roadmaps.sh
  doctor.sh
  smoke-automatic-workflow.sh
  smoke-claude-hook-engine.sh
  validate.sh
)

printf '%s\n' '== install.sh syntax =='
bash -n "$INSTALL"

printf '%s\n' '== install.sh shellcheck =='
shellcheck "$INSTALL"

printf '%s\n' '== install.sh default bootstrap and dry-run avoid real installers =='
TOOL_DRY_HOME="$TMP_HOME/tool-dry-home"
TOOL_DRY_BIN="$TMP_HOME/tool-dry-bin"
TOOL_DRY_LOG="$TMP_HOME/tool-dry-network.log"
mkdir -p "$TOOL_DRY_HOME" "$TOOL_DRY_BIN"
for command_name in curl git; do
  cat >"$TOOL_DRY_BIN/$command_name" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >>"$TOOL_DRY_LOG"
exit 99
EOF
  chmod +x "$TOOL_DRY_BIN/$command_name"
done
cat >"$TOOL_DRY_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${DOTFILES_TEST_UNAME:-Darwin}"
EOF
chmod +x "$TOOL_DRY_BIN/uname"
cat >"$TOOL_DRY_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '--print-path' ]; then
  exit 1
fi
printf '%s\n' "$0 $*" >>"$TOOL_DRY_LOG"
exit 99
EOF
chmod +x "$TOOL_DRY_BIN/xcode-select"

: >"$TOOL_DRY_LOG"
# PATH omite herramientas de usuario y HOME es aislado; los stubs convierten
# cualquier descarga o clone accidental en una falla determinista.
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TOOL_DRY_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TOOL_DRY_HOME/no-brew" \
  PATH="$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" --dry-run >"$TMP_HOME/tool-dry.log"
tool_dry_output="$TMP_HOME/tool-dry.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'dry-run invoked a network or clone command'
assert_not_exists "$TOOL_DRY_HOME/.zshrc"
assert_not_exists "$TOOL_DRY_HOME/.oh-my-zsh"
grep -qF 'https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh' "$tool_dry_output" || fail 'Oh My Zsh plan missing'
grep -qF 'https://github.com/romkatv/powerlevel10k.git' "$tool_dry_output" || fail 'Powerlevel10k plan missing'
grep -qF 'https://kilo.ai/cli/install' "$tool_dry_output" || fail 'Kilo plan missing'
grep -qF 'https://cursor.com/install' "$tool_dry_output" || fail 'Cursor Agent plan missing'
grep -qF 'https://antigravity.google/cli/install.sh' "$tool_dry_output" || fail 'Antigravity plan missing'
grep -qF 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' "$tool_dry_output" || fail 'Homebrew plan missing'
grep -qF 'xcode-select --install' "$tool_dry_output" || fail 'Xcode Command Line Tools plan missing'
grep -qF 'OpenCode' "$tool_dry_output" || fail 'OpenCode plan missing'
grep -qF -- '--no-modify-path' "$tool_dry_output" || fail 'no-modify-path plan missing'
tools_line=$(grep -n '^herramientas de shell y agentes$' "$tool_dry_output" | cut -d: -f1)
shell_line=$(grep -n '^shell$' "$tool_dry_output" | cut -d: -f1)
[ "$tools_line" -lt "$shell_line" ] || fail 'tool installers were not planned before managed shell files'

printf '%s\n' '== install.sh skips existing Homebrew and Apple tools =='
printf '%s\n' '#!/usr/bin/env bash' >"$TOOL_DRY_HOME/brew"
chmod +x "$TOOL_DRY_HOME/brew"
cat >"$TOOL_DRY_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '--print-path' ]; then
  printf '%s\n' '/Library/Developer/CommandLineTools'
  exit 0
fi
printf '%s\n' "$0 $*" >>"$TOOL_DRY_LOG"
exit 99
EOF
chmod +x "$TOOL_DRY_BIN/xcode-select"
: >"$TOOL_DRY_LOG"
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TOOL_DRY_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TOOL_DRY_HOME/brew" \
  PATH="$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" --dry-run >"$TMP_HOME/tool-system-existing.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'existing system tool check invoked a mutating command'
grep -qF 'SKIP   Homebrew (ya existe brew)' "$TMP_HOME/tool-system-existing.log" || fail 'existing Homebrew was not skipped'
grep -qF 'SKIP   Apple Command Line Tools (ya existe)' "$TMP_HOME/tool-system-existing.log" || fail 'existing Apple tools were not skipped'

printf '%s\n' '== install.sh skips known user-local CLI locations =='
mkdir -p "$TOOL_DRY_HOME/.opencode/bin" "$TOOL_DRY_HOME/.kilo/bin"
for command_name in opencode kilo; do
  printf '%s\n' '#!/usr/bin/env bash' >"$TOOL_DRY_HOME/.${command_name}/bin/$command_name"
  chmod +x "$TOOL_DRY_HOME/.${command_name}/bin/$command_name"
done
: >"$TOOL_DRY_LOG"
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TOOL_DRY_HOME" \
  PATH="$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" --dry-run >"$TMP_HOME/tool-local-cli.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'known local CLI check invoked a network or clone command'
grep -qF 'SKIP   OpenCode (ya existe opencode)' "$TMP_HOME/tool-local-cli.log" || fail 'OpenCode local binary was not skipped'
grep -qF 'SKIP   Kilo Code (ya existe kilo)' "$TMP_HOME/tool-local-cli.log" || fail 'Kilo local binary was not skipped'

printf '%s\n' '== install.sh rejects unknown arguments =='
INVALID_HOME="$TMP_HOME/invalid-home"
mkdir -p "$INVALID_HOME"
REMOVED_TOOL_FLAG="--install-"'tools'
for argument in --dryrun "$REMOVED_TOOL_FLAG"; do
  set +e
  HOME="$INVALID_HOME" bash "$INSTALL" "$argument" >"$TMP_HOME/invalid-$(printf '%s' "$argument" | tr -cd '[:alnum:]').log" 2>&1
  invalid_rc=$?
  set -e
  [ "$invalid_rc" -eq 2 ] || fail "unknown argument $argument returned $invalid_rc instead of 2"
done
assert_not_exists "$INVALID_HOME/.zshrc"

printf '%s\n' '== install.sh fails closed before work on non-macOS =='
NON_MAC_HOME="$TMP_HOME/non-mac-home"
mkdir -p "$NON_MAC_HOME"
: >"$TOOL_DRY_LOG"
set +e
DOTFILES_TEST_UNAME=Linux TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$NON_MAC_HOME" \
  PATH="$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/non-mac.log" 2>&1
non_mac_rc=$?
set -e
[ "$non_mac_rc" -eq 1 ] || fail "non-macOS bootstrap returned $non_mac_rc instead of 1"
grep -qF 'bootstrap solo es compatible con macOS' "$TMP_HOME/non-mac.log" || fail 'non-macOS error missing'
[ ! -s "$TOOL_DRY_LOG" ] || fail 'non-macOS bootstrap invoked an installer or download'
assert_not_exists "$NON_MAC_HOME/.zshrc"

printf '%s\n' '== install.sh stops for missing Apple Command Line Tools =='
MISSING_CLT_HOME="$TMP_HOME/missing-clt-home"
mkdir -p "$MISSING_CLT_HOME"
cat >"$TOOL_DRY_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = '--print-path' ]; then
  exit 1
fi
printf '%s\n' "$0 $*" >>"$TOOL_DRY_LOG"
[ "${1:-}" = '--install' ] && exit 0
exit 99
EOF
chmod +x "$TOOL_DRY_BIN/xcode-select"
: >"$TOOL_DRY_LOG"
set +e
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$MISSING_CLT_HOME" \
  PATH="$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/missing-clt.log" 2>&1
missing_clt_rc=$?
set -e
[ "$missing_clt_rc" -eq 1 ] || fail "missing CLT bootstrap returned $missing_clt_rc instead of 1"
grep -qF 'xcode-select --install' "$TOOL_DRY_LOG" || fail 'missing CLT did not request xcode-select --install'
grep -qF 'volve a ejecutar ./install.sh' "$TMP_HOME/missing-clt.log" || fail 'missing CLT rerun instruction missing'
assert_not_exists "$MISSING_CLT_HOME/.zshrc"

printf '%s\n' '== install.sh completes source preflight before prerequisites =='
INCOMPLETE_ROOT="$TMP_HOME/incomplete-repo"
INCOMPLETE_HOME="$TMP_HOME/incomplete-home"
PREFLIGHT_BIN="$TMP_HOME/preflight-bin"
PREFLIGHT_LOG="$TMP_HOME/preflight.log"
mkdir -p "$INCOMPLETE_ROOT" "$INCOMPLETE_HOME" "$PREFLIGHT_BIN"
cp "$INSTALL" "$INCOMPLETE_ROOT/install.sh"
cat >"$PREFLIGHT_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' Darwin
EOF
cat >"$PREFLIGHT_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >>"$PREFLIGHT_LOG"
[ "${1:-}" = '--print-path' ] && exit 0
exit 99
EOF
chmod +x "$PREFLIGHT_BIN/uname" "$PREFLIGHT_BIN/xcode-select"
: >"$PREFLIGHT_LOG"
: >"$TOOL_DRY_LOG"
set +e
PREFLIGHT_LOG="$PREFLIGHT_LOG" TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$INCOMPLETE_HOME" \
  PATH="$PREFLIGHT_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INCOMPLETE_ROOT/install.sh" >"$TMP_HOME/incomplete.log" 2>&1
incomplete_rc=$?
set -e
[ "$incomplete_rc" -eq 1 ] || fail "incomplete checkout returned $incomplete_rc instead of 1"
[ ! -s "$PREFLIGHT_LOG" ] || fail 'incomplete checkout reached macOS prerequisites before source preflight'
[ ! -s "$TOOL_DRY_LOG" ] || fail 'incomplete checkout invoked an installer or download before source preflight'
assert_not_exists "$INCOMPLETE_HOME/.zshrc"

TEST_HOME="$TMP_HOME/home"
BOOTSTRAP_BIN="$TMP_HOME/bootstrap-bin"
VSCODE_HOME="$TEST_HOME/Library/Application Support/Code/User"
mkdir -p "$BOOTSTRAP_BIN" "$TEST_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
for command_name in herdr codegraph gentle-ai opencode codex agent agy claude copilot kilo; do
  cat >"$BOOTSTRAP_BIN/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$BOOTSTRAP_BIN/$command_name"
done
cat >"$BOOTSTRAP_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = '--print-path' ] && exit 0
exit 99
EOF
chmod +x "$BOOTSTRAP_BIN/xcode-select"
printf '%s\n' '#!/usr/bin/env bash' >"$TEST_HOME/brew"
chmod +x "$TEST_HOME/brew"
mkdir -p -- \
  "$TEST_HOME/.config/ghostty" \
  "$TEST_HOME/.config/herdr" \
  "$TEST_HOME/.claude" \
  "$TEST_HOME/.claude/hooks" \
  "$TEST_HOME/.claude/skills/pptx/node_modules" \
  "$VSCODE_HOME"

# Symlinks managed by an earlier installer version must migrate to copies.
ln -s -- "$ROOT/.zshrc" "$TEST_HOME/.zshrc"
ln -s -- "$ROOT/config/claude/agents" "$TEST_HOME/.claude/agents"

# Conflicting local files must be backed up before replacement.
printf '%s\n' 'local zprofile' >"$TEST_HOME/.zprofile"
printf '%s\n' 'local Claude instructions' >"$TEST_HOME/.claude/CLAUDE.md"
printf '%s\n' 'local VS Code settings' >"$VSCODE_HOME/settings.json"

# A stale file under a managed directory must be removed by rsync --delete.
printf '%s\n' 'stale managed file' >"$TEST_HOME/.config/ghostty/stale.conf"
printf '%s\n' 'local Ghostty config' >"$TEST_HOME/.config/ghostty/config.ghostty"
printf '%s\n' 'runtime Herdr session' >"$TEST_HOME/.config/herdr/session.json"

# User-local state outside the managed set must survive installation.
printf '%s\n' 'local identity' >"$TEST_HOME/.gitconfig.local"
printf '%s\n' 'unmanaged marker' >"$TEST_HOME/local-marker"
printf '%s\n' 'runtime dependency' >"$TEST_HOME/.claude/skills/pptx/node_modules/.keep"
printf '%s\n' 'runtime rollback' >"$TEST_HOME/.claude/hooks/example.sh.backup.20260821000000"
printf '#!/usr/bin/env bash\nexit 0\n' >"$EXCLUDE_FIXTURE"

printf '%s\n' '== isolated default bootstrap =='
: >"$TOOL_DRY_LOG"
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TEST_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TEST_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/install.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'default bootstrap invoked a real installer or download'
grep -qF 'prerrequisitos macOS' "$TMP_HOME/install.log" || fail 'default bootstrap did not check macOS prerequisites'
grep -qF 'herramientas de shell y agentes' "$TMP_HOME/install.log" || fail 'default bootstrap did not check shell and agent tools'

printf '%s\n' '== independent copies =='
# Core configuration
assert_file "$TEST_HOME/.zshrc"
assert_not_symlink "$TEST_HOME/.zshrc"
assert_equal "$ROOT/.zshrc" "$TEST_HOME/.zshrc"
assert_file "$TEST_HOME/.zshenv"
assert_equal "$ROOT/.zshenv" "$TEST_HOME/.zshenv"
assert_file "$TEST_HOME/.p10k.zsh"
assert_equal "$ROOT/.p10k.zsh" "$TEST_HOME/.p10k.zsh"
assert_file "$TEST_HOME/.gitconfig"
assert_equal "$ROOT/.gitconfig" "$TEST_HOME/.gitconfig"
assert_file "$TEST_HOME/.gitignore_global"
assert_equal "$ROOT/config/git/.gitignore_global" "$TEST_HOME/.gitignore_global"
assert_directory "$TEST_HOME/.git-hooks"
assert_file "$TEST_HOME/.git-hooks/pre-push"

# Claude configuration
assert_directory "$TEST_HOME/.claude/agents"
assert_not_symlink "$TEST_HOME/.claude/agents"
assert_file "$TEST_HOME/.claude/agents/backend-architect.md"
assert_file "$TEST_HOME/.claude/CLAUDE.md"
assert_equal "$ROOT/config/claude/CLAUDE.md" "$TEST_HOME/.claude/CLAUDE.md"
assert_file "$TEST_HOME/.claude/mcp-servers.json"
assert_equal "$ROOT/config/claude/mcp-servers.json" "$TEST_HOME/.claude/mcp-servers.json"
assert_file "$TEST_HOME/.claude/scripts/validate-task-roadmap.py"
assert_file "$TEST_HOME/.claude/hooks/lib/test-runner.sh"
for script in "${TEST_ONLY_CLAUDE_SCRIPTS[@]}"; do
  assert_not_exists "$TEST_HOME/.claude/scripts/$script"
done

# Ghostty configuration
assert_file "$TEST_HOME/.config/ghostty/config.ghostty"
assert_not_symlink "$TEST_HOME/.config/ghostty"
assert_equal "$ROOT/config/ghostty/config.ghostty" "$TEST_HOME/.config/ghostty/config.ghostty"

# Herdr configuration is a managed file, not a managed directory: session
# state and plugin locks must survive installation.
assert_file "$TEST_HOME/.config/herdr/config.toml"
assert_equal "$ROOT/config/herdr/config.toml" "$TEST_HOME/.config/herdr/config.toml"
assert_file "$TEST_HOME/.config/herdr/session.json"
grep -qxF 'runtime Herdr session' "$TEST_HOME/.config/herdr/session.json" || fail 'Herdr runtime state changed'

# VS Code configuration
assert_file "$VSCODE_HOME/settings.json"
assert_file "$VSCODE_HOME/keybindings.json"
assert_file "$VSCODE_HOME/mcp.json"
assert_not_symlink "$VSCODE_HOME/settings.json"
assert_equal "$ROOT/config/vscode/settings.json" "$VSCODE_HOME/settings.json"
assert_equal "$ROOT/config/vscode/keybindings.json" "$VSCODE_HOME/keybindings.json"
assert_equal "$ROOT/config/vscode/mcp.json" "$VSCODE_HOME/mcp.json"
assert_not_exists "$TEST_HOME/.claude/hooks/$EXCLUDE_FIXTURE_NAME"

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

vscode_backup=$(find "$VSCODE_HOME" -maxdepth 1 -name 'settings.json.backup.*' -type f -print -quit)
[ -n "$vscode_backup" ] || fail 'missing VS Code settings backup'
grep -qxF 'local VS Code settings' "$vscode_backup" || fail 'wrong VS Code settings backup content'

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
: >"$TOOL_DRY_LOG"
TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TEST_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TEST_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/reinstall.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'idempotent bootstrap invoked a real installer or download'
if grep -q '  BACKUP ' "$TMP_HOME/reinstall.log"; then
  fail 'idempotent reinstall created a new backup'
fi

printf '%s\n' 'PASS: install.sh syntax, shellcheck, deterministic bootstrap, symlink migration, backups, cleanup, and local preservation'

printf '%s\n' '== install.sh backup failure regressions =='
bash "$ROOT/.github/test/install-backups.test.sh"

printf '%s\n' '== Claude provider wrapper =='
WRAPPER_HOME="$TMP_HOME/wrapper-home"
WRAPPER_BIN="$TMP_HOME/wrapper-bin"
mkdir -p "$WRAPPER_HOME/.claude" "$WRAPPER_BIN"
for overlay in deepseek glm openrouter ollama; do
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

printf '%s\n' '== AGENTS.md/CLAUDE.md scope-detection hook =='
bash "$ROOT/.github/test/project-integrations-check.test.sh"

printf '%s\n' '== gauntlet-stop.sh timeout and coverage regressions =='
bash "$ROOT/.github/test/gauntlet-stop.test.sh"

printf '%s\n' '== quality-gate.sh timeout regressions =='
bash "$ROOT/.github/test/quality-gate.test.sh"

printf '%s\n' '== hook edge cases =='
bash "$ROOT/.github/test/hooks-edge-cases.test.sh"

printf '%s\n' '== statusline model-tier icons =='
bash "$ROOT/.github/test/statusline.test.sh"

printf '%s\n' '== read-only doctor =='
bash "$ROOT/.github/test/doctor.test.sh"

printf '%s\n' '== Herdr auto-start guard =='
bash "$ROOT/.github/test/herdr-autostart.test.sh"

printf '%s\n' '== validation contract =='
bash "$ROOT/.github/test/validate-contract.test.sh"
