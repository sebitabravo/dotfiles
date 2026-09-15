#!/usr/bin/env bash
# Asserts that defaults.sh takes the right branch per macOS version.
#
# defaults.sh claims to run on Sequoia, Tahoe and Golden Gate. Two behaviours
# differ between them and both were previously untested:
#
#   1. Launchpad springboard-* keys are written only below macOS 26, because
#      Tahoe removed Launchpad from the system.
#   2. Reduce Transparency is skipped only on 26.0 through 26.2, the window
#      where Apple shipped the key broken. It was fixed in 26.3.
#
# CI runs one macOS image per matrix entry, so the guards themselves are
# exercised here with a stubbed sw_vers instead of relying on the runner.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
DEFAULTS_SCRIPT="$ROOT/config/macos/defaults.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/macos-version-guards.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
HOME_FIX="$TMP/home"
mkdir -p "$BIN" "$HOME_FIX"

# Every external command the script may reach is stubbed to a silent success,
# so the run exercises control flow only and never touches the real machine.
for cmd in defaults killall tmutil chflags lsof sharing cupsctl sysadminctl \
  spctl csrutil fdesetup diskutil pmset systemsetup security; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$BIN/$cmd"
  chmod +x "$BIN/$cmd"
done
printf '#!/usr/bin/env bash\necho arm64\n' >"$BIN/uname"
chmod +x "$BIN/uname"

FAILURES=0

run_with_version() {
  printf '#!/usr/bin/env bash\necho %s\n' "$1" >"$BIN/sw_vers"
  chmod +x "$BIN/sw_vers"
  env HOME="$HOME_FIX" PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$DEFAULTS_SCRIPT" --no-sudo --dry-run 2>&1
}

# assert_branch <version> <springboard: written|skipped> <transparency: written|skipped>
assert_branch() {
  local version="$1" springboard="$2" transparency="$3"
  local output
  output="$(run_with_version "$version")"

  if printf '%s' "$output" | grep -q 'springboard-show-duration'; then
    local got_springboard=written
  else
    local got_springboard=skipped
  fi

  if printf '%s' "$output" | grep -q 'reduceTransparency'; then
    local got_transparency=written
  else
    local got_transparency=skipped
  fi

  if [ "$got_springboard" != "$springboard" ]; then
    printf 'FAIL: %s expected springboard-* %s, got %s\n' \
      "$version" "$springboard" "$got_springboard" >&2
    FAILURES=$((FAILURES + 1))
  fi
  if [ "$got_transparency" != "$transparency" ]; then
    printf 'FAIL: %s expected reduceTransparency %s, got %s\n' \
      "$version" "$transparency" "$got_transparency" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

#              version   springboard  reduceTransparency
assert_branch 15.7.9 written written
assert_branch 26 skipped skipped
assert_branch 26.0 skipped skipped
assert_branch 26.2 skipped skipped
assert_branch 26.3 skipped written
assert_branch 26.6.2 skipped written
# macOS 27 Golden Gate. The broken-transparency window was a 26.x-only bug, so
# 27 must write the key again; a guard written as ">= 26" instead of "== 26"
# would silently keep skipping it forever.
assert_branch 27 skipped written
assert_branch 27.0 skipped written
assert_branch 27.2.1 skipped written

if [ "$FAILURES" -gt 0 ]; then
  printf 'FAIL: %s macOS version guard assertion(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf '%s\n' 'PASS: defaults.sh takes the right branch on Sequoia, Tahoe and Golden Gate'
