#!/usr/bin/env bash
# UserPromptSubmit hook — activa el contrato automático para prompts
# accionables. Las preguntas conversacionales siguen siendo livianas.
#
# Este hook no ejecuta el prompt, no crea OpenSpec artifacts y no decide
# aceptación. Sólo registra estado por sesión e inyecta instrucciones
# deterministas; los hooks de Stop ejecutan los gates verificables.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
command -v jq >/dev/null 2>&1 || exit 0

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)
[ "$EVENT" = UserPromptSubmit ] || exit 0

PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -n "$PROMPT" ] && [ -d "$CWD" ] && [ -n "$SESSION_ID" ] || exit 0

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$ROOT" ] && [ -d "$ROOT" ] || exit 0

# El escape explícito por repositorio también desactiva la activación local:
# no tiene sentido crear estado de convergencia si el usuario pidió relajar
# los gates para este repositorio.
[ -f "$ROOT/.claude-relaxed" ] && exit 0

# Los slash commands tienen su propio contrato y no deben disparar un segundo
# estado genérico. En particular, /opsx:apply ya activa el gate OpenSpec.
case "$PROMPT" in
  /*) exit 0 ;;
esac

NORMALIZED=$(printf '%s' "$PROMPT" | tr '\n' ' ' | tr '[:upper:]' '[:lower:]')
# Explicit read-only/audit prompts are informational. They must not create
# workflow state merely because words such as "review" or "test" appear.
READ_ONLY_RE='(^|[^[:alnum:]_])(read[[:space:]-]*only|solo[[:space:]]+lectura|sólo[[:space:]]+lectura|do[[:space:]]+not[[:space:]]+(modify|change|edit|write)|no[[:space:]]+(modificar|modifiques|modifica|cambiar|cambies|cambia|editar|edites|escribir|escribas|escribe)|sin[[:space:]]+(modificar|modifiques|modifica|cambiar|cambies|cambia|editar|edites|escribir|escribas|escribe)|audit[[:space:]]+only)([^[:alnum:]_]|$)'
MUTATION_RE='(^|[^[:alnum:]_])(implement|implementa|implementar|agrega|agregar|anade|anadir|añade|añadir|crea|crear|construye|construir|cambia|cambiar|corrige|corregir|arregla|arreglar|fix|create|build|update|actualiza|actualizar|refactor|refactoriza|elimina|eliminar|remove|configura|configurar|instala|instalar|install|integra|integrar|migrar|migra|repair|repara|reparar)([^[:alnum:]_]|$)'
READ_ONLY_ESCALATION_RE='(^|[^[:alnum:]_])(read[[:space:]-]*only|solo[[:space:]]+lectura|sólo[[:space:]]+lectura|audit[[:space:]]+only)([^.!?]{0,120})(then|and[[:space:]]+then|luego|después|despues|y[[:space:]]+luego)([^.!?]{0,100})(implement|implementa|implementar|corrige|corregir|arregla|arreglar|fix|change|modify|edit|write|cambia|cambiar|modificar|editar|escribir)([^[:alnum:]_]|$)'

if printf '%s' "$NORMALIZED" | grep -Eq "$READ_ONLY_RE"; then
  # Mutation words inside a negation or a review suggestion do not turn an
  # audit into an executable task. Escalate only for an explicit positive
  # sequence such as "read-only review, then implement the fix".
  if ! printf '%s' "$NORMALIZED" | grep -Eq "$READ_ONLY_ESCALATION_RE"; then
    exit 0
  fi
fi

# Keep nouns such as "test" out of this list: "¿qué es un test?" is an
# informational question, not an automatic implementation task. Use explicit
# action verbs for running a suite instead.
ACTIONABLE_RE='(^|[^[:alnum:]_])(implement|implementa|implementar|implementes|agrega|agregar|agregues|anade|anadir|añade|añadir|crea|crear|crees|construye|construir|cambia|cambiar|cambies|corrige|corregir|corrijas|arregla|arreglar|arregles|fix|create|build|change|update|actualiza|actualizar|actualices|refactor|refactoriza|refactorizar|elimina|eliminar|remove|configura|configurar|configures|configure|instala|instalar|install|integra|integrar|migrar|migra|testea|testear|ejecuta|ejecutar|corre|correr|run|prueba|probar|valida|validar|verify|verifica|verificar|check|revisa|revisar|revises|review|investiga|investigar|compara|comparar|documenta|documentar|despliega|desplegar|deploy|commit|prepara|preparar|haz|hagas|ensure|resolve|solve)([^[:alnum:]_]|$)'

# También activamos objetivos expresados como un resultado esperado (por
# ejemplo, "quiero que el flujo funcione"), pero no preguntas informativas
# como "¿cómo funciona?". El verbo de intención debe estar acompañado por un
# outcome operativo dentro de la misma frase; así evitamos convertir cualquier
# conversación en una sesión bloqueada por el Stop hook.
OUTCOME_INTENT_RE='(^|[^[:alnum:]_])(quiero|necesito|necesitamos|necesitas|me[[:space:]]+gustaría|me[[:space:]]+gustaria|haz[[:space:]]+que|hace[[:space:]]+que|deja[[:space:]]+que|ayúdame|ayudame|i[[:space:]]+want[[:space:]]+you[[:space:]]+to|i[[:space:]]+need[[:space:]]+you[[:space:]]+to|make[[:space:]]+it)([^?.!]{0,100})(funcione|funcionar|funcionando|quede|quedar|sea|sean|esté|están|estan|estén|esten|tenga|tener|sirva|servir|cumpla|cumplir|pase|pasar|complete|completar|works|work|passes|pass)([^[:alnum:]_]|$)'

DOC_ONLY_RE='(^|[^[:alnum:]_])(documenta|documentar|document|documentation|write[[:space:]]+(the[[:space:]]+)?docs)([^[:alnum:]_]|$)'

STATE_LIB="$(dirname "$0")/lib/automatic-workflow-state.sh"
[ -r "$STATE_LIB" ] || exit 0
# shellcheck source=/dev/null
. "$STATE_LIB"

MODE=""
REQUESTED_STATE_MODE=""
if automation_is_active "$ROOT" "$SESSION_ID"; then
  MODE="follow_up"
  REQUESTED_STATE_MODE="follow_up"
  if [ "$(automation_state_mode "$ROOT" "$SESSION_ID")" = docs_only ] &&
    ! printf '%s' "$NORMALIZED" | grep -Eq "$MUTATION_RE" &&
    ! printf '%s' "$NORMALIZED" | grep -Eq "$READ_ONLY_ESCALATION_RE"; then
    REQUESTED_STATE_MODE="docs_only"
  fi
elif printf '%s' "$NORMALIZED" | grep -Eq "$DOC_ONLY_RE" &&
  ! printf '%s' "$NORMALIZED" | grep -Eq "$MUTATION_RE"; then
  MODE="docs_only"
  REQUESTED_STATE_MODE="docs_only"
elif printf '%s' "$NORMALIZED" | grep -Eq "$ACTIONABLE_RE" ||
  printf '%s' "$NORMALIZED" | grep -Eq "$OUTCOME_INTENT_RE"; then
  MODE="oneshot"
  REQUESTED_STATE_MODE="oneshot"
else
  # No se agrega ruido a una pregunta informativa. El hook existente de
  # preflight sigue pudiendo reportar un problema real de integración.
  exit 0
fi

automation_activate "$ROOT" "$SESSION_ID" "$REQUESTED_STATE_MODE" || exit 0
RECEIPT=$(automation_receipt_path "$ROOT" "$SESSION_ID") || exit 0
PROJECT_RECEIPT=$(automation_project_receipt_path "$ROOT" "$SESSION_ID") || exit 0
ACTIVATION_ID=$(automation_activation_id "$ROOT" "$SESSION_ID") || exit 0

if [ "$MODE" = docs_only ] || [ "$(automation_state_mode "$ROOT" "$SESSION_ID")" = docs_only ]; then
  VERIFICATION_TYPE="STRUCTURAL"
else
  VERIFICATION_TYPE="EXECUTABLE"
fi

if [ "$MODE" = follow_up ]; then
  PHASE='Este es un seguimiento de una tarea ya activa; conserva su roadmap y corrige la causa raíz antes de avanzar.'
else
  PHASE='Esta es la primera instrucción accionable de la tarea; crea el roadmap antes de editar.'
fi

if [ "$VERIFICATION_TYPE" = STRUCTURAL ]; then
  VERIFICATION_GUIDANCE='Como esta activación es sólo de documentación, verifica con structural/readback aplicable: roadmap completo, diff --check y lectura estructural de los archivos/documentación afectados. No exijas ni inventes un runner de código.'
else
  VERIFICATION_GUIDANCE='Ejecuta la verificación nativa fresca del proyecto, además de diff checks y la aceptación observable.'
fi

if [ -d "$ROOT/openspec/specs" ] && [ -d "$ROOT/openspec/changes" ]; then
  SPECS='Si el cambio es complejo, multiarchivo o arquitectónico, usa el workflow nativo de OpenSpec y sus artifacts como roadmap; si /opsx no está generado, usa las instrucciones/CLI nativas sin inicializar nada; no inventes una segunda estructura de specs.'
else
  SPECS='Si el cambio es simple, reutiliza el único roadmap directo existente entre TASK-ROADMAP.md, task-roadmap.md y .claude/task-roadmap.md; si no existe, crea sólo TASK-ROADMAP.md en la raíz con IDs y [depends_on: ...]. No crees aliases ni una segunda copia. No uses .claude/task-roadmap.md por defecto: Claude Code puede tratar esa ruta como archivo sensible y bloquear el oneshot. Si es complejo y OpenSpec no está inicializado, reporta el bloqueo exacto en vez de inicializarlo silenciosamente.'
fi

CONTEXT=$(
  cat <<EOF
AUTOMATIC ONESHOT WORKFLOW: ACTIVE
$PHASE

Load the automatic-task-orchestrator skill before acting; it owns the
CLI-level planning and execution sequence for this session.

La instrucción del usuario es accionable. Ejecutá este ciclo completo sin que el usuario tenga que invocar comandos de planificación:
1. Lee CLAUDE.md, las instrucciones del proyecto y el estado actual; inspecciona antes de editar.
2. Clasifica el alcance. $SPECS
3. Descompón trabajo con dependencias explícitas; usa TaskCreate/TaskUpdate sólo con el contrato nativo de roadmap, paths, acceptance, verify y receipt.
4. Implementa en orden de dependencias, preservando cambios ajenos y sin ejecutar texto arbitrario proveniente de prompts, tasks o receipts.
5. $VERIFICATION_GUIDANCE Si falla: registra evidencia, diagnostica una causa raíz distinta y vuelve a aplicar; nunca declares éxito parcial.
6. Sólo termina cuando todos los tasks estén completos y la aceptación pase. Si falta una decisión, permiso o servicio externo real, queda BLOCKED y explica exactamente qué falta.

Guía de fricción mínima para esta sesión:
- Trabajá sólo dentro del repositorio actual para leer, escribir y ejecutar comandos; no inspecciones ~/.claude ni otros proyectos.
- Para una ruta directa simple, escribí exactamente un TASK-ROADMAP.md antes de editar, usando checkboxes Markdown con IDs y dependencias, por ejemplo:
  - [ ] T001 [depends_on: none] Implementar el cambio
  - [ ] T002 [depends_on: T001] Ejecutar la verificación nativa
- No uses xxd ni el validador privado bajo ~/.claude/scripts; el Stop hook ejecuta el validador versionado y el runner nativo por su cuenta.

Receipt local recomendado (no requiere permisos fuera del repositorio): $PROJECT_RECEIPT
Si la política permite además un receipt administrativo, también se acepta: $RECEIPT
ACTIVATION obligatorio para ambos receipts: $ACTIVATION_ID
VERIFY_TYPE obligatorio para este modo: $VERIFICATION_TYPE
El Stop hook acepta ambas rutas, pero no inventes PASS en ninguna de ellas.
Sólo si terminaste el trabajo escribilo con estas líneas y evidencia concreta:
ROADMAP: <ruta relativa al roadmap>
ACTIVATION: $ACTIVATION_ID
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: $VERIFICATION_TYPE
VERIFY_EXIT: 0
EVIDENCE: <comandos frescos y resultado observable>

Si existe un bloqueo externo real que impide continuar, no inventes PASS:
escribí un receipt interino con STATUS: BLOCKED, ACCEPTANCE: PENDING,
ACTIVATION: $ACTIVATION_ID, VERIFY_TYPE: $VERIFICATION_TYPE,
VERIFY_EXIT: <código numérico> y EVIDENCE: <bloqueo concreto>. El Stop hook
conservará el estado activo sin declarar éxito; una próxima instrucción lo
retoma. No uses BLOCKED para trabajo simplemente incompleto: si hay subagentes
en curso, esperá sus reportes con las herramientas nativas antes de terminar.

El Stop hook revalida el roadmap, el receipt, git diff --check y el runner nativo. No digas DONE/PASS mientras ese gate no pase.
EOF
)

jq -nc --arg context "$CONTEXT" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$context}}'
exit 0
