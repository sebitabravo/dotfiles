#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
DEFAULTS_SCRIPT="$ROOT/config/macos/defaults.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/defaults-failure-propagation.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
HOME_FIX="$TMP/home"
OUTPUT="$TMP/output.log"
CALL_LOG="$TMP/defaults.calls"
mkdir -p "$BIN" "$HOME_FIX"

# Fail only the middle write in the Dock auto-hide group. The final write in
# that group would succeed, which is the exact scenario that used to report a
# false [SET] when the grouped commands were separated by semicolons.
cat >"$BIN/defaults" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${DEFAULTS_CALL_LOG:?}"
if [ "${1:-}" = "write" ] && [ "${2:-}" = "com.apple.dock" ] && [ "${3:-}" = "autohide-delay" ]; then
  exit 1
fi
if [ "${1:-}" = "read" ] && [ -n "${DEFAULTS_FAIL_READ:-}" ] && [[ "${2:-}" == *"$DEFAULTS_FAIL_READ"* ]]; then
  exit 1
fi
exit 0
EOF
cat >"$BIN/mdfind" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MDFIND_COUNT:-0}"
EOF
cat >"$BIN/killall" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$BIN/tmutil" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$BIN/sw_vers" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '15.7.9'
EOF
cat >"$BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'arm64'
EOF
cat >"$BIN/chflags" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN/defaults" "$BIN/killall" "$BIN/tmutil" "$BIN/sw_vers" "$BIN/uname" "$BIN/chflags" "$BIN/mdfind"

set +e
HOME="$HOME_FIX" DEFAULTS_CALL_LOG="$CALL_LOG" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$DEFAULTS_SCRIPT" --no-sudo >"$OUTPUT" 2>&1
rc=$?
set -e

[ "$rc" -eq 1 ] || {
  printf 'FAIL: defaults.sh returned %s after simulated grouped write failure\n' "$rc" >&2
  cat "$OUTPUT" >&2
  exit 1
}
grep -Fq '[FAIL] Dock auto-hide instantaneo' "$OUTPUT" ||
  {
    echo 'FAIL: middle grouped write failure was not reported' >&2
    exit 1
  }
if grep -Fq '[SET] Dock auto-hide instantaneo' "$OUTPUT"; then
  echo 'FAIL: partially failed grouped block reported [SET]' >&2
  exit 1
fi
grep -Eq '^=== 1 defaults operation\(s\) failed ===$' "$OUTPUT" ||
  {
    echo 'FAIL: aggregate grouped failure summary was missing' >&2
    exit 1
  }

# A failure in one grouped block must not abort unrelated writes that follow it.
grep -Fq 'write com.apple.dock launchanim -bool false' "$CALL_LOG" ||
  {
    echo 'FAIL: later independent defaults write was suppressed' >&2
    exit 1
  }

# Segundo escenario: el container de Mail no se puede leer (sin Full Disk Access,
# o Mail nunca se abrió). El bloque Mail se salta sin escribir nada; Safari, que
# sí tiene container legible, sigue escribiendo. Las rutas de desarrollo existen
# acá, así que la medición de Spotlight tiene que avisar y no declarar exclusión.
HOME_DEV="$TMP/home-dev"
OUTPUT_DEV="$TMP/output-dev.log"
CALL_LOG_DEV="$TMP/defaults-dev.calls"
mkdir -p "$HOME_DEV/Developer" "$HOME_DEV/Library/Caches"
set +e
HOME="$HOME_DEV" DEFAULTS_CALL_LOG="$CALL_LOG_DEV" DEFAULTS_FAIL_READ='Containers/com.apple.mail' \
  MDFIND_COUNT=7 PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
  bash "$DEFAULTS_SCRIPT" --no-sudo >"$OUTPUT_DEV" 2>&1
set -e

grep -Fq '[SKIP] Bloque Mail (5 keys)' "$OUTPUT_DEV" ||
  {
    echo 'FAIL: Mail block was not skipped when its container is unreadable' >&2
    exit 1
  }
if grep -Fq 'write com.apple.mail DisableReplyAnimations' "$CALL_LOG_DEV"; then
  echo 'FAIL: Mail keys were written while its container is unreadable' >&2
  exit 1
fi
grep -Fq 'write com.apple.Safari SendDoNotTrackHTTPHeader' "$CALL_LOG_DEV" ||
  {
    echo 'FAIL: Safari stopped writing although its container is readable' >&2
    exit 1
  }
grep -Fq '[WARN] Spotlight sigue indexando' "$OUTPUT_DEV" ||
  {
    echo 'FAIL: Spotlight measurement did not warn about recent indexing' >&2
    exit 1
  }
if grep -Fq 'Spotlight excluye' "$OUTPUT_DEV"; then
  echo 'FAIL: script still claims Spotlight exclusion from the marker' >&2
  exit 1
fi
grep -Fq '[WARN] IDFA sigue activo' "$OUTPUT_DEV" ||
  {
    echo 'FAIL: IDFA read-back did not warn when the value did not stick' >&2
    exit 1
  }

printf '%s\n' 'PASS: defaults.sh reports helper/manual write failures and exits non-zero'
