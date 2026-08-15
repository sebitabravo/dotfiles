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

repo_root() { git rev-parse --show-toplevel 2>/dev/null || die "not a git repo"; }

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
  cd "$root" || die "could not enter $root"
  git diff --cached --quiet && die "there is nothing staged to freeze"

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
  echo "candidate frozen"
  echo "  hash          $h"
  echo "  files         $(git diff --cached --name-only | wc -l | tr -d ' ')"
  echo "  lines         $n"
  echo "  fix ceiling   $max_fix lines"
  echo
  echo "Review those bytes NOW. If you touch anything, the hash changes and the receipt will not validate."
}

cmd_receipt() {
  local root
  root=$(repo_root)
  cd "$root" || die "could not enter $root"
  [ -f "$CANDIDATE" ] || die "there is no frozen candidate. Run: rdd freeze"

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
    die "the correction moved $delta lines and the ceiling is $max. That is no longer a bounded fix: shrink it, or freeze a new candidate on purpose."
  fi

  if [ "$frozen" != "$now" ]; then
    echo "rdd: the bytes changed since the freeze." >&2
    echo "  frozen: $frozen" >&2
    echo "  now:    $now" >&2
    echo "  The fix fits under the ceiling, but the review covered other content." >&2
    echo "  Freeze again and review the delta before asking for the receipt." >&2
    exit 1
  fi

  # argv, NO eval. Con eval, `rdd receipt 'npm test || true'` emitia recibo con
  # la suite en rojo: el `||` armaba una segunda capa de comando y el exit 0 lo
  # ponia el `true`, no los tests. Eso rompia la propiedad que justifica RDD
  # entera — "no se emite recibo salvo que la evidencia salga 0".
  # Como argv, `||` y `true` llegan como argumentos literales a npm y falla.
  [ "$#" -gt 0 ] || die "the evidence is missing. Usage: rdd receipt <test command>  (e.g. rdd receipt npm test)"

  # Los metacaracteres van literales a proposito: se buscan como texto, no se expanden.
  # shellcheck disable=SC2016
  case "$*" in
    *'|'* | *';'* | *'&'* | *'$('* | *'`'*)
      die "the evidence contains shell metacharacters. Pass it as argv (rdd receipt npm test), not as a string: an operator there can fabricate the exit 0 the receipt claims to have verified."
      ;;
  esac

  local evidence_cmd="$*"
  echo "running evidence: $evidence_cmd"
  local out rc
  out=$("$@" 2>&1)
  rc=$?
  printf '%s\n' "$out" | tail -20

  if [ "$rc" -ne 0 ]; then
    echo
    die "the evidence failed (exit $rc). No green evidence, no receipt."
  fi

  mkdir -p "$STATE_DIR"
  cat >"$RECEIPT" <<EOF
{
  "candidate_hash": "$frozen",
  "evidence_command": "$(printf '%s' "$evidence_cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')",
  "evidence_exit_code": $rc,
  "lines_changed": $now_lines,
  "issued_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  echo
  echo "RECEIPT ISSUED — commit authorized for hash $frozen"
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
  cd "$root" || die "could not enter $root"
  if [ -f "$SWITCH" ]; then echo "RDD: ON (blocks commits without a receipt)"; else echo "RDD: off (quality-gate only warns)"; fi
  if [ -f "$CANDIDATE" ]; then
    local frozen
    frozen=$(json_get "$CANDIDATE" hash)
    echo "candidate: $frozen"
    [ "$frozen" = "$(candidate_hash)" ] && echo "  the staged bytes MATCH" || echo "  the staged bytes CHANGED since the freeze"
  else
    echo "candidate: none"
  fi
  if [ -f "$RECEIPT" ]; then
    cmd_verify && echo "receipt: VALID" || echo "receipt: present but for other bytes"
  else
    echo "receipt: none"
  fi
}

cmd_on() {
  local root
  root=$(repo_root)
  mkdir -p "$root/$STATE_DIR" && touch "$root/$SWITCH"
  grep -qxF "$STATE_DIR/" "$root/.gitignore" 2>/dev/null || printf '%s/\n' "$STATE_DIR" >>"$root/.gitignore"
  echo "RDD turned on in $root. .gitignore updated."
}

cmd_off() {
  local root
  root=$(repo_root)
  rm -f "$root/$SWITCH"
  echo "RDD turned off in $root. Commits no longer require a receipt."
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

  rdd freeze [max_fix_lines]   freeze the staged bytes (default: ceiling 40)
  rdd receipt <test cmd>       run the evidence and issue the receipt (argv, unquoted)
  rdd verify                   exit 0 authorized / 1 no receipt / 2 other bytes
  rdd status                   current state
  rdd on | rdd off             per-repo kill switch

The rule: without a receipt bound to the exact bytes, there is no commit.
EOF
    exit 2
    ;;
esac
