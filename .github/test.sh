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

printf '%s\n' '== install.sh rejects altered remote bytes before shell execution =='
HASH_MISMATCH_HOME="$TMP_HOME/hash-mismatch-home"
HASH_MISMATCH_BIN="$TMP_HOME/hash-mismatch-bin"
HASH_MISMATCH_CURL_LOG="$TMP_HOME/hash-mismatch-curl.log"
HASH_MISMATCH_CURL_OUTPUT_LOG="$TMP_HOME/hash-mismatch-curl-output.log"
HASH_MISMATCH_SHELL_LOG="$TMP_HOME/hash-mismatch-shell.log"
mkdir -p \
  "$HASH_MISMATCH_HOME/.oh-my-zsh/custom/themes/powerlevel10k" \
  "$HASH_MISMATCH_BIN"
printf '%s\n' '#!/usr/bin/env bash' >"$HASH_MISMATCH_HOME/brew"
chmod +x "$HASH_MISMATCH_HOME/brew"
cat >"$HASH_MISMATCH_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' Darwin
EOF
cat >"$HASH_MISMATCH_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = '--print-path' ] && exit 0
exit 99
EOF
cat >"$HASH_MISMATCH_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${HASH_MISMATCH_CURL_LOG:?}"
output=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '--output' ]; then
    output="${2:?}"
    shift 2
  else
    shift
  fi
done
printf '%s\n' 'altered remote installer' >"${output:?}"
printf '%s\n' "$output" >"${HASH_MISMATCH_CURL_OUTPUT_LOG:?}"
EOF
cat >"$HASH_MISMATCH_BIN/sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HASH_MISMATCH_SHELL_LOG:?}"
exit 99
EOF
# codegraph queda fuera a proposito: cada stub de esta lista hace que
# install.sh salte ese remote tool por "ya existe", asi que exactamente uno
# tiene que faltar para forzar el path real de descarga y ejercitar el
# checksum fail-closed. CodeGraph es el primer remote tool que install.sh
# intenta tras Homebrew/Oh My Zsh (que se saltan por fixture aparte).
for command_name in gentle-ai opencode codex agent agy claude copilot kilo; do
  cat >"$HASH_MISMATCH_BIN/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$HASH_MISMATCH_BIN/$command_name"
done
chmod +x "$HASH_MISMATCH_BIN/uname" "$HASH_MISMATCH_BIN/xcode-select" \
  "$HASH_MISMATCH_BIN/curl" "$HASH_MISMATCH_BIN/sh"
: >"$HASH_MISMATCH_CURL_LOG"
: >"$HASH_MISMATCH_CURL_OUTPUT_LOG"
: >"$HASH_MISMATCH_SHELL_LOG"
set +e
HASH_MISMATCH_CURL_LOG="$HASH_MISMATCH_CURL_LOG" HASH_MISMATCH_CURL_OUTPUT_LOG="$HASH_MISMATCH_CURL_OUTPUT_LOG" HASH_MISMATCH_SHELL_LOG="$HASH_MISMATCH_SHELL_LOG" \
  HOME="$HASH_MISMATCH_HOME" DOTFILES_HOMEBREW_BREW_CANDIDATES="$HASH_MISMATCH_HOME/brew" \
  PATH="$HASH_MISMATCH_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/hash-mismatch.log" 2>&1
hash_mismatch_rc=$?
set -e
[ "$hash_mismatch_rc" -eq 1 ] || fail "hash mismatch returned $hash_mismatch_rc instead of 1"
[ -s "$HASH_MISMATCH_CURL_LOG" ] || fail 'hash mismatch did not exercise the fake curl download'
[ -s "$HASH_MISMATCH_CURL_OUTPUT_LOG" ] || fail 'hash mismatch did not record its unique temporary file'
[ ! -e "$(cat "$HASH_MISMATCH_CURL_OUTPUT_LOG")" ] || fail 'hash mismatch left the downloaded temporary file behind'
[ ! -s "$HASH_MISMATCH_SHELL_LOG" ] || fail 'hash mismatch invoked the remote shell before verification'
grep -qF 'checksum SHA-256 no coincide para CodeGraph' "$TMP_HOME/hash-mismatch.log" ||
  fail 'hash mismatch did not report the fail-closed checksum error'
