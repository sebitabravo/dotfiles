#!/usr/bin/env bash
# rdd.sh — Receipt Driven Development, version minima y enforceable.
#
# LA IDEA: la opinion de la IA ("esto funciona") no autoriza un commit. Lo
# autoriza un recibo atado al contenido exacto que se va a commitear. Si los
# bytes cambian despues del review, el recibo deja de valer solo.
#
# NO es un puerto de gentle-ai: ese sistema tiene contratos versionados,
# lineages y CAS. Aca esta lo unico que se puede enforcear desde un hook y sin
# binarios extra.
#
# FLUJO
#   1. rdd freeze              congela los bytes staged -> candidate hash
#   2. (review / tests)
#   3. rdd receipt "<cmd>"     corre la evidencia y emite el recibo atado al hash
#   4. git commit              quality-gate.sh valida el recibo
#
# KILL SWITCH
#   rdd off / rdd on           por repo. Apagado = quality-gate solo avisa.
set -uo pipefail

STATE_DIR=".claude-rdd"
CANDIDATE="$STATE_DIR/candidate.json"
RECEIPT="$STATE_DIR/receipt.json"
SWITCH="$STATE_DIR/enabled"

die() {
  echo "rdd: $1" >&2
  exit 1
}

repo_root() { git rev-parse --show-toplevel 2>/dev/null || die "no es un repo git"; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi
}

# Hash del candidato = diff staged exacto + manifiesto ordenado de paths.
# El manifiesto entra aparte para que renombrar un archivo cambie el hash aunque
# el contenido del diff se vea igual.
candidate_hash() {
  {
    git diff --cached --no-color
    printf '\n--- manifest ---\n'
    git diff --cached --name-only | LC_ALL=C sort
  } | sha
}

staged_line_count() { git diff --cached --numstat | awk '{a+=$1; d+=$2} END {print (a+d)+0}'; }

