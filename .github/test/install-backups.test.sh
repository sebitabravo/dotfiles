#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
INSTALL="$ROOT/install.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-backup-regression.XXXXXX")"
REAL_CP="$(command -v cp)"

cleanup() {
  rm -rf -- "$TMP"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_equal() {
  cmp -s -- "$1" "$2" || fail "files differ: $1 vs $2"
}

mkdir -p -- "$TMP/bin"

cat >"$TMP/bin/cp" <<'EOF'
#!/usr/bin/env bash

for arg in "$@"; do
  if [ "$arg" = "${DOTFILES_TEST_FAIL_SOURCE:-}" ]; then
    destination="${@: -1}"
    printf '%s\n' 'partial file' >"$destination" 2>/dev/null || true
    printf '%s\n' 'intentional cp failure' >&2
    exit 91
  fi
done

exec "$DOTFILES_TEST_REAL_CP" "$@"
EOF

chmod +x "$TMP/bin/cp"

# Entorno hermetico: install.sh llega al paso de copia solo despues de Homebrew,
# herramientas de bootstrap y fuentes. El PATH queda limitado a stubs para que
# ningun brew, instalador remoto ni descarga real corra durante el test.
TOOL_BIN="$TMP/tools"
mkdir -p -- "$TOOL_BIN"
for tool in codegraph opencode codex agy claude copilot; do
  printf '%s\n' '#!/bin/bash' 'exit 0' >"$TOOL_BIN/$tool"
done
printf '%s\n' '#!/bin/bash' 'printf "unexpected download: %s\n" "$*" >&2' 'exit 99' >"$TOOL_BIN/curl"
chmod +x "$TOOL_BIN"/*
JQ_BIN="$(command -v jq || true)"
[ -x "$JQ_BIN" ] || fail 'jq is required for the isolated bootstrap fixture'
ISOLATED_PATH="$TMP/bin:$TOOL_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

prepare_home() {
  mkdir -p -- "$1/.oh-my-zsh/custom/themes/powerlevel10k"
  printf '%s\n' '#!/bin/bash' 'exit 0' >"$1/brew"
  chmod +x "$1/brew"
}

printf '%s\n' '== failed file copy preserves the original and creates no backup =='
FILE_HOME="$TMP/file-home"
mkdir -p -- "$FILE_HOME"
prepare_home "$FILE_HOME"
printf '%s\n' 'original zprofile' >"$FILE_HOME/.zprofile"
printf '%s\n' 'original zprofile' >"$TMP/expected-zprofile"

set +e
HOME="$FILE_HOME" PATH="$ISOLATED_PATH" \
  DOTFILES_HOMEBREW_BREW_CANDIDATES="$FILE_HOME/brew" DOTFILES_JQ_BIN="$JQ_BIN" \
  DOTFILES_TEST_REAL_CP="$REAL_CP" \
  DOTFILES_TEST_FAIL_SOURCE="$ROOT/.zprofile" \
  bash "$INSTALL" >"$TMP/file-copy.log" 2>&1
file_rc=$?
set -e

[ "$file_rc" -ne 0 ] || fail 'failed file copy unexpectedly succeeded'
assert_equal "$FILE_HOME/.zprofile" "$TMP/expected-zprofile"
file_backup_count="$(find "$FILE_HOME" -maxdepth 1 -name '.zprofile.backup.*' -type f -print | wc -l | tr -d ' ')"
[ "$file_backup_count" -eq 0 ] || fail 'failed file copy left a backup behind'
if find "$FILE_HOME" -name '.dotfiles-file-stage.*' -print -quit | grep -q .; then
  fail 'failed file copy left a temporary staging file'
fi

printf '%s\n' 'PASS: failed file copy preserves the original and leaves no staging file'
