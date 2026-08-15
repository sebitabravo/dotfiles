#!/usr/bin/env bash
# protect-tests.sh — PreToolUse hook para Edit/Write/NotebookEdit.
#
# QUE ES: un badén contra la deriva accidental, NO un gate hermetico.
# Corre con matcher Edit|Write|NotebookEdit, asi que una escritura por Bash
# (`sd`, `cat >`, `python -c`) lo esquiva por completo. Eso es a proposito y esta
# documentado en el mensaje de bloqueo: un guardarrail que miente sobre su
# alcance es peor que uno honesto, porque te hace confiar de mas.
# El gate real es CI corriendo la suite desde un checkout limpio, donde el
# agente no llega.
#
# QUE FRENA: el caso documentado de un agente autonomo que borro sus propios
# tests durante un refactor porque "estorbaban" — sin malicia, solo optimizando
# para dejar todo en verde.
#
# PROPIEDAD POR SESION: un test que ESTE agente creo en ESTA sesion no es una
# restriccion sobre el, es su propio borrador. Bloquearlo rompia el ciclo TDD
# (escribir test -> correrlo -> ajustar el test -> implementar): permitia el
# primer paso y bloqueaba el tercero. Se registran los archivos creados y se
# permiten sus ediciones posteriores dentro de la misma sesion.
set -euo pipefail

# jq es obligatorio: sin el, este hook no puede proteger archivos de test.
# Fallar cerrado evita que la ausencia del parser permita una edición que debía
# quedar bloqueada.
if ! command -v jq >/dev/null 2>&1; then
  echo "[protect-tests] jq is not installed: blocking preventively; install it with: brew install jq" >&2
  exit 2
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null | tr -cd 'a-zA-Z0-9-')

OWNED="${TMPDIR:-/tmp}/claude-owned-tests-${SESSION_ID:-nosession}"

# Silencio, no "allow": un permissionDecision "allow" se salta el prompt de
# permisos, asi que devolverlo para cada archivo que no es test auto-aprobaba
# todo Edit/Write de la sesion. Sin stdout, decide settings.json.
allow() {
  exit 0
}

# jq -n arma el JSON y escapa el reason. Interpolar la razon directo rompia el
# decision cuando el filename traia comillas o backslashes, y un decision
# malformado se ignora: el bloqueo fallaba abierto justo con el input raro.
deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

case "$TOOL_NAME" in
  Edit | Write | NotebookEdit) ;;
  *) allow ;;
esac

[ -z "$FILE_PATH" ] && allow

BASENAME=$(basename "$FILE_PATH")

# Sufijos de test por convencion de cada ecosistema.
# Anclados a un separador (. o _) para no capturar 'latest.js' ni 'contest.py'.
IS_TEST=false
case "$BASENAME" in
  *.test.* | *.spec.*) IS_TEST=true ;; # JS/TS: foo.test.ts, foo.spec.tsx
  *_test.go | *_test.py | *_test.rb | *_test.exs | *_test.dart) IS_TEST=true ;;
  test_*.py) IS_TEST=true ;; # pytest
  *Test.java | *Tests.java | *Test.kt | *Tests.kt) IS_TEST=true ;;
  *Spec.scala | *Test.cs | *Tests.cs) IS_TEST=true ;;
  *Test.php | *Tests.php) IS_TEST=true ;; # PHPUnit / Pest
  *Test.swift | *Tests.swift) IS_TEST=true ;; # XCTest
  *.feature) IS_TEST=true ;;  # Gherkin
  conftest.py) IS_TEST=true ;; # fixtures pytest
  # Un snapshot ES la assertion: reescribirlo hace pasar cualquier output.
  # Es la forma mas barata de poner la suite en verde sin arreglar nada.
  *.snap | *.ambr) IS_TEST=true ;;
esac

# Directorios de test. Requiere el separador / a ambos lados para no capturar
# 'src/contests/' ni 'app/latest/'.
if [ "$IS_TEST" = false ]; then
  case "/$FILE_PATH" in
    */tests/* | */test/* | */__tests__/* | */spec/* | */specs/* | */features/*) IS_TEST=true ;;
    */e2e/* | */integration-tests/* | */cypress/* | */playwright/*) IS_TEST=true ;;
    */__snapshots__/*) IS_TEST=true ;;
  esac
fi

[ "$IS_TEST" = false ] && allow

# Crear un test nuevo se permite: un archivo que todavia no existe no puede
# debilitar la suite, y bloquearlo rompia el ciclo TDD. Se anota como propio
# para que las ediciones siguientes de la misma sesion tampoco se bloqueen.
if [ ! -e "$FILE_PATH" ]; then
  printf '%s\n' "$FILE_PATH" >>"$OWNED" 2>/dev/null || true
  allow
fi

# Test creado por este agente en esta sesion: es su borrador, no una restriccion
# sobre el. La proteccion aplica a la cobertura que YA existia al empezar.
if [ -f "$OWNED" ] && grep -qxF -- "$FILE_PATH" "$OWNED" 2>/dev/null; then
  allow
fi

deny "TEST PROTECTION: '$BASENAME' already existed when this session started, so it is coverage that verifies your work and not a draft of yours. Do not modify it on your own. If the change is legitimate (the requirement genuinely changed), STOP and ask the user for explicit authorization, stating: (1) which test you are touching, (2) why, (3) what it covers after the change. Never delete or weaken a test to make the code pass. NOTE: this hook only covers Edit/Write/NotebookEdit — a write through Bash slips past it. That it is possible does not make it permitted: bypassing it is breaking the rule, not working around it."
