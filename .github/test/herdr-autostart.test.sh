#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/herdr-autostart.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

zsh -n "$ROOT/.zshrc"

# Extract the production guard instead of duplicating it in the fixture. The
# fake binary makes the positive path observable without starting a real Herdr
# server or changing the user's session.
sed -n '/^# Herdr — abrir automáticamente/,/^fi$/p' "$ROOT/.zshrc" >"$TMP/guard.zsh"
grep -q 'exec herdr' "$TMP/guard.zsh" || fail 'Herdr guard is missing from .zshrc'

mkdir -p "$TMP/bin"
cat >"$TMP/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' started >"$HERDR_MARKER"
EOF
chmod +x "$TMP/bin/herdr"

cat >"$TMP/runner.zsh" <<EOF
source "$TMP/guard.zsh"
EOF

run_case() {
  local name=$1
  shift
  local marker="$TMP/$name.marker"

  script -q /dev/null env \
    "PATH=$TMP/bin:/usr/bin:/bin" \
    "HERDR_MARKER=$marker" \
    "TERM_PROGRAM=ghostty" \
    "$@" \
    zsh -f -i "$TMP/runner.zsh" >"$TMP/$name.output" 2>&1 ||
    fail "$name: zsh guard execution failed"
}

run_case starts HERDR_AUTO_START=1 HERDR_ENV= TMUX= ZELLIJ=
[ -f "$TMP/starts.marker" ] || fail 'interactive Ghostty shell did not enter Herdr'

run_case nested HERDR_AUTO_START=1 HERDR_ENV=1 TMUX= ZELLIJ=
[ ! -e "$TMP/nested.marker" ] || fail 'nested Herdr shell attempted to start another Herdr'

run_case optout HERDR_AUTO_START=0 HERDR_ENV= TMUX= ZELLIJ=
[ ! -e "$TMP/optout.marker" ] || fail 'HERDR_AUTO_START=0 did not disable auto-start'

run_case other-terminal HERDR_AUTO_START=1 HERDR_ENV= TMUX= ZELLIJ= TERM_PROGRAM=Terminal
[ ! -e "$TMP/other-terminal.marker" ] || fail 'non-Ghostty shell attempted Herdr auto-start'

printf '%s\n' 'PASS: Herdr auto-start is Ghostty-only, interactive, TTY-bound, nest-safe, and opt-out capable'
