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
# ORDEN DE PRECEDENCIA — el Makefile primero, a proposito: si el repo declara un
# target `test`, esa es la definicion que sus autores dieron de "correr los
# tests", incluidos el venv, los flags de cobertura y los markers. Adivinar el
# comando por nuestra cuenta es reimplementar peor algo que ya esta escrito.
#
# Setea TEST_CMD (vacio si no se pudo determinar).

# TEST_CMD lo consume quien sourcea este archivo (gauntlet-stop.sh), no se usa
# aca adentro. shellcheck no cruza archivos y lo reporta como variable muerta.
# shellcheck disable=SC2034
detect_test_cmd() {
  local root="${1:-$PWD}"
  TEST_CMD=""

  # 1. Makefile / justfile con target de test.
  if [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile" 2>/dev/null; then
    command -v make >/dev/null 2>&1 && { TEST_CMD="make test"; return 0; }
  fi
  if [ -f "$root/justfile" ] && grep -qE '^test:' "$root/justfile" 2>/dev/null; then
    command -v just >/dev/null 2>&1 && { TEST_CMD="just test"; return 0; }
  fi

  # 2. Manifiesto en la raiz o un nivel adentro. El subdirectorio cubre el
  # layout de monorepo (backend/, api/, server/) sin recorrer el repo entero.
  local d
  for d in "$root" "$root"/*/; do
    [ -d "$d" ] || continue

    if [ -f "$d/package.json" ] && command -v jq >/dev/null 2>&1 &&
      jq -e '.scripts.test' "$d/package.json" >/dev/null 2>&1; then
      [ "$d" = "$root" ] && TEST_CMD="npm test" || TEST_CMD="cd '$d' && npm test"
      return 0
    fi

    if [ -f "$d/pyproject.toml" ] || [ -f "$d/pytest.ini" ]; then
      # uv/poetry: el runner vive en el entorno del proyecto, no en el PATH
      # global del shell.
      local py=""
      if [ -f "$d/pyproject.toml" ] && command -v uv >/dev/null 2>&1; then
        py="uv run pytest"
      elif [ -f "$d/poetry.lock" ] && command -v poetry >/dev/null 2>&1; then
        py="poetry run pytest"
      fi
      if [ -n "$py" ]; then
        [ "$d" = "$root" ] && TEST_CMD="$py" || TEST_CMD="cd '$d' && $py"
        return 0
      fi
    fi

    if [ -f "$d/go.mod" ] && command -v go >/dev/null 2>&1; then
      [ "$d" = "$root" ] && TEST_CMD="go test ./..." || TEST_CMD="cd '$d' && go test ./..."
      return 0
    fi

  done

  return 1
}