for curl_flag in \
  '--proto =https' '--proto-redir =https' '--tlsv1.2' '--fail' '--silent' '--show-error' \
  '--location' '--max-time 120' '--output '; do
  grep -qF -- "$curl_flag" "$HASH_MISMATCH_CURL_LOG" ||
    fail "verified download omitted curl flag: $curl_flag"
done

printf '%s\n' '== install.sh executes a matching verified remote script =='
MATCH_HOME="$TMP_HOME/matching-home"
MATCH_BIN="$TMP_HOME/matching-bin"
MATCH_CURL_LOG="$TMP_HOME/matching-curl.log"
MATCH_CURL_OUTPUT_LOG="$TMP_HOME/matching-curl-output.log"
MATCH_SHELL_LOG="$TMP_HOME/matching-shell.log"
mkdir -p \
  "$MATCH_HOME/.oh-my-zsh/custom/themes/powerlevel10k" \
  "$MATCH_BIN"
printf '%s\n' '#!/usr/bin/env bash' >"$MATCH_HOME/brew"
chmod +x "$MATCH_HOME/brew"
cat >"$MATCH_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' Darwin
EOF
cat >"$MATCH_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = '--print-path' ] && exit 0
exit 99
EOF
cat >"$MATCH_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${MATCH_CURL_LOG:?}"
output=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '--output' ]; then
    output="${2:?}"
    shift 2
  else
    shift
  fi
done
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"${output:?}"
printf '%s\n' "$output" >"${MATCH_CURL_OUTPUT_LOG:?}"
EOF
cat >"$MATCH_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
printf '%s  %s\n' 'f4e90c6e0c1d2ac95a43fa6e82e4caf76fabdb18310afc72597314b58632e56c' "${3:?}"
EOF
cat >"$MATCH_BIN/sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${MATCH_SHELL_LOG:?}"
exit 42
EOF
# codegraph queda fuera del loop de stubs por el mismo motivo que en el bloque
# de hash mismatch: es el primer remote tool real tras Homebrew/Oh My Zsh, y
# el shasum de arriba esta fijado a su checksum real para simular un match.
for command_name in gentle-ai opencode codex agent agy claude copilot kilo; do
  cat >"$MATCH_BIN/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MATCH_BIN/$command_name"
done
chmod +x "$MATCH_BIN/uname" "$MATCH_BIN/xcode-select" "$MATCH_BIN/curl" \
  "$MATCH_BIN/shasum" "$MATCH_BIN/sh"
: >"$MATCH_CURL_LOG"
: >"$MATCH_CURL_OUTPUT_LOG"
: >"$MATCH_SHELL_LOG"
set +e
MATCH_CURL_LOG="$MATCH_CURL_LOG" MATCH_CURL_OUTPUT_LOG="$MATCH_CURL_OUTPUT_LOG" MATCH_SHELL_LOG="$MATCH_SHELL_LOG" \
  HOME="$MATCH_HOME" DOTFILES_HOMEBREW_BREW_CANDIDATES="$MATCH_HOME/brew" \
  PATH="$MATCH_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/matching.log" 2>&1
matching_rc=$?
set -e
[ "$matching_rc" -eq 42 ] || fail "matching verified script returned $matching_rc instead of fake shell status 42"
[ -s "$MATCH_CURL_LOG" ] || fail 'matching verified script did not exercise the fake curl download'
[ -s "$MATCH_SHELL_LOG" ] || fail 'matching verified script was not executed after verification'
[ -s "$MATCH_CURL_OUTPUT_LOG" ] || fail 'matching verified script did not record its temporary file'
[ ! -e "$(cat "$MATCH_CURL_OUTPUT_LOG")" ] || fail 'matching verified script left the downloaded temporary file behind'

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
BOOTSTRAP_CURL_LOG="$TMP_HOME/bootstrap-curl.log"
VSCODE_HOME="$TEST_HOME/Library/Application Support/Code/User"
MCP_JQ_BIN="$(command -v jq || true)"
[ -x "$MCP_JQ_BIN" ] || fail 'jq is required for the isolated MCP fixture'
mkdir -p "$BOOTSTRAP_BIN" "$TEST_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
for command_name in herdr codegraph gentle-ai opencode codex agent agy copilot kilo; do
  cat >"$BOOTSTRAP_BIN/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$BOOTSTRAP_BIN/$command_name"
