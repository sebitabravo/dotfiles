#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
INSTALL="$ROOT/install.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-backup-regression.XXXXXX")"
REAL_CP="$(command -v cp)"
REAL_RSYNC="$(command -v rsync)"

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

assert_not_exists() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "unexpected path: $1"
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

cat >"$TMP/bin/rsync" <<'EOF'
#!/usr/bin/env bash

if [ "${DOTFILES_TEST_FAIL_BACKUP_RSYNC:-0}" = 1 ]; then
  destination="${@: -1}"
  destination="${destination%/}"
  case "$destination" in
    */.dotfiles-backups/*)
      printf '%s\n' 'partial snapshot' >"$destination/partial.marker"
      printf '%s\n' 'intentional backup rsync failure' >&2
      exit 92
      ;;
  esac
fi

exec "$DOTFILES_TEST_REAL_RSYNC" "$@"
EOF

chmod +x "$TMP/bin/cp" "$TMP/bin/rsync"

printf '%s\n' '== failed file copy preserves the original and creates no backup =='
FILE_HOME="$TMP/file-home"
mkdir -p -- "$FILE_HOME"
printf '%s\n' 'original zprofile' >"$FILE_HOME/.zprofile"
printf '%s\n' 'original zprofile' >"$TMP/expected-zprofile"

set +e
HOME="$FILE_HOME" PATH="$TMP/bin:$PATH" \
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

printf '%s\n' '== failed directory backup preserves the original and removes partial state =='
DIR_HOME="$TMP/directory-home"
mkdir -p -- "$DIR_HOME/.config/ghostty"
printf '%s\n' 'original ghostty config' >"$DIR_HOME/.config/ghostty/config.ghostty"
printf '%s\n' 'local-only state' >"$DIR_HOME/.config/ghostty/local-only.conf"
printf '%s\n' 'original ghostty config' >"$TMP/expected-ghostty"
printf '%s\n' 'local-only state' >"$TMP/expected-ghostty-local"

set +e
HOME="$DIR_HOME" PATH="$TMP/bin:$PATH" \
  DOTFILES_TEST_REAL_CP="$REAL_CP" \
  DOTFILES_TEST_REAL_RSYNC="$REAL_RSYNC" \
  DOTFILES_TEST_FAIL_BACKUP_RSYNC=1 \
  bash "$INSTALL" >"$TMP/directory-copy.log" 2>&1
directory_rc=$?
set -e

[ "$directory_rc" -ne 0 ] || fail 'failed directory backup unexpectedly succeeded'
assert_equal "$DIR_HOME/.config/ghostty/config.ghostty" "$TMP/expected-ghostty"
assert_equal "$DIR_HOME/.config/ghostty/local-only.conf" "$TMP/expected-ghostty-local"
backup_root="$DIR_HOME/.dotfiles-backups"
assert_not_exists "$backup_root"
if find "$DIR_HOME" -name 'partial.marker' -print -quit | grep -q .; then
  fail 'failed directory backup left a partial marker'
fi
if find "$DIR_HOME" -name '.dotfiles-backup-stage.*' -print -quit | grep -q .; then
  fail 'failed directory backup left a staging directory'
fi

printf '%s\n' 'PASS: failed file/directory copies preserve originals and clean partial backups'
