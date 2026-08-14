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
  echo "check-skill-deps: jq no esta instalado; no puedo leer skills-lock.json" >&2
  exit 1
fi
if [ ! -f "$LOCK" ]; then
  echo "check-skill-deps: falta $LOCK" >&2
  exit 1
fi

missing=0
report() {
  missing=$((missing + 1))
  echo "  FALTA  $1  (skill: $2)"
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

echo "Verificando dependencias de skills..."

# Version minima de python por skill. python3 -c "import X" solo prueba que el
# modulo importa con la version de python3 que resuelva el PATH; una skill puede
# tener requisitos adicionales dentro del propio proyecto.
PY_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
while IFS=$'\t' read -r skill min_py; do
  [ -z "$skill" ] || [ -z "$min_py" ] && continue
  if [ "$(printf '%s\n' "$min_py" "$PY_VERSION" | sort -V | head -1)" != "$min_py" ]; then
    missing=$((missing + 1))
    echo "  FALTA  python $min_py+ (system python3 es $PY_VERSION)  (skill: $skill)"
  fi
done < <(jq -r '.skills | to_entries[] | select(.value.python_version) | [.key, .value.python_version] | @tsv' "$LOCK")

while IFS=$'\t' read -r skill kind dep; do
  [ -z "$skill" ] && continue
  case "$kind" in
    python)
      mod=$(py_module "$dep")
      python3 -c "import $mod" >/dev/null 2>&1 || report "python: $dep" "$skill"
      ;;
    system)
      bin=$(sys_binary "$dep")
      command -v "$bin" >/dev/null 2>&1 || report "system: $dep ($bin)" "$skill"
      ;;
    node)
      # Las deps de node se instalan por proyecto, no global: solo se informan.
      [ "$QUIET" -eq 1 ] || echo "  info   node: $dep se instala por proyecto (skill: $skill)"
      ;;
  esac
done < <(jq -r '.skills | to_entries[] | .key as $s | .value.deps // {} | to_entries[] | .key as $k | .value[] | [$s, $k, .] | @tsv' "$LOCK")

# Frontmatter de cada skill. Un SKILL.md sin `name:` o sin `description:` no lo
# carga el harness: la skill queda instalada, invisible, y no falla nunca de
# forma ruidosa. Chequear las deps de una skill que no carga no sirve de nada.
SKILLS_ROOT="${SKILLS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills}"
if [ -d "$SKILLS_ROOT" ]; then
  invalid=0
  while IFS= read -r skill_file; do
    if ! grep -q '^name:' "$skill_file" || ! grep -q '^description:' "$skill_file"; then
      echo "  invalid  frontmatter incompleto: ${skill_file#"$SKILLS_ROOT/"}"
      invalid=$((invalid + 1))
    fi
  done < <(find "$SKILLS_ROOT" -name SKILL.md -maxdepth 2 -type f)
  if [ "$invalid" -gt 0 ]; then
    echo "$invalid skill(s) con frontmatter invalido: sin 'name:' y 'description:' el harness no las carga."
    missing=$((missing + invalid))
  fi
fi

if [ "$missing" -eq 0 ]; then
  echo "OK — dependencias presentes y frontmatter de skills valido."
  exit 0
fi

echo
echo "$missing dependencia(s) faltante(s). No se instala nada automaticamente; revisa el entorno del proyecto o reporta la limitacion del host."
exit 1