json_get() { grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'; }

cmd_freeze() {
  local root
  root=$(repo_root)
  cd "$root" || die "no pude entrar a $root"
  git diff --cached --quiet && die "no hay nada staged que congelar"

  local max_fix="${1:-40}"
  mkdir -p "$STATE_DIR"
  local h files n
  h=$(candidate_hash)
  n=$(staged_line_count)
  files=$(git diff --cached --name-only | LC_ALL=C sort | tr '\n' ' ')

  cat >"$CANDIDATE" <<EOF
{
  "hash": "$h",
  "lines_changed": $n,
  "max_fix_lines": $max_fix,
  "files": "$files",
  "frozen_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  rm -f "$RECEIPT"
  echo "candidato congelado"
  echo "  hash          $h"
  echo "  archivos      $(git diff --cached --name-only | wc -l | tr -d ' ')"
  echo "  lineas        $n"
  echo "  techo de fix  $max_fix lineas"
  echo
  echo "Revisa AHORA sobre estos bytes. Si tocas algo, el hash cambia y el recibo no va a validar."
}

cmd_receipt() {
  local root
  root=$(repo_root)
  cd "$root" || die "no pude entrar a $root"
  [ -f "$CANDIDATE" ] || die "no hay candidato congelado. Corre: rdd freeze"

  local frozen now
  frozen=$(json_get "$CANDIDATE" hash)
  now=$(candidate_hash)

  # ORDEN IMPORTANTE: primero el techo, despues el hash.
  # Cualquier correccion cambia el hash, asi que si el hash se chequeara primero
  # el techo nunca se evaluaria — seria codigo muerto. El techo es el limite
  # grueso (anti sobre-ingenieria) y merece el mensaje claro; el hash es la
  # regla fina de "volve a congelar antes de pedir el recibo".
  local frozen_lines now_lines max delta
  frozen_lines=$(grep -o '"lines_changed"[[:space:]]*:[[:space:]]*[0-9]*' "$CANDIDATE" | grep -o '[0-9]*$')
  max=$(grep -o '"max_fix_lines"[[:space:]]*:[[:space:]]*[0-9]*' "$CANDIDATE" | grep -o '[0-9]*$')
  now_lines=$(staged_line_count)
  delta=$((now_lines > frozen_lines ? now_lines - frozen_lines : frozen_lines - now_lines))
  if [ "$delta" -gt "$max" ]; then
    die "la correccion movio $delta lineas y el techo es $max. Eso ya no es un fix acotado: achicalo, o congela un candidato nuevo a proposito."
  fi

  if [ "$frozen" != "$now" ]; then
    echo "rdd: los bytes cambiaron desde el freeze." >&2
    echo "  congelado: $frozen" >&2
    echo "  ahora:     $now" >&2
    echo "  El fix entra en el techo, pero el review cubrio otro contenido." >&2
    echo "  Volve a congelar y revisa el delta antes de pedir el recibo." >&2
    exit 1
  fi

  local evidence_cmd="${1:-}"
  [ -n "$evidence_cmd" ] || die "falta la evidencia. Uso: rdd receipt '<comando de tests>'"

  echo "corriendo evidencia: $evidence_cmd"
  local out rc
  out=$(eval "$evidence_cmd" 2>&1)
  rc=$?
  printf '%s\n' "$out" | tail -20

  if [ "$rc" -ne 0 ]; then
    echo
    die "la evidencia fallo (exit $rc). Sin evidencia verde no hay recibo."
  fi

  mkdir -p "$STATE_DIR"
  cat >"$RECEIPT" <<EOF
{
  "candidate_hash": "$frozen",
  "evidence_command": "$(printf '%s' "$evidence_cmd" | sed 's/"/\\"/g')",
  "evidence_exit_code": $rc,
  "lines_changed": $now_lines,
  "issued_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  echo
  echo "RECIBO EMITIDO — commit autorizado para el hash $frozen"
}

# Usado por quality-gate.sh. Silencioso; el exit code es el contrato.
#   0 = autorizado (o RDD apagado)   1 = sin recibo   2 = recibo de otros bytes
cmd_verify() {
  local root
  root=$(repo_root)
  cd "$root" || return 0
  [ -f "$SWITCH" ] || return 0
  [ -f "$RECEIPT" ] || return 1
  local rh
  rh=$(json_get "$RECEIPT" candidate_hash)
  [ "$rh" = "$(candidate_hash)" ] || return 2
  return 0
}

cmd_status() {
  local root
  root=$(repo_root)
  cd "$root" || die "no pude entrar a $root"
  if [ -f "$SWITCH" ]; then echo "RDD: ENCENDIDO (bloquea commits sin recibo)"; else echo "RDD: apagado (quality-gate solo avisa)"; fi
  if [ -f "$CANDIDATE" ]; then
    local frozen
    frozen=$(json_get "$CANDIDATE" hash)
    echo "candidato: $frozen"
    [ "$frozen" = "$(candidate_hash)" ] && echo "  los bytes staged COINCIDEN" || echo "  los bytes staged CAMBIARON desde el freeze"
  else
    echo "candidato: ninguno"
  fi
  if [ -f "$RECEIPT" ]; then
    cmd_verify && echo "recibo: VALIDO" || echo "recibo: presente pero para otros bytes"
  else
    echo "recibo: ninguno"
  fi
}

cmd_on() {
  local root
  root=$(repo_root)
  mkdir -p "$root/$STATE_DIR" && touch "$root/$SWITCH"
  grep -qxF "$STATE_DIR/" "$root/.gitignore" 2>/dev/null || printf '%s/\n' "$STATE_DIR" >>"$root/.gitignore"
  echo "RDD encendido en $root. .gitignore actualizado."
}

cmd_off() {
  local root
  root=$(repo_root)
  rm -f "$root/$SWITCH"
  echo "RDD apagado en $root. Los commits ya no requieren recibo."
}

case "${1:-}" in
  freeze) shift && cmd_freeze "$@" ;;
  receipt) shift && cmd_receipt "$@" ;;
  verify) cmd_verify ;;
  status) cmd_status ;;
  on) cmd_on ;;
  off) cmd_off ;;
  *)
    cat <<'EOF'
rdd.sh — Receipt Driven Development

  rdd freeze [max_fix_lines]   congela los bytes staged (default: techo 40)
  rdd receipt '<cmd tests>'    corre la evidencia y emite el recibo
  rdd verify                   exit 0 autorizado / 1 sin recibo / 2 otros bytes
  rdd status                   estado actual
  rdd on | rdd off             kill switch por repo

La regla: sin recibo atado a los bytes exactos, no hay commit.
EOF
    exit 2
    ;;
esac
