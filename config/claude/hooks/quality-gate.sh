#!/bin/bash
# quality-gate.sh — PreToolUse hook for git commit
# Runs lint + tests + coverage before allowing a commit.
# Defensive mode: if the project has no test runner configured, warns but does not block.
# Blocks commit (exit 2) if lint or tests fail.

# Read hook input (JSON on stdin)
input=$(cat)

# Extract tool_name and command
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // ""')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only act on Bash
[ "$TOOL_NAME" != "Bash" ] && exit 0

# Only act on git commit (not amend, merge, etc.)
echo "$COMMAND" | grep -qE 'git commit ' || exit 0

# Skip merge/amend commits
echo "$COMMAND" | grep -qE '(--amend|--merge|-m\s+"merge)' && exit 0

# Detect project root and test runner
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
cd "$ROOT" 2>/dev/null || exit 0

# Function to block commit with message
block() {
  local msg="$1"
  echo "[quality-gate] COMMIT BLOCKED: $msg" >&2
  echo "[quality-gate] Fix the issue and retry. Do NOT use --no-verify." >&2
  exit 2
}

# Detect test runner and lint
HAS_TESTS=false
TEST_CMD=""
LINT_CMD=""
COVERAGE_CMD=""

if [ -f "package.json" ]; then
  # JS/TS project
  if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    HAS_TESTS=true
    # Detect runner
    if jq -r '.scripts.test' package.json | grep -qE 'vitest|jest'; then
      TEST_CMD="npm test"
      COVERAGE_CMD="npm test -- --coverage 2>/dev/null || npm test -- --coverage.enabled 2>/dev/null || true"
    fi
  fi
  if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
    LINT_CMD="npm run lint"
  elif command -v eslint >/dev/null 2>&1 && [ -f ".eslintrc.js" -o -f ".eslintrc.json" -o -f ".eslintrc.yml" -o -f "eslint.config.js" -o -f "eslint.config.mjs" ]; then
    LINT_CMD="npx eslint . --max-warnings=0"
  fi
elif [ -f "pyproject.toml" ] || [ -f "setup.cfg" ] || [ -f "pytest.ini" ]; then
  # Python project
  if command -v pytest >/dev/null 2>&1; then
    HAS_TESTS=true
    TEST_CMD="pytest"
    COVERAGE_CMD="pytest --cov --cov-report=term-missing"
  fi
elif [ -f "go.mod" ]; then
  # Go project
  HAS_TESTS=true
  TEST_CMD="go test ./..."
  COVERAGE_CMD="go test -cover ./..."
  if command -v golangci-lint >/dev/null 2>&1; then
    LINT_CMD="golangci-lint run"
  fi
elif [ -f "Cargo.toml" ]; then
  # Rust project
  HAS_TESTS=true
  TEST_CMD="cargo test"
  if command -v clippy >/dev/null 2>&1; then
    LINT_CMD="cargo clippy -- -D warnings"
  fi
fi

# If no tests configured, warn (don't block, but make it clear)
if [ "$HAS_TESTS" = false ]; then
  echo "[quality-gate] WARNING: No test runner detected in this project." >&2
  echo "[quality-gate] ALL code requires tests (see rules/common/testing.md)." >&2
  echo "[quality-gate] Configure a test runner before writing production code." >&2
  exit 0
fi

# 1. Lint (if available)
if [ -n "$LINT_CMD" ]; then
  if ! $LINT_CMD >/dev/null 2>&1; then
    block "lint failed. Run: $LINT_CMD"
  fi
fi

# 2. Tests
if [ -n "$TEST_CMD" ]; then
  if ! $TEST_CMD >/dev/null 2>&1; then
    block "tests failed. Run: $TEST_CMD"
  fi
fi

# 3. Coverage (best effort, does not block if unmeasurable)
# Threshold is verified in CI, not on every commit (can be slow).
# Hook only reports if coverage is below threshold.
if [ -n "$COVERAGE_CMD" ]; then
  COVERAGE_OUTPUT=$($COVERAGE_CMD 2>&1 || true)
  # Extract coverage percentage (best effort)
  COVERAGE_PCT=$(echo "$COVERAGE_OUTPUT" | grep -oE '[0-9]+(\.[0-9]+)?%' | head -1 | tr -d '%')
  if [ -n "$COVERAGE_PCT" ]; then
    if [ "$(echo "$COVERAGE_PCT < 80" | bc 2>/dev/null)" = "1" ]; then
      echo "[quality-gate] WARNING: coverage ${COVERAGE_PCT}% < 80%. Consider adding tests before pushing." >&2
    fi
  fi
fi

# 4. Scope creep detection
# Warn if a single commit touches files in 4+ unrelated top-level directories.
STAGED_DIRS=$(git diff --cached --name-only 2>/dev/null | awk -F/ '{print $1}' | sort -u)
DIR_COUNT=$(echo "$STAGED_DIRS" | grep -c . 2>/dev/null || echo "0")
if [ "$DIR_COUNT" -gt 3 ] 2>/dev/null; then
  echo "[quality-gate] WARNING: commit touches ${DIR_COUNT} top-level directories: $(echo "$STAGED_DIRS" | tr '\n' ' ')" >&2
  echo "[quality-gate] Consider splitting into smaller, scoped commits (see rules/common/git-workflow.md)." >&2
fi

# All good
exit 0