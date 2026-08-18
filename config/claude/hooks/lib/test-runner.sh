#!/usr/bin/env bash
# test-runner.sh — detecta COMO corre sus tests este repo.
#
# POR QUE EXISTE: quality-gate.sh y gauntlet-stop.sh tenian cada uno su propia
# deteccion, con la misma limitacion — asumian que el manifiesto vive en la raiz
# del repo git y que el runner esta en el PATH. En un monorepo real eso falla en
# silencio y el hook reporta verde sin haber corrido nada, que es peor que no
# tener hook.
#
# Caso que lo motivo: un repo con `backend/pyproject.toml`, `landing/package.json`
# y un Makefile cuyo target es `cd backend && uv run pytest`. No hay pyproject en
# la raiz y `pytest` no esta en el PATH (vive en el venv que maneja uv), asi que
# la deteccion vieja no encontraba runner y salia 0.
#
# ORDEN DE PRECEDENCIA — un runner explicito del repo gana porque expresa la
# validacion que sus autores definieron sin imponer una herramienta de build.
# Luego vienen Make/Just y los manifiestos detectables por convencion.
#
# Setea TEST_CMD (vacio si no se pudo determinar) y TEST_CMD_SOURCE con el nivel
# de precedencia que lo eligio:
#
#   declared  el repo escribio el comando (test.sh, target de make/just)
#   inferred  lo dedujimos de un manifiesto por convencion
#
# La distincion importa para quien consuma esto: un comando `declared` es la
# definicion que dieron los autores del repo y no se reemplaza por una variante
# nuestra "equivalente pero con flag de cobertura". Uno `inferred` si, porque ya
# es una suposicion propia.

