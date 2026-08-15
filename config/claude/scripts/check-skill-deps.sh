#!/usr/bin/env bash
# check-skill-deps.sh — verifica las dependencias externas declaradas en skills-lock.json.
#
# Las dependencias declaradas deben poder verificarse antes de una tarea; las
# dependencias que solo viven dentro de un proyecto se informan, no se instalan.
#
# Uso: bash scripts/check-skill-deps.sh [--quiet]
set -uo pipefail

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$DIR/skills-lock.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "check-skill-deps: jq is not installed; cannot read skills-lock.json" >&2
  exit 1
fi
if [ ! -f "$LOCK" ]; then
  echo "check-skill-deps: $LOCK is missing" >&2
  exit 1
fi

missing=0
report() {
  missing=$((missing + 1))
  echo "  MISSING  $1  (skill: $2)"
}

# Los nombres declarativos suelen coincidir con el import en el lock activo.
py_module() {
  echo "$1"
}

# Algunos locks pueden declarar un nombre distinto al binario; los locks
# actuales usan nombres ejecutables directamente.
sys_binary() {
  echo "$1"
}

echo "Checking skill dependencies..."

# Version minima de python por skill. No asumas que el primer python3 del PATH
# funciona: en macOS un shim pyenv roto puede abortar el proceso antes de
# devolver una version y producir un falso `0.0`. Preferimos ese interprete si
# responde; si no, usamos el Python administrado por uv.
PYTHON_BIN="${PYTHON_BIN:-}"
if [ -n "$PYTHON_BIN" ] && ! "$PYTHON_BIN" -c 'import sys' >/dev/null 2>&1; then
  PYTHON_BIN=""
fi
if [ -z "$PYTHON_BIN" ] && command -v uv >/dev/null 2>&1; then
  candidate=$(uv python find 3.12 2>/dev/null || true)
  if [ -n "$candidate" ] && "$candidate" -c 'import sys' >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
  fi
fi
if [ -z "$PYTHON_BIN" ] && command -v python3 >/dev/null 2>&1 \
  && python3 -c 'import sys' >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi
if [ -z "$PYTHON_BIN" ] && [ -x /usr/bin/python3 ] \
  && /usr/bin/python3 -c 'import sys' >/dev/null 2>&1; then
  PYTHON_BIN=/usr/bin/python3
fi

PY_VERSION="0.0"
if [ -n "$PYTHON_BIN" ]; then
  PY_VERSION=$("$PYTHON_BIN" -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
fi
echo "  python $PY_VERSION via ${PYTHON_BIN:-unavailable}"
while IFS=$'\t' read -r skill min_py; do
  [ -z "$skill" ] || [ -z "$min_py" ] && continue
  if [ "$(printf '%s\n' "$min_py" "$PY_VERSION" | sort -V | head -1)" != "$min_py" ]; then
    missing=$((missing + 1))
    echo "  MISSING  python $min_py+ (system python3 is $PY_VERSION)  (skill: $skill)"
  fi
done < <(jq -r '.skills | to_entries[] | select(.value.python_version) | [.key, .value.python_version] | @tsv' "$LOCK")

while IFS=$'\t' read -r skill kind dep; do
  [ -z "$skill" ] && continue
  case "$kind" in
    python)
      mod=$(py_module "$dep")
      if [ -z "$PYTHON_BIN" ] || ! "$PYTHON_BIN" -c "import $mod" >/dev/null 2>&1; then
        report "python: $dep" "$skill"
      fi
      ;;
    system)
      bin=$(sys_binary "$dep")
      command -v "$bin" >/dev/null 2>&1 || report "system: $dep ($bin)" "$skill"
      ;;
    node)
      # Las deps de node se instalan por proyecto, no global: solo se informan.
      [ "$QUIET" -eq 1 ] || echo "  info   node: $dep is installed per project (skill: $skill)"
      ;;
  esac
done < <(jq -r '.skills | to_entries[] | .key as $s | .value.deps // {} | to_entries[] | .key as $k | .value[] | [$s, $k, .] | @tsv' "$LOCK")

