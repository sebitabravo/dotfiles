#!/usr/bin/env bash
# check-skill-deps.sh — verifica las dependencias externas declaradas en skills-lock.json.
#
# Las skills de Office (pptx/xlsx/inacap) fallan con errores cripticos cuando falta
# libreoffice o un paquete de python. Esto lo dice antes, no en medio de una tarea.
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

# Los nombres de import de python no siempre coinciden con el del paquete.
py_module() {
  case "$1" in
    "markitdown[pptx]") echo "markitdown" ;;
    python-pptx) echo "pptx" ;;
    python-docx) echo "docx" ;;
    Pillow) echo "PIL" ;;
    *) echo "$1" ;;
  esac
}

# libreoffice se invoca como 'soffice' en la mayoria de las instalaciones.
sys_binary() {
  case "$1" in
    libreoffice) echo "soffice" ;;
    poppler) echo "pdftoppm" ;;
    "node>=18") echo "node" ;;
    *) echo "$1" ;;
  esac
}

echo "Verificando dependencias de skills..."

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

if [ "$missing" -eq 0 ]; then
  echo "OK — todas las dependencias de sistema y python estan presentes."
  exit 0
fi

echo
echo "$missing dependencia(s) faltante(s). Comandos de instalacion:"
if [ "$(uname -s)" = "Darwin" ]; then
  jq -r '.install.macos[] | "  " + .' "$LOCK"
else
  jq -r '.install.debian[] | "  " + .' "$LOCK"
fi
exit 1