# TEST_CMD y TEST_CMD_SOURCE los consume quien sourcea este archivo
# (gauntlet-stop.sh, quality-gate.sh), no se usan aca adentro. shellcheck no
# cruza archivos y los reporta como variables muertas.
# shellcheck disable=SC2034
detect_test_cmd() {
  local root="${1:-$PWD}"
  TEST_CMD=""
  TEST_CMD_SOURCE=""

  # 1. Runner explicito para repos que no necesitan una herramienta de build.
  if [ -x "$root/test.sh" ]; then
    TEST_CMD="$root/test.sh"
    TEST_CMD_SOURCE="declared"
    return 0
  fi

  # 2. Makefile / justfile con target de test.
  if [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile" 2>/dev/null; then
    command -v make >/dev/null 2>&1 && { TEST_CMD="make test"; TEST_CMD_SOURCE="declared"; return 0; }
  fi
  if [ -f "$root/justfile" ] && grep -qE '^test:' "$root/justfile" 2>/dev/null; then
    command -v just >/dev/null 2>&1 && { TEST_CMD="just test"; TEST_CMD_SOURCE="declared"; return 0; }
  fi

  # 3. Manifiesto en la raiz o un nivel adentro. El subdirectorio cubre el
  # layout de monorepo (backend/, api/, server/) sin recorrer el repo entero.
  local d
  for d in "$root" "$root"/*/; do
    [ -d "$d" ] || continue

    _detect_js "$d" "$root" && return 0
    _detect_python "$d" "$root" && return 0
    _detect_compiled "$d" "$root" && return 0
    _detect_managed "$d" "$root" && return 0
  done

  return 1
}

# Arma TEST_CMD con el prefijo `cd` solo cuando el manifiesto no esta en la raiz.
_emit() {
  local dir="$1" root="$2" cmd="$3"
  [ "$dir" = "$root" ] && TEST_CMD="$cmd" || TEST_CMD="cd '$dir' && $cmd"
  TEST_CMD_SOURCE="inferred"
  return 0
}

# El lockfile decide el package manager, no la preferencia personal: cambiarlo
# re-resuelve el arbol entero de dependencias (rules/common/security.md).
_js_manager() {
  local dir="$1"
  if [ -f "$dir/bun.lock" ] || [ -f "$dir/bun.lockb" ]; then
    echo bun
  elif [ -f "$dir/pnpm-lock.yaml" ]; then
    echo pnpm
  elif [ -f "$dir/yarn.lock" ]; then
    echo yarn
  else
    echo npm
  fi
}

_detect_js() {
  local dir="$1" root="$2"
  [ -f "$dir/package.json" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  # Un `test` que solo imprime "no test specified" es el placeholder de `npm
  # init`: existe, sale 0, y no corre nada. Tratarlo como runner es falso verde.
  local script=""
  local candidate
  for candidate in test test:ci test:unit test:all; do
    local value
    value=$(jq -r --arg k "$candidate" '.scripts[$k] // empty' "$dir/package.json" 2>/dev/null)
    [ -n "$value" ] || continue
    case "$value" in
      *"no test specified"* | *"no tests specified"*) continue ;;
    esac
    script="$candidate"
    break
  done
  [ -n "$script" ] || return 1

  local manager
  manager=$(_js_manager "$dir")
  command -v "$manager" >/dev/null 2>&1 || return 1

  if [ "$script" = test ]; then
    _emit "$dir" "$root" "$manager test"
  else
    _emit "$dir" "$root" "$manager run $script"
  fi
}

_detect_python() {
  local dir="$1" root="$2"
  { [ -f "$dir/pyproject.toml" ] || [ -f "$dir/pytest.ini" ] || [ -f "$dir/tox.ini" ]; } || return 1

  # El runner vive en el entorno del proyecto, no en el PATH global del shell.
  local venv
  for venv in "$dir/.venv/bin/pytest" "$dir/venv/bin/pytest"; do
    [ -x "$venv" ] && _emit "$dir" "$root" "$venv" && return 0
  done
  [ -f "$dir/pyproject.toml" ] && command -v uv >/dev/null 2>&1 &&
    _emit "$dir" "$root" "uv run pytest" && return 0
  [ -f "$dir/poetry.lock" ] && command -v poetry >/dev/null 2>&1 &&
    _emit "$dir" "$root" "poetry run pytest" && return 0
  command -v pytest >/dev/null 2>&1 && _emit "$dir" "$root" "pytest" && return 0
  return 1
}

_detect_compiled() {
  local dir="$1" root="$2"
  [ -f "$dir/go.mod" ] && command -v go >/dev/null 2>&1 &&
    _emit "$dir" "$root" "go test ./..." && return 0
  [ -f "$dir/Cargo.toml" ] && command -v cargo >/dev/null 2>&1 &&
    _emit "$dir" "$root" "cargo test" && return 0
  [ -f "$dir/Package.swift" ] && command -v swift >/dev/null 2>&1 &&
    _emit "$dir" "$root" "swift test" && return 0
  # El wrapper versionado del repo le gana al binario global: fija la version
  # de la herramienta y no depende de lo que este instalado en la maquina.
  [ -x "$dir/gradlew" ] && _emit "$dir" "$root" "./gradlew test" && return 0
  if [ -f "$dir/pom.xml" ]; then
    [ -x "$dir/mvnw" ] && _emit "$dir" "$root" "./mvnw test" && return 0
    command -v mvn >/dev/null 2>&1 && _emit "$dir" "$root" "mvn test" && return 0
  fi
  return 1
}

_detect_managed() {
  local dir="$1" root="$2"

  if [ -f "$dir/composer.json" ] && command -v composer >/dev/null 2>&1 &&
    command -v jq >/dev/null 2>&1 &&
    jq -e '.scripts.test' "$dir/composer.json" >/dev/null 2>&1; then
    _emit "$dir" "$root" "composer run-script test" && return 0
  fi

  if [ -f "$dir/Gemfile" ] && command -v bundle >/dev/null 2>&1; then
    [ -d "$dir/spec" ] && _emit "$dir" "$root" "bundle exec rspec" && return 0
    [ -d "$dir/test" ] && _emit "$dir" "$root" "bundle exec rake test" && return 0
  fi

  # Glob explicito, no `ls *.sln *.csproj`: ls falla entero si uno de los dos
  # patrones no matchea, aunque el otro si — y el proyecto quedaba sin detectar.
  if command -v dotnet >/dev/null 2>&1; then
    local project
    for project in "$dir"/*.sln "$dir"/*.csproj; do
      [ -f "$project" ] || continue
      _emit "$dir" "$root" "dotnet test --nologo"
      return 0
    done
  fi

  return 1
}