done
cat >"$BOOTSTRAP_BIN/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${MCP_FAKE_LOG:?}"
case "${1:-} ${2:-}" in
  'mcp add-json')
    [ "${3:-}" = '--scope' ] && [ "${4:-}" = 'user' ] || exit 2
    name=${5:?}
    definition=${6:?}
    if [ "${MCP_FAKE_FAIL_ADD_NAME:-}" = "$name" ] && \
      [ ! -e "${MCP_FAKE_ADD_FAILURE_MARKER:-}" ]; then
      : >"${MCP_FAKE_ADD_FAILURE_MARKER:?}"
      printf 'forced MCP add failure for %s\n' "$name" >&2
      exit 97
    fi
    if "$MCP_FAKE_JQ_BIN" -e --arg name "$name" '.mcpServers[$name] != null' "$HOME/.claude.json" >/dev/null 2>&1; then
      printf 'MCP server %s already exists in user config\n' "$name" >&2
      exit 1
    fi
    "$MCP_FAKE_JQ_BIN" --arg name "$name" --argjson definition "$definition" \
      '.mcpServers = (.mcpServers // {}) | .mcpServers[$name] = $definition' \
      "$HOME/.claude.json" >"$HOME/.claude.json.tmp"
    mv -- "$HOME/.claude.json.tmp" "$HOME/.claude.json"
    ;;
  'mcp remove')
    [ "${3:-}" = '--scope' ] && [ "${4:-}" = 'user' ] || exit 2
    name=${5:?}
    "$MCP_FAKE_JQ_BIN" --arg name "$name" 'del(.mcpServers[$name])' "$HOME/.claude.json" \
      >"$HOME/.claude.json.tmp"
    mv -- "$HOME/.claude.json.tmp" "$HOME/.claude.json"
    ;;
  'mcp get')
    "$MCP_FAKE_JQ_BIN" -e --arg name "${3:?}" '.mcpServers[$name] != null' "$HOME/.claude.json" >/dev/null
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "$BOOTSTRAP_BIN/claude"
cat >"$BOOTSTRAP_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = '--print-path' ] && exit 0
exit 99
EOF
chmod +x "$BOOTSTRAP_BIN/xcode-select"
# Font archives are the only downloads allowed by the isolated bootstrap
# fixture. Build a valid local archive for each pinned font URL and reject all
# other URLs so an unexpected remote installer download still fails closed.
cat >"$BOOTSTRAP_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${BOOTSTRAP_CURL_LOG:?}"
output=''
url=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = '--output' ]; then
    output="${2:?}"
    shift 2
  else
    url="$1"
    shift
  fi
done

case "$url" in
  'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip')
    font_name='CascadiaCodePL.ttf'
    ;;
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip')
    font_name='FiraCodeNerdFont.ttf'
    ;;
  'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip')
    font_name='JetBrainsMono.ttf'
    ;;
  'https://codeload.github.com/andreberg/Meslo-Font/zip/09a431d546d211130352c28eb0466e5d7d5aeaf0')
    font_name='MesloLGSNF.ttf'
    ;;
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/IosevkaTerm.zip')
    font_name='IosevkaTermNerdFont.ttf'
    ;;
  *)
    printf 'unexpected remote download: %s\n' "$url" >&2
    exit 99
    ;;
esac

font_fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-font-fixture.XXXXXX")"
trap 'rm -rf -- "$font_fixture_dir"' EXIT
printf 'isolated font fixture: %s\n' "$url" >"$font_fixture_dir/$font_name"
(cd "$font_fixture_dir" && /usr/bin/zip -q -X "$output" "$font_name")
EOF
cat >"$BOOTSTRAP_BIN/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

file=''
while [ "$#" -gt 0 ]; do
  file="$1"
  shift
