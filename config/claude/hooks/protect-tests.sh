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

# Un test existente no se edita silenciosamente, pero una modificacion
# legitima puede aprobarse desde el prompt nativo de permisos de Claude Code.
# La autorizacion conversacional no llega al hook, asi que `ask` es el unico
# punto de aprobacion que este guardarrail puede consumir de forma confiable.
ask() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
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

ask "TEST PROTECTION: '$BASENAME' ya existia antes de esta sesion y protege cobertura que verifica tu trabajo. La edicion no se permite silenciosamente: aprobala en el prompt nativo solo si el requisito cambio. Indica (1) que test tocas, (2) por que y (3) que cubrira despues. Nunca borres ni debilites un test para hacer pasar el codigo. Este hook solo cubre Edit/Write/NotebookEdit; escribir por Bash lo esquiva, pero hacerlo rompe esta politica y no es un workaround valido."
