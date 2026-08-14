#!/usr/bin/env bash
# quality-gate.test.sh — prueba la exencion de "commit sin codigo" del gate.
#
# Escenarios: un commit que solo toca CI/config/docs sale 0 sin exigir test
# runner; un commit con codigo (.py/.sh) o mezclado con codigo cae al bloqueo
# (exit 2) cuando el repo no tiene runner, igual que antes.
GATE=/Users/sebastian/Developer/dotfiles/config/claude/hooks/quality-gate.sh
T=$(mktemp -d)
FAILED=0

run_gate() {
  # $1 = repo, $2 = mensaje del commit, $3.. = archivos a stagear (relativos).
  local repo="$1" msg="$2"; shift 2
  (
    cd "$repo" || exit 99
    git add "$@" >/dev/null 2>&1
    jq -n --arg cmd "git commit -m \"$msg\"" --arg cwd "$repo" \
      '{tool_name:"Bash",tool_input:{command:$cmd},cwd:$cwd}' |
      "$GATE" >/dev/null 2>&1
  )
}

expect() {
  local desc="$1" expected="$2" got="$3"
  if [ "$expected" = "$got" ]; then
    printf 'PASS  %-46s (exit %s)\n' "$desc" "$got"
  else
    printf 'FAIL  %-46s exit %s, esperaba %s\n' "$desc" "$got" "$expected"
    FAILED=1
  fi
}

mkrepo() { mkdir -p "$1"; git -C "$1" init -q; }

mkrepo "$T/ci-only"; mkdir -p "$T/ci-only/.github/workflows"; echo "name: CodeQL" > "$T/ci-only/.github/workflows/codeql.yml"
mkrepo "$T/docs";    echo "# README" > "$T/docs/README.md"; mkdir -p "$T/docs/docs"; echo "ADR" > "$T/docs/docs/ADR-001.md"
mkrepo "$T/code";    echo "print('x')" > "$T/code/app.py"
mkrepo "$T/mixed";   mkdir -p "$T/mixed/.github/workflows"; echo "name: CodeQL" > "$T/mixed/.github/workflows/codeql.yml"; echo "print('x')" > "$T/mixed/app.py"
mkrepo "$T/script";  printf '#!/bin/bash\necho hi\n' > "$T/script/run.sh"

run_gate "$T/ci-only" "ci(security): agrega CodeQL" .github/workflows/codeql.yml
expect "solo .github/*.yml pasa sin gate" 0 "$?"
run_gate "$T/docs" "docs: agrega ADR" README.md docs/ADR-001.md
expect "solo .md pasa sin gate" 0 "$?"
run_gate "$T/code" "feat: app" app.py
expect "un .py sin runner bloquea" 2 "$?"
run_gate "$T/mixed" "feat: mezcla" .github/workflows/codeql.yml app.py
expect "yml + py bloquea (no exento)" 2 "$?"
run_gate "$T/script" "feat: script" run.sh
expect "un .sh sin runner bloquea" 2 "$?"

# Manifiestos y lockfiles: matchean *.json/*.toml/*.lock pero NO son config
# estatica, son el arbol de dependencias. Un bump de version no toca una linea
# de codigo propio y rompe la build igual: es el commit donde MAS hace falta
# que corra la suite. Si alguien vuelve a meter *.json en la whitelist sin la
# lista negra delante, estos cinco casos se ponen rojos.
mkrepo "$T/pkg";   echo '{"name":"x"}' > "$T/pkg/package.json"
mkrepo "$T/lock";  echo '{}' > "$T/lock/package.json"; echo '{"lockfileVersion":3}' > "$T/lock/package-lock.json"
mkrepo "$T/pyp";   printf '[project]\nname="x"\n' > "$T/pyp/pyproject.toml"
mkrepo "$T/cargo"; printf '[package]\nname="x"\n' > "$T/cargo/Cargo.toml"
mkrepo "$T/gomod"; printf 'module x\n' > "$T/gomod/go.mod"
mkrepo "$T/tscfg"; echo '{"compilerOptions":{}}' > "$T/tscfg/tsconfig.json"

run_gate "$T/pkg" "chore: bump dependencia" package.json
expect "package.json solo NO se exime" 2 "$?"
run_gate "$T/lock" "chore: lockfile" package-lock.json
expect "package-lock.json solo NO se exime" 2 "$?"
run_gate "$T/pyp" "chore: deps" pyproject.toml
expect "pyproject.toml solo NO se exime" 2 "$?"
run_gate "$T/cargo" "chore: deps" Cargo.toml
expect "Cargo.toml solo NO se exime" 2 "$?"
run_gate "$T/gomod" "chore: deps" go.mod
expect "go.mod solo NO se exime" 2 "$?"
run_gate "$T/tscfg" "chore: tsconfig" tsconfig.json
expect "tsconfig.json solo NO se exime" 2 "$?"

# Los patrones sin extension se comparan por basename, no por ruta completa:
# antes `sub/.gitignore` no matcheaba `.gitignore` y un commit de solo-docs
# quedaba bloqueado por vivir en un subdirectorio.
mkrepo "$T/subgit"; mkdir -p "$T/subgit/sub"; echo "node_modules" > "$T/subgit/sub/.gitignore"
mkrepo "$T/sublic"; mkdir -p "$T/sublic/pkg"; echo "MIT" > "$T/sublic/pkg/LICENSE"

run_gate "$T/subgit" "chore: ignore" sub/.gitignore
expect "sub/.gitignore se exime igual que en raiz" 0 "$?"
run_gate "$T/sublic" "docs: licencia" pkg/LICENSE
expect "pkg/LICENSE se exime igual que en raiz" 0 "$?"

rm -rf "$T"
echo "---"; [ "$FAILED" = 0 ] && echo "TODO VERDE" || echo "HAY FALLAS"
exit "$FAILED"