done
case "${file##*/}" in
  0.zip) hash='e67a68ee3386db63f48b9054bd196ea752bc6a4ebb4df35adce6733da50c8474' ;;
  1.zip) hash='4ee8fbafecfc90460399b9828270b8ece30ccbf60b3ab875d64ff77696c6e262' ;;
  2.zip) hash='6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf' ;;
  3.zip) hash='930d960c30ff582c1ca27721f74cc93c0f51e74f63b88360904eaa1af65f55e4' ;;
  4.zip) hash='4d2c7fc44f215cd762ceab5167aa13285f179e83f36d56a1129c2871b9552080' ;;
  *)
    printf 'unexpected checksum target: %s\n' "$file" >&2
    exit 99
    ;;
esac
printf '%s  %s\n' "$hash" "$file"
EOF
chmod +x "$BOOTSTRAP_BIN/curl" "$BOOTSTRAP_BIN/shasum"
printf '%s\n' '#!/usr/bin/env bash' >"$TEST_HOME/brew"
chmod +x "$TEST_HOME/brew"
mkdir -p -- \
  "$TEST_HOME/.config/ghostty" \
  "$TEST_HOME/.config/herdr" \
  "$TEST_HOME/.claude" \
  "$TEST_HOME/.claude/hooks" \
  "$TEST_HOME/.claude/skills/pptx/node_modules" \
  "$VSCODE_HOME"
printf '%s\n' '{"userOwned":true,"mcpServers":{"user-server":{"type":"stdio","command":"user-server"}}}' \
  >"$TEST_HOME/.claude.json"
chmod 600 "$TEST_HOME/.claude.json"

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

printf '%s\n' '== dry-run skips user-scope MCP registration =='
MCP_DRY_HOME="$TMP_HOME/mcp-dry-home"
MCP_DRY_LOG="$TMP_HOME/mcp-dry.log"
mkdir -p "$MCP_DRY_HOME"
: >"$MCP_DRY_LOG"
MCP_FAKE_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_LOG="$MCP_DRY_LOG" HOME="$MCP_DRY_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$MCP_DRY_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" --dry-run >"$TMP_HOME/mcp-dry-install.log"
[ ! -s "$MCP_DRY_LOG" ] || fail 'dry-run registered a Claude MCP server'

printf '%s\n' '== MCP replacement failure restores the previous definition =='
MCP_ROLLBACK_HOME="$TMP_HOME/mcp-rollback-home"
MCP_ROLLBACK_MARKER="$TMP_HOME/mcp-rollback-add-failed"
MCP_ROLLBACK_LOG="$TMP_HOME/mcp-rollback.log"
MCP_ROLLBACK_TMPDIR="$TMP_HOME/mcp-rollback-tmp"
MCP_ROLLBACK_BEFORE="$MCP_ROLLBACK_TMPDIR/claude-before.json"
mkdir -p "$MCP_ROLLBACK_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
mkdir -p "$MCP_ROLLBACK_TMPDIR"
printf '%s\n' '#!/usr/bin/env bash' >"$MCP_ROLLBACK_HOME/brew"
chmod +x "$MCP_ROLLBACK_HOME/brew"
printf '%s\n' '{"userOwned":true,"mcpServers":{"context7":{"type":"stdio","command":"legacy-context7","args":["--legacy"]},"user-server":{"type":"stdio","command":"user-server"}}}' \
  >"$MCP_ROLLBACK_HOME/.claude.json"
cp -p "$MCP_ROLLBACK_HOME/.claude.json" "$MCP_ROLLBACK_BEFORE"
old_context7_definition='{"type":"stdio","command":"legacy-context7","args":["--legacy"]}'
if BOOTSTRAP_CURL_LOG="$BOOTSTRAP_CURL_LOG" DOTFILES_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_LOG="$MCP_ROLLBACK_LOG" \
  MCP_FAKE_FAIL_ADD_NAME='context7' MCP_FAKE_ADD_FAILURE_MARKER="$MCP_ROLLBACK_MARKER" \
  HOME="$MCP_ROLLBACK_HOME" TMPDIR="$MCP_ROLLBACK_TMPDIR" DOTFILES_HOMEBREW_BREW_CANDIDATES="$MCP_ROLLBACK_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/mcp-rollback-install.log" 2>&1; then
  fail 'MCP replacement failure unexpectedly succeeded'
