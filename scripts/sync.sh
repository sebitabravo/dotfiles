#!/bin/bash
# sync.sh — mantiene el repo y las copias desplegadas en el home alineados.
#
# El problema que resuelve: config/claude vive en el repo pero Claude Code lee
# ~/.claude. Sin un mecanismo, las dos copias divergen y nadie se entera hasta
# que una sesion arranca con reglas viejas. Llego a haber 67 archivos distintos
# entre ambas, con la copia desplegada MAS NUEVA que el repo — al reves de lo
# que dice CLAUDE.md.
#
# Que archivos maneja: los que git ya trackea, y solo esos. La lista sale de
# `git ls-files`, no de un array escrito a mano. Un allowlist manual habria
# tenido el mismo destino que el resto: envejecer sin que nadie lo note. Como
# efecto, todo el estado runtime del home (cache/, projects/, history.jsonl,
# plugins/, backups/) queda fuera sin necesidad de enumerarlo.
#
#   ./scripts/sync.sh            # status — que difiere, sin tocar nada
#   ./scripts/sync.sh deploy     # repo -> home
#   ./scripts/sync.sh pull       # home -> repo
#   ./scripts/sync.sh deploy -n  # dry-run

set -uo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO" || exit 1

# origen_en_repo:destino_en_home
MAPPINGS=(
  "config/claude:$HOME/.claude"
  "config/opencode:$HOME/.config/opencode"
  "config/codex:$HOME/.codex"
  "config/fastfetch:$HOME/.config/fastfetch"
  "git-hooks:$HOME/.git-hooks"
)

# Dotfiles sueltos de la raiz del repo, todos van directo al home.
ROOT_FILES=(.zshrc .zshenv .zprofile .p10k.zsh .gitconfig)

MODE="${1:-status}"
DRY=""
[ "${2:-}" = "-n" ] || [ "${2:-}" = "--dry-run" ] && DRY="1"

case "$MODE" in
  status | deploy | pull) ;;
  *)
    echo "uso: $0 [status|deploy|pull] [-n]" >&2
    exit 2
    ;;
esac

DIFF_COUNT=0
MISSING_COUNT=0
COPIED_COUNT=0
FAILED_COUNT=0

# copy_one <src> <dst> — copia preservando el modo, creando el arbol destino.
# Los symlinks se recrean como symlink: config/opencode/rules/common apunta a
# ../../claude/rules/common, y un cp -p lo dereferencia y copia el directorio
# entero, rompiendo el vinculo que evita duplicar las reglas.
copy_one() {
  local src="$1" dst="$2"
  if [ -n "$DRY" ]; then
    echo "  [dry-run] $src -> $dst"
    return
  fi
  if ! mkdir -p "$(dirname "$dst")" 2>/dev/null; then
    echo "  ! no se pudo crear $(dirname "$dst")" >&2
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1
  fi

  if [ -L "$src" ]; then
    # Si el destino es un directorio REAL, ln -sfn no lo reemplaza: crea el
    # link ADENTRO. El -n solo cubre el caso symlink-a-directorio. Sin este
    # chequeo queda un common/common roto y el script lo reporta como copiado.
    # Es el caso de ~/.config/opencode/rules/common, que hoy es una copia real
    # donde el repo tiene un symlink a ../../claude/rules/common.
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      echo "  ! $dst es un directorio real y el repo lo tiene como symlink." >&2
      echo "    Borralo a mano (rm -rf) si querés que quede linkeado." >&2
      FAILED_COUNT=$((FAILED_COUNT + 1))
      return 1
    fi
    if ! ln -sfn "$(readlink "$src")" "$dst" 2>/dev/null; then
      echo "  ! no se pudo crear el symlink $dst" >&2
      FAILED_COUNT=$((FAILED_COUNT + 1))
      return 1
    fi
  elif ! cp -p "$src" "$dst" 2>/dev/null; then
    echo "  ! fallo la copia a $dst" >&2
    FAILED_COUNT=$((FAILED_COUNT + 1))
    return 1
  fi
  COPIED_COUNT=$((COPIED_COUNT + 1))
}

# same_content <a> <b> — cmp no sirve con symlinks: sigue el link y con uno que
# apunta a un directorio falla con "Is a directory". Se comparan los targets.
same_content() {
  local a="$1" b="$2"
  if [ -L "$a" ] || [ -L "$b" ]; then
    [ -L "$a" ] && [ -L "$b" ] && [ "$(readlink "$a")" = "$(readlink "$b")" ]
    return
  fi
  cmp -s "$a" "$b"
}

# process <ruta_repo> <ruta_home>
process() {
  local repo_path="$1" home_path="$2"

  # -e sigue el symlink y da falso en uno roto; -L lo detecta igual.
  if [ ! -e "$home_path" ] && [ ! -L "$home_path" ] && [ "$MODE" = "pull" ]; then
    return
  fi

  if [ ! -e "$home_path" ] && [ ! -L "$home_path" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    [ "$MODE" = "status" ] && echo "  falta en home: $repo_path"
    [ "$MODE" = "deploy" ] && { echo "  + $repo_path"; copy_one "$repo_path" "$home_path"; }
    return
  fi

  same_content "$repo_path" "$home_path" && return

  DIFF_COUNT=$((DIFF_COUNT + 1))
  case "$MODE" in
    status)
      # Cual de las dos es mas nueva es justo el dato que falta cuando se decide
      # en que direccion sincronizar.
      if [ "$home_path" -nt "$repo_path" ]; then
        echo "  difiere (home mas nuevo):  $repo_path"
      else
        echo "  difiere (repo mas nuevo):  $repo_path"
      fi
      ;;
    deploy)
      echo "  -> $repo_path"
      copy_one "$repo_path" "$home_path"
      ;;
    pull)
      echo "  <- $repo_path"
      copy_one "$home_path" "$repo_path"
      ;;
  esac
}

echo "modo: $MODE${DRY:+ (dry-run)}"
echo

for mapping in "${MAPPINGS[@]}"; do
  repo_dir="${mapping%%:*}"
  home_dir="${mapping#*:}"

  [ -d "$repo_dir" ] || continue
  echo "$repo_dir -> $home_dir"

  # -z: nombres separados por NUL, unico modo seguro con espacios en la ruta.
  while IFS= read -r -d '' f; do
    process "$f" "$home_dir/${f#"$repo_dir"/}"
  done < <(git ls-files -z "$repo_dir")
done

echo "raiz -> $HOME"
for f in "${ROOT_FILES[@]}"; do
  [ -f "$f" ] || continue
  process "$f" "$HOME/$f"
done

echo
if [ "$MODE" = "status" ]; then
  echo "$DIFF_COUNT distintos, $MISSING_COUNT sin desplegar"
  # Salida 1 con drift: sirve para encadenarlo en un check.
  [ "$DIFF_COUNT" -gt 0 ] || [ "$MISSING_COUNT" -gt 0 ] && exit 1
  echo "en sync"
else
  echo "$COPIED_COUNT copiados, $FAILED_COUNT fallidos"
  [ "$FAILED_COUNT" -gt 0 ] && exit 1
fi
exit 0
