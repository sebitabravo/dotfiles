#!/usr/bin/env bash
LIB=/Users/sebastian/Developer/dotfiles/config/claude/hooks/lib/test-runner.sh
. "$LIB"
T=$(mktemp -d)
FAILED=0
check() {
  TEST_CMD=""
  detect_test_cmd "$1" >/dev/null 2>&1
  if [ "$TEST_CMD" = "$2" ]; then
    printf 'PASS  %-16s -> %s\n' "$(basename "$1")" "${TEST_CMD:-<vacio>}"
  else
    printf 'FAIL  %-16s -> %-30s esperaba: %s\n' "$(basename "$1")" "${TEST_CMD:-<vacio>}" "${2:-<vacio>}"
    FAILED=1
  fi
}
mkdir -p "$T/js-npm"        && echo '{"scripts":{"test":"vitest run"}}' > "$T/js-npm/package.json" && touch "$T/js-npm/package-lock.json"
mkdir -p "$T/js-bun"        && echo '{"scripts":{"test":"vitest run"}}' > "$T/js-bun/package.json" && touch "$T/js-bun/bun.lock"
mkdir -p "$T/js-pnpm-ci"    && echo '{"scripts":{"test:ci":"vitest run"}}' > "$T/js-pnpm-ci/package.json" && touch "$T/js-pnpm-ci/pnpm-lock.yaml"
mkdir -p "$T/js-placebo"    && echo '{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}' > "$T/js-placebo/package.json"
mkdir -p "$T/rust"          && printf '[package]\nname="x"\n' > "$T/rust/Cargo.toml"
mkdir -p "$T/swift"         && touch "$T/swift/Package.swift"
mkdir -p "$T/gradle"        && touch "$T/gradle/gradlew" && chmod +x "$T/gradle/gradlew"
mkdir -p "$T/maven"         && touch "$T/maven/pom.xml" "$T/maven/mvnw" && chmod +x "$T/maven/mvnw"
mkdir -p "$T/dotnet"        && touch "$T/dotnet/App.csproj"
mkdir -p "$T/py-uv"         && printf '[project]\nname="x"\n' > "$T/py-uv/pyproject.toml"
mkdir -p "$T/go"            && printf 'module x\n' > "$T/go/go.mod"
mkdir -p "$T/mono/backend"  && printf '[project]\nname="x"\n' > "$T/mono/backend/pyproject.toml"
mkdir -p "$T/vacio"
check "$T/js-npm"     "npm test"
check "$T/js-bun"     "bun test"
check "$T/js-pnpm-ci" "pnpm run test:ci"
check "$T/js-placebo" ""
if command -v cargo >/dev/null 2>&1; then check "/rust" "cargo test"; else check "/rust" ""; fi
check "$T/swift"      "swift test"
check "$T/gradle"     "./gradlew test"
check "$T/maven"      "./mvnw test"
check "$T/dotnet"     "dotnet test --nologo"
check "$T/py-uv"      "uv run pytest"
check "$T/go"         "go test ./..."
check "$T/mono"       "cd '$T/mono/backend/' && uv run pytest"
check "$T/vacio"      ""
rm -rf "$T"
echo "---"; [ "$FAILED" = 0 ] && echo "TODO VERDE" || echo "HAY FALLAS"
exit "$FAILED"