fi
assert_equal "$MCP_ROLLBACK_BEFORE" "$MCP_ROLLBACK_HOME/.claude.json"
jq -e --argjson expected "$old_context7_definition" \
  '.mcpServers.context7 == $expected and .mcpServers["user-server"].command == "user-server"' \
  "$MCP_ROLLBACK_HOME/.claude.json" >/dev/null ||
  fail 'failed MCP replacement did not restore the exact old definition'
grep -qF 'no se pudo registrar el MCP administrado context7' "$TMP_HOME/mcp-rollback-install.log" ||
  fail 'MCP replacement failure was not reported'
[ "$(grep -c '^mcp remove --scope user context7$' "$MCP_ROLLBACK_LOG" || true)" -eq 1 ] ||
  fail 'MCP replacement failure did not remove the old definition once'
[ "$(grep -c '^mcp add-json --scope user context7 ' "$MCP_ROLLBACK_LOG" || true)" -eq 2 ] ||
  fail 'MCP replacement failure did not attempt managed add and restoration'

printf '%s\n' '== isolated default bootstrap =='
: >"$TOOL_DRY_LOG"
: >"$BOOTSTRAP_CURL_LOG"
BOOTSTRAP_CURL_LOG="$BOOTSTRAP_CURL_LOG" DOTFILES_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_LOG="$TMP_HOME/mcp.log" TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TEST_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TEST_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/install.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'default bootstrap invoked a real installer or download'
[ "$(wc -l <"$BOOTSTRAP_CURL_LOG" | tr -d ' ')" -eq 5 ] || fail 'default bootstrap did not simulate exactly five font downloads'
for font_url in \
  'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip' \
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip' \
  'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip' \
  'https://codeload.github.com/andreberg/Meslo-Font/zip/09a431d546d211130352c28eb0466e5d7d5aeaf0' \
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/IosevkaTerm.zip'; do
  grep -qF -- "$font_url" "$BOOTSTRAP_CURL_LOG" || fail "font fixture did not serve $font_url"
done
grep -qF 'prerrequisitos macOS' "$TMP_HOME/install.log" || fail 'default bootstrap did not check macOS prerequisites'
grep -qF 'herramientas de shell y agentes' "$TMP_HOME/install.log" || fail 'default bootstrap did not check shell and agent tools'
for mcp_name in context7 codegraph playwright; do
  jq -e --arg name "$mcp_name" \
    '.mcpServers[$name] == (input.mcpServers[$name])' \
    "$TEST_HOME/.claude.json" "$ROOT/config/claude/mcp-servers.json" >/dev/null ||
    fail "managed MCP server $mcp_name was not registered exactly"
done
jq -e '.userOwned == true and .mcpServers["user-server"].command == "user-server"' \
  "$TEST_HOME/.claude.json" >/dev/null ||
  fail 'unrelated user MCP configuration was not preserved'
[ "$(grep -c '^mcp add-json --scope user ' "$TMP_HOME/mcp.log")" -eq 3 ] ||
  fail 'normal bootstrap did not register each managed MCP server exactly once'

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
MCP_ADD_COUNT="$(grep -c '^mcp add-json --scope user ' "$TMP_HOME/mcp.log")"
MCP_REMOVE_COUNT="$(grep -c '^mcp remove --scope user ' "$TMP_HOME/mcp.log" || true)"
BOOTSTRAP_CURL_LOG="$BOOTSTRAP_CURL_LOG" DOTFILES_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_JQ_BIN="$MCP_JQ_BIN" MCP_FAKE_LOG="$TMP_HOME/mcp.log" TOOL_DRY_LOG="$TOOL_DRY_LOG" HOME="$TEST_HOME" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$TEST_HOME/brew" \
  PATH="$BOOTSTRAP_BIN:$TOOL_DRY_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$INSTALL" >"$TMP_HOME/reinstall.log"
[ ! -s "$TOOL_DRY_LOG" ] || fail 'idempotent bootstrap invoked a real installer or download'
if grep -q '  BACKUP ' "$TMP_HOME/reinstall.log"; then
  fail 'idempotent reinstall created a new backup'
fi
[ "$(grep -c '^mcp add-json --scope user ' "$TMP_HOME/mcp.log")" -eq "$MCP_ADD_COUNT" ] ||
  fail 'idempotent reinstall added a duplicate MCP server'