# Las skills que traen un package.json propio se instalan bajo demanda en la
# carpeta de la skill. No las instales durante un hook: informa si todavía no
# están provisionadas para evitar que un OK oculte una capacidad pendiente.
local_node_info=0
SKILLS_ROOT_FOR_PACKAGES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)"
while IFS= read -r package_json; do
  [ -f "$package_json" ] || continue
  skill_dir=$(dirname "$package_json")
  skill_name=$(basename "$skill_dir")
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    dep_path="$skill_dir/node_modules/$dep"
    if [ ! -e "$dep_path" ]; then
      local_node_info=$((local_node_info + 1))
      [ "$QUIET" -eq 1 ] || echo "  info   local node: $dep is not provisioned (skill: $skill_name; run npm install inside the skill when it applies)"
    fi
  done < <(jq -r '.dependencies // {} | keys[]' "$package_json")
done < <(find "$SKILLS_ROOT_FOR_PACKAGES" -mindepth 2 -maxdepth 2 -name package.json -type f -print)

# Algunas skills tienen capacidades opcionales (Office, metadata, imágenes o
# conversión) que no deben convertir el host en una instalación global. Se
# reportan de forma explícita para que "OK" nunca oculte que una capacidad
# bajo demanda todavía no está provisionada.
optional_info=0
while IFS=$'\t' read -r skill dep; do
  [ -z "$skill" ] || [ -z "$dep" ] && continue
  if [ -z "$PYTHON_BIN" ] || ! "$PYTHON_BIN" -c "import $dep" >/dev/null 2>&1; then
    optional_info=$((optional_info + 1))
    [ "$QUIET" -eq 1 ] || echo "  info   optional python: $dep is not provisioned (skill: $skill; resolve with uv --with when it applies)"
  fi
done < <(jq -r '.skills | to_entries[] | .key as $s | .value.optional_python // [] | .[] | [$s, .] | @tsv' "$LOCK")

while IFS=$'\t' read -r skill dep; do
  [ -z "$skill" ] || [ -z "$dep" ] && continue
  if ! command -v "$dep" >/dev/null 2>&1; then
    optional_info=$((optional_info + 1))
    [ "$QUIET" -eq 1 ] || echo "  info   optional binary: $dep is not provisioned (skill: $skill; install on demand only)"
  fi
done < <(jq -r '.skills | to_entries[] | .key as $s | .value.optional_system // [] | .[] | [$s, .] | @tsv' "$LOCK")

# Frontmatter de cada skill. Un SKILL.md sin `name:` o sin `description:` no lo
# carga el harness: la skill queda instalada, invisible, y no falla nunca de
# forma ruidosa. Chequear las deps de una skill que no carga no sirve de nada.
SKILLS_ROOT="${SKILLS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills}"
if [ -d "$SKILLS_ROOT" ]; then
  invalid=0
  while IFS= read -r skill_file; do
    if ! grep -q '^name:' "$skill_file" || ! grep -q '^description:' "$skill_file"; then
      echo "  invalid  incomplete frontmatter: ${skill_file#"$SKILLS_ROOT/"}"
      invalid=$((invalid + 1))
    fi
  done < <(find "$SKILLS_ROOT" -name SKILL.md -maxdepth 2 -type f)
  if [ "$invalid" -gt 0 ]; then
    echo "$invalid skill(s) with invalid frontmatter: without 'name:' and 'description:' the harness does not load them."
    missing=$((missing + invalid))
  fi
fi

if [ "$missing" -eq 0 ]; then
  if [ "$local_node_info" -gt 0 ] || [ "$optional_info" -gt 0 ]; then
    echo "OK — required lock dependencies and frontmatter are valid; on-demand capabilities are reported above."
  else
    echo "OK — dependencies present and skill frontmatter valid."
  fi
  exit 0
fi

echo
echo "$missing missing dependency(ies). Nothing is installed automatically; check the project environment or report the host limitation."
exit 1