[ "$(grep -c '^mcp remove --scope user ' "$TMP_HOME/mcp.log" || true)" -eq "$MCP_REMOVE_COUNT" ] ||
  fail 'idempotent reinstall removed an unchanged MCP server'

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

printf '%s\n' '== verify.sh authoritative source regression =='
bash "$ROOT/.github/test/verify.test.sh"

printf '%s\n' '== Claude permission boundary regressions =='
bash "$ROOT/.github/test/protect-tests.test.sh"
SETTINGS="$ROOT/config/claude/settings.json"
jq -e '
  .permissions.defaultMode == "auto"
  and .permissions.disableAutoMode != "disable"
  and (.permissions | has("disableBypassPermissionsMode") | not)
  and .skipDangerousModePermissionPrompt == true
  and (has("bypassPermissions") | not)
' "$SETTINGS" >/dev/null ||
  fail 'Claude permissive Auto Mode contract drifted'
jq -e '.permissions.allow | index("Skill") != null' "$SETTINGS" >/dev/null ||
  fail 'automatic workflow cannot load its required versioned skill'
jq -e '.permissions.ask == [
  "Bash(npm install:*)",
  "Bash(npm i:*)",
  "Bash(pip install:*)",
  "Bash(git push:*)",
  "Bash(git rebase:*)"
]' "$SETTINGS" >/dev/null ||
  fail 'Claude ask rules drifted from the historical five-command boundary'
for pattern in \
  'Bash(git fetch:*)' 'Bash(git add:*)' 'Bash(git pull:*)' \
  'Bash(npm:*)' 'Bash(pnpm:*)' 'Bash(bun:*)' 'Bash(yarn:*)' \
  'Bash(fd:*)' 'Bash(sd:*)' 'Bash(brew:*)' 'Bash(pip:*)' \
  'Bash(uvx:*)' 'Bash(uv:*)' 'Bash(cargo:*)' 'Bash(rustc:*)' \
  'Bash(go:*)' 'Bash(make:*)' 'Bash(docker:*)' 'Bash(gh:*)' \
  'Bash(code:*)' 'Bash(nvim:*)' 'Bash(touch:*)' 'Bash(source:*)' \
  'Bash(ng:*)' 'Bash(nx:*)' 'Bash(turbo:*)' \
  'WebFetch' 'mcp__codegraph__*' 'mcp__context7__*' 'mcp__playwright__*'; do
  jq -e --arg pattern "$pattern" '.permissions.allow | index($pattern) != null' "$SETTINGS" >/dev/null ||
    fail "missing intentional permissive allow rule: $pattern"
done
for pattern in \
  'Bash(npm test:*)' 'Bash(npm run test:*)' 'Bash(npm run lint:*)' \
  'Bash(pnpm test:*)' 'Bash(pnpm run test:*)' \
  'Bash(bun test:*)' 'Bash(bun run test:*)' \
  'Bash(yarn test:*)' 'Bash(yarn run test:*)' \
  'Bash(uv run pytest:*)' 'Bash(cargo test:*)' 'Bash(go test:*)' 'Bash(make test:*)'; do
  jq -e --arg pattern "$pattern" '.permissions.allow | index($pattern) != null' "$SETTINGS" >/dev/null ||
    fail "missing automatic verification permission: $pattern"
done
for pattern in \
  'Edit(**/.env)' 'Read(**/.env)' 'Read(~/.ssh/**)' 'Bash(rm -rf /)'; do
  jq -e --arg pattern "$pattern" '.permissions.deny | index($pattern) != null' "$SETTINGS" >/dev/null ||
    fail "missing deterministic secret/destructive deny rule: $pattern"
done

printf '%s\n' '== hook edge cases =='
bash "$ROOT/.github/test/hooks-edge-cases.test.sh"

printf '%s\n' '== statusline model-tier icons =='
bash "$ROOT/.github/test/statusline.test.sh"

printf '%s\n' '== read-only doctor =='
bash "$ROOT/.github/test/doctor.test.sh"

printf '%s\n' '== validation contract =='
bash "$ROOT/.github/test/validate-contract.test.sh"
