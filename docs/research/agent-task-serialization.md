# Serialización de tareas y roadmaps en agentes LLM

> Documento de investigación. Objetivo: material verificable para discutir con
> otros ingenieros por qué la descomposición explícita de tareas mejora (o no)
> el rendimiento de un agente LLM, y qué tan cerca está este harness de Claude
> Code del estado del arte. Cada cifra citada fue contrastada con la fuente
> primaria mediante consulta directa, no tomada de un resumen de buscador.

## 1. El problema

Un prompt monolítico falla en tareas largas por dos mecanismos distintos, no
uno solo:

**Degradación no lineal por longitud de contexto.** Chroma Research evaluó 18
modelos (GPT-4.1, Claude 4, Gemini 2.5, Qwen3) en tareas controladas de
retrieval y encontró que el rendimiento no decae linealmente con el largo del
input: los modelos sufren "cliffs" — funcionan bien a 32K tokens y colapsan a
64K, en vez de degradarse gradualmente. El factor que más acelera la caída no
es el largo bruto, sino la similitud semántica entre la consulta y la
información objetivo: a menor similitud, la degradación se acelera más rápido
con el largo del input (Hong, Troynikov & Huber, *Context Rot*, Chroma
Research, 2025).

**Pérdida de saliencia del plan.** A medida que los resultados de herramientas
se acumulan en el historial conversacional, el plan original pierde peso
relativo en la atención del modelo. Una refactorización de diez pasos puede
completar los pasos 1-3 y luego derivar, porque los pasos 4-10 ya no son
prominentes en el contexto. Esto no es un problema de capacidad del modelo —es
un problema de qué información compite por atención en cada paso de inferencia.

Estos dos mecanismos son la razón de fondo por la que "descomponer y ordenar
explícitamente" no es una preferencia estética: es una respuesta a límites
medibles del propio modelo.

## 2. Taxonomía de descomposición

La literatura distingue varios ejes independientes, y confundirlos genera
comparaciones inválidas entre papers:

- **Explícito vs. implícito.** Un planner separado que genera el plan antes de
  ejecutar, frente a Chain-of-Thought embebido en una sola llamada que mezcla
  razonamiento y acción sin una fase de planificación distinguible.
- **Decomposition-first vs. interleaved.** El plan completo se genera antes de
  ejecutar cualquier paso (Plan-and-Execute, ReWOO), frente a proponer un paso,
  ejecutarlo, observar el resultado y recién ahí proponer el siguiente (ReAct).
- **Lineal vs. grafo dirigido acíclico (DAG).** Una secuencia estricta de
  subtareas, frente a un grafo con dependencias parciales donde varias ramas
  son independientes entre sí y pueden ejecutarse en paralelo.
- **Estático vs. recursivo bajo demanda.** ADaPT (Prasad et al., NAACL 2024
  Findings) no descompone por adelantado según una estimación de dificultad:
  descompone *cuando* el executor falla en ejecutar una subtarea, y ese
  descomponer es recursivo — la subtarea fallida se vuelve a partir hasta que
  el executor puede con los pedazos. Esto adapta la granularidad a la
  capacidad real del modelo en ese momento, no a una heurística previa.

El propio harness de Claude Code usa varios de estos ejes sin nombrarlos: SDD
es decomposition-first con fases explícitas; ADaPT describe justo el patrón que
`sdd-workflow` no tiene — nada en este repo re-descompone una tarea cuando el
implementador falla a mitad de camino.

## 3. Serialización: el costo medido

El caso de referencia es **LLMCompiler** (Kim et al., *An LLM Compiler for
Parallel Function Calling*, ICML 2024, arXiv:2312.04511). Tres componentes,
inspirados deliberadamente en la arquitectura de un compilador tradicional:

- **LLM Planner**: formula la estrategia de ejecución completa y construye un
  DAG explícito de tareas y sus dependencias — no ejecuta nada, solo planifica.
- **Task Fetching Unit**: despacha las tareas cuyas dependencias ya están
  resueltas, y alimenta cada tarea con las salidas reales de sus predecesoras
  en el grafo a medida que estas terminan.
- **Executor**: corre en paralelo todo lo que el DAG permite, respetando el
  orden parcial.

Cifras confirmadas en el abstract (arXiv:2312.04511, leído directo): frente a
ReAct, **speedup de latencia de hasta 3.7x, ahorro de costo de hasta 6.7x, y
mejora de accuracy de hasta ~9%**. El abstract no desglosa cifras por
benchmark individual (HotpotQA, Movie Recommendation, WebShop) — esas
comparaciones específicas están en el cuerpo del paper, no en el resumen, así
que no se citan aquí números que no fueron verificados directamente.

El **failure mode que da nombre al problema** es la *serialización
innecesaria*: el modelo, al planificar, infiere una dependencia que no existe
—"este paso necesita la salida del anterior" cuando en realidad no la
necesita— y convierte en secuencial un trabajo que era paralelizable. Es un
error de sobre-especificación del grafo, no de ejecución: el DAG generado tiene
más aristas de las que la tarea real requiere.

Esto es exactamente el gap del punto 6.1 más abajo: este repo declara la
sintaxis para marcar paralelismo (`[P]` en `sdd-tasks.md`) pero no tiene un
Planner/Executor personalizado que derive y verifique el grafo. Claude Code sí
dispone de una task list nativa para sesiones con Task tools; el problema local
es que el harness no imponía un contrato, no validaba receipts y no gobernaba
la finalización. La responsabilidad de no serializar de más sigue dependiendo
del criterio del agente mientras no exista evidencia de independencia y
propiedad de archivos.

## 4. Roadmaps: estado durable fuera de la ventana

Anthropic llama a esto *structured note-taking* (o *agentic memory*): "una
técnica donde el agente escribe notas regularmente, persistidas en memoria
fuera de la ventana de contexto" (*Effective context engineering for AI
agents*, Anthropic Engineering). El patrón aplicable aquí no es depender de
un nombre histórico de herramienta, sino mantener un roadmap durable y una
task list de ejecución con estados y dependencias.

- **Claude Code** coordina una task list estructurada cuando la sesión tiene
  las Task tools: `TaskCreate`, `TaskGet`, `TaskList` y `TaskUpdate` mantienen
  estados, dependencias y bloqueos. La documentación actual indica que estas
  herramientas son el camino por defecto desde Claude Code `2.1.142`; este host
  tiene `2.1.234` y no define `CLAUDE_CODE_ENABLE_TASKS`, pero la disponibilidad
  efectiva de las tools aún debe probarse dentro de una sesión real. La task
  list es runtime state, no un roadmap versionado del proyecto.
- **Claude jugando Pokémon** mantiene conteos precisos a través de miles de
  pasos de juego — "en los últimos 1.234 pasos he estado entrenando a mi
  Pokémon en la Ruta 1, Pikachu subió 8 niveles de los 10 objetivo" — sin
  mantener toda esa historia en el contexto activo.

Un ejemplo relacionado pero de una publicación distinta (*How we built our
multi-agent research system*, Anthropic Engineering): el LeadResearcher
"comienza pensando el enfoque y guarda su plan en Memory para persistir el
contexto, ya que si la ventana excede 200.000 tokens será truncada y es
importante retener el plan". La persistencia del plan no es una optimización
posterior: es la precondición para que la truncación no destruya el trabajo.

La configuración no debe describirse como "TodoWrite ausente": la cadena no
aparece en los archivos locales, pero eso no prueba la ausencia de la task list
nativa. El gap verificable era otro: no había una política local para exigir
descripción, dependencias, aceptación, verificación y receipt. Ese contrato se
documenta en `config/claude/templates/sdd-tasks.md` y se valida con los hooks
deterministas `TaskCreated`/`TaskCompleted`.

El patrón más general es **checkpoint-restore**: un archivo de estado que se
hidrata al arrancar — si existe, se carga y el agente salta al paso donde
quedó; si no existe, arranca de cero. Es el mecanismo detrás de agentes que
cruzan sesiones completas, no solo compactaciones dentro de una sesión.

## 5. El contrapunto honesto

Descomponer entre agentes no es gratis, y el argumento en contra tiene tanta
evidencia como el argumento a favor.

**Cognition, *Don't Build Multi-Agents*** (2025): el ejemplo central es un
Flappy Bird dividido en dos subagentes — uno construye el fondo, otro
construye el pájaro. Un subagente entiende mal el encargo y produce un fondo
estilo Super Mario Bros; el otro produce un pájaro que no calza visual ni
mecánicamente con lo que el primero hizo. El agente coordinador queda con la
tarea imposible de reconciliar dos salidas que partieron de supuestos
distintos y nunca se sincronizaron. El principio que Cognition nombra
explícitamente: "las acciones cargan decisiones implícitas, y decisiones en
conflicto producen malos resultados" — cuando los subagentes trabajan sin
visibilidad mutua, cada uno decide sobre una vista parcial, y esas decisiones
parciales no son reconciliables después del hecho.

**Costo de coordinación medido por el propio Anthropic** (*How we built our
multi-agent research system*): "los agentes típicamente usan ~4x más tokens
que una interacción de chat, y los sistemas multi-agente usan ~15x más tokens
que un chat". Es un costo real y cuantificado, no una intuición.

**Cemri et al., *Why Do Multi-Agent LLM Systems Fail?*** (arXiv:2503.13657):
catalogaron **14 modos de falla, agrupados en 3 categorías**, sobre **1.600+
trazas anotadas recolectadas de 7 frameworks MAS populares** (la taxonomía en
sí se construyó sobre un análisis más fino de 150 trazas). Una de las tres
categorías es "inter-agent misalignment" — desalineación entre agentes. El
abstract confirma que la categoría existe y su lugar en la taxonomía, pero
**no reporta ahí un porcentaje o conteo específico de cuántas de las 1.600+
fallas caen en esa categoría**; cualquier cifra puntual (por ejemplo, un 32%)
requeriría leer el cuerpo del paper, y no se cita aquí una cifra que esta
sesión no verificó directamente.

**Cómo se reconcilian ambas posiciones**: el mismo Anthropic reporta, en el
mismo documento donde reconoce el costo de 15x, que su sistema multi-agente
(Opus 4 como lead, subagentes Sonnet 4) superó al agente único Opus 4 en
**90.2% en su eval interno de research**. La diferencia no es "multi-agente
sí" vs "multi-agente no": es que Anthropic encontró el punto óptimo en tareas
de research verdaderamente paralelizables con fronteras naturales de
independencia (cada subagente investiga una rama distinta y nadie necesita ver
el trabajo del otro para avanzar), mientras que Cognition documentó la falla
específicamente en tareas que exigen contexto compartido y decisiones
coordinadas (dos subagentes construyendo piezas visuales que deben encajar).

**Conclusión a defender**: la granularidad correcta de descomposición es un
parámetro de diseño que depende de si la tarea tiene fronteras naturales de
independencia — no es "más subtareas siempre mejor". Descomponer demasiado
grueso deja subtareas inmanejables para un solo agente; descomponer demasiado
fino explota en overhead de coordinación exactamente como predice el costo de
15x. El criterio no es el tamaño de la tarea, es si sus partes pueden decidirse
sin ver las decisiones de las otras partes.

## 6. Gap analysis del harness

Estado real de este repo (`dotfiles/config/claude/`) frente a la literatura de
las secciones 1-5. Las filas distinguen hechos locales verificados de decisiones
implementadas durante esta investigación; no confunden documentación de
Anthropic con comportamiento probado en un proveedor alternativo.

| # | Práctica en la literatura | Estado en este harness | Evidencia |
|---|---|---|---|
| 1 | DAG explícito con Planner que deriva paralelismo y Executor que lo respeta (LLMCompiler) | No hay Planner/Executor que genere o despache tareas automáticamente. El harness ahora calcula la frontera teórica y puede declarar `verified`, `unproven` o `conflict` usando anotaciones `[paths: ...]`; `paths: none`, rutas inseguras y globs no resueltos permanecen `unproven`. No infiere ownership ni paraleliza por su cuenta | `config/claude/scripts/validate-task-roadmap.py`; `config/claude/templates/sdd-tasks.md`; `config/claude/CLAUDE.md` §Agent Orchestration; `config/claude/settings.json` registra `TaskCreated`/`TaskCompleted` |
| 2 | Descomposición a nivel de fase (Plan-and-Execute) | Presente y explícito en el flujo OpenSpec, pero solo entre artefactos/fases, no dentro de una fase | `preflight → OpenSpec CLI planning → apply → verification gate → archive` en `CLAUDE.md` §SDD and project context y `sdd-workflow`; `/opsx:verify` y `/opsx:archive` quedan como fallback cuando los comandos generados existen |
| 3 | Re-descomposición recursiva cuando el executor falla (ADaPT) | No hay re-partición recursiva ilimitada. Sí existe una política bounded: después del segundo fallo se propone una sola re-descomposición, preservando nodos validados y deteniéndose sólo ante una decisión material o bloqueo real | `config/claude/skills/sdd-workflow/SKILL.md` §Failure and re-planning budget |
| 4 | Checkpoint-restore de estado de tareas, no solo de reglas | Parcial pero implementado: tras compactación se reinyectan reglas, estado de git y el roadmap activo con sus tareas marcadas; todavía no se restaura automáticamente el task registry nativo | `config/claude/hooks/compact-resume.py` y su fixture `compact-resume.test.sh` |
| 5 | Gobernanza explícita de la herramienta nativa de tracking de tareas (TaskCreate/TaskUpdate / structured note-taking) | Parcial y ahora enforceable: el template define el contrato y `task-contract.sh` bloquea tareas sin roadmap, dependencias, paths, aceptación, verificación o receipt; para cerrar exige `STATUS: PASS`, `ACCEPTANCE: PASS`, `VERIFY_EXIT: 0` y evidencia no vacía | `config/claude/templates/sdd-tasks.md` sección `Native task contract`; `config/claude/hooks/task-contract.sh`; `config/claude/settings.json` eventos `TaskCreated`/`TaskCompleted` |
| 6 | Gate de cierre de turno que verifica tareas abiertas, no solo estado de git | Implementado para OpenSpec y oneshots naturales: `automatic-workflow.sh` activa estado por sesión sólo para prompts accionables; `automatic-workflow-stop.sh` exige roadmap completo, receipt, diff check y runner nativo fresco. El task registry nativo de Claude sigue gobernado por `TaskCreated`/`TaskCompleted`, no inferido desde el texto del prompt | `config/claude/hooks/automatic-workflow.sh`; `config/claude/hooks/automatic-workflow-stop.sh`; `config/claude/hooks/activate-convergence-on-apply.sh`; `config/claude/settings.json` |
| 7 (contrapeso) | Structured note-taking y memoria persistente fuera de ventana (Anthropic) | Implementado con cobertura real | `rules/common/context-management.md` (protocolo completo de `mem_save`/`/handoff`), `skills/handoff/SKILL.md`, integración Engram vía MCP |
| 8 (contrapeso) | Reportes durables por subagente en vez de pasar resultados grandes por chat (mitiga el costo de coordinación de la sección 5) | Implementado explícitamente como regla dedicada | `CLAUDE.md` regla "ANTI-TELEPHONE RULE" y "DELIVERY RECEIPT FALLBACK" |

**Lectura del gap analysis**: el harness resolvió bien el lado de *contexto*
del problema (filas 7-8), tiene un gate de contrato en el lado de ejecución
(fila 5), recupera el roadmap después de compactación (fila 4), formaliza una
re-descomposición acotada (fila 3) y ahora realiza una revisión conservadora de
ownership para frontiers paralelos (fila 1). Todavía no infiere ownership,
despacha tareas automáticamente, enumera tareas abiertas del registry nativo
en Stop ni tiene re-planificación adaptativa recursiva (filas 1, 3 y 6). El DAG
de fases (fila 2) demuestra que el
patrón se entiende a nivel macro; la siguiente iteración debe bajarlo a la
tarea individual sin crear un scheduler externo.

### 6.1 Activación automática desde un oneshot

La brecha específica del uso que motivó esta investigación era operacional:
las reglas sabían qué hacer, pero el usuario todavía debía conocer `/goal`,
`/opsx:apply` o la existencia del receipt. La implementación añade dos capas
sin convertir el hook en un intérprete de shell:

- `automatic-workflow.sh` recibe `UserPromptSubmit.prompt`, clasifica con una
  lista conservadora de verbos accionables y crea estado aislado por
  `session_id`; las preguntas conversacionales y slash commands quedan fuera.
  Devuelve `hookSpecificOutput.additionalContext`, que es el canal oficial de
  Claude Code para inyectar contexto en `UserPromptSubmit`.
- `automatic-workflow-stop.sh` consume sólo el estado de esa sesión. No ejecuta
  `VERIFY:` ni una orden escrita por el modelo: valida el DAG, valida OpenSpec
  cuando el roadmap es un change, corre `git diff --check` y ejecuta el runner
  nativo detectado por `test-runner.sh`. Sólo después elimina el estado de la
  sesión.
- `automatic-task-orchestrator/SKILL.md` resuelve una limitación importante de
  OpenSpec 1.9.0: el `/opsx:propose` generado es deliberadamente planning-only
  y espera otra petición antes de aplicar. En un oneshot claro, el skill usa la
  secuencia CLI `new change -> status -> instructions -> validate` y deja los
  comandos `/opsx:*` como fallback explícito.

Esto automatiza el enrutamiento, la secuencia de planificación y el cierre mecánico, pero no inventa una
aceptación semántica: si el repositorio no tiene un runner ejecutable o la
aceptación necesita juicio humano, el resultado correcto es `BLOCKED`. Un
clasificador basado en otro LLM se descartó porque agregaría una inferencia
extra antes de cada prompt y podría bloquear o malclasificar una pregunta; la
documentación oficial permite prompt/agent hooks, pero no los necesita para
este contrato determinista.

## 7. Plan de implementación

### Fase 0 — Baseline

Medir antes de ajustar más la configuración: violaciones de dependencias,
serialización innecesaria, tareas cerradas sin evidencia, receipts faltantes,
recuperación después de compactación, retries, latencia y tokens. Repetir cada
escenario varias veces; una sola corrida no prueba una mejora.

### Fase 1 — Contrato y gate determinista (implementada)

- Reutilizar `sdd-tasks.md` como roadmap durable, sin crear otra herramienta de
  planificación.
- Exigir en cada task description `ROADMAP`, `DEPENDS_ON`, `PATHS`,
  `ACCEPTANCE`, `VERIFY` y `RECEIPT`.
- Bloquear `TaskCreated` si el contrato o el roadmap no existe.
- Bloquear `TaskCompleted` si el receipt no existe, no coincide el `TASK_ID` o
  no contiene `STATUS: PASS`, `ACCEPTANCE: PASS`, `VERIFY_EXIT: 0` y evidencia
  no vacía.
- No ejecutar texto arbitrario de `VERIFY` desde un hook; la evidencia la corre
  el agente mediante el comando nativo del proyecto.
- Emitir métricas observacionales del DAG (`--json`): camino crítico, frontier
  teórica, niveles, tareas ejecutables y tareas bloqueadas. No se interpreta
  ese reporte como prueba automática de independencia de archivos.

### Fase 2 — Recuperación y replanificación acotada

`compact-resume.py` ya reinyecta el roadmap activo y sus tareas marcadas. El
workflow SDD ahora fija la política de ejecución: después de dos fallos del
mismo task se propone una sola re-descomposición; se preservan nodos validados
y se exige aprobación humana si cambia el alcance. Esto es una política
determinista de seguridad, no un planner adaptativo automático.

### Fase 3 — Evaluación comparativa

Construir fixtures con DAG lineal, DAG con ramas independientes, DAG con
dependencia falsa y tarea que falla dos veces. Comparar baseline contra cada
cambio usando correctness, dependency violations, unnecessary serialization,
premature completion, receipt completeness, retries, latency y tokens; usar
las métricas de frontier/camino crítico como diagnóstico, no como resultado de
calidad por sí mismas.

El primer instrumento ya está implementado en
`config/claude/scripts/compare-task-roadmaps.sh`: compara dos DAGs válidos y
emite JSON con camino crítico, frontier teórica, estados, deltas y el estado
de independencia del candidato. El candidato debe declarar `[paths: ...]` con
ownership concreto, sin globs ambiguos ni solapamientos estáticos; su fixture demuestra una serialización
artificial de 4 niveles frente a una variante de 3 niveles con una frontera de
2 tareas. Esto valida la estructura y el ownership anotado, no la seguridad
del repositorio ni la correctness del modelo; esas dimensiones siguen
requiriendo una evaluación multi-run real.

### Fase 3.1 — Enrutamiento automático de oneshots (implementada en fuente)

- Añadir clasificación determinista de prompt accionable versus conversación,
  incluyendo objetivos expresados como resultado esperado (por ejemplo,
  "quiero que funcione"), sin ejecutar contenido del prompt ni activar un gate
  duplicado para slash commands.
- Crear estado temporal por sesión fuera del repositorio y reinyectar el
  contrato en seguimientos de la misma tarea.
- Exigir un roadmap completo, receipt PASS, `git diff --check` y runner nativo
  fresco en Stop; mantener el bypass sólo como `.claude-relaxed` explícito.
- Cubrir conversación, primera instrucción, seguimiento, slash command,
  intención de resultado, intención informativa, receipt ausente, roadmap
  pendiente y suite RED con fixtures locales.
- Mantener `CLAUDE.md` bajo 200 líneas y cargar el detalle de los workflows sólo
  desde skills; el host observado es Claude Code `2.1.234` sin override de
  `CLAUDE_CODE_ENABLE_TASKS`.

La fase está implementada y validada en la configuración fuente. La prueba
contractual local cubre el ciclo completo sin inferencia:
`config/claude/scripts/smoke-automatic-workflow.sh` activa el oneshot, fuerza un
bloqueo por roadmap incompleto, valida `TaskCreated`/`TaskCompleted` y deja que
Stop acepte sólo después de receipts, DAG, `git diff --check` y runner verde.
Eso no sustituye el smoke conversacional real.

### Fase 4 — Activación del runtime efectivo

Esta fase no se puede marcar como completada desde la fuente. El orden
reproducible es:

1. Ejecutar `check-runtime-parity.sh --json` y guardar el estado inicial.
2. Revisar el `--dry-run` del sincronizador acotado.
3. Autorizar explícitamente `sync-convergence-runtime.sh --apply`.
4. Verificar `check-runtime-parity.sh --strict` y conservar los backups.
5. Ejecutar `claude doctor` como chequeo de instalación, recordando que no
   prueba la ejecución de hooks. Ejecutar primero
   `bash config/claude/scripts/smoke-claude-hook-engine.sh`, que monta un HOME
   temporal, sincroniza el harness, ejecuta `--init-only` y verifica
   `SessionStart`/`compact-resume` sin inferencia. Ejecutar también
   `bash config/claude/scripts/smoke-automatic-workflow.sh` para el contrato
   determinista sin inferencia. Después ejecutar un smoke real con
   `claude -p --include-hook-events --output-format stream-json` en un repo
   temporal confiable, sin `--bare` ni `--safe-mode`, y con presupuesto acotado.
   Observar `UserPromptSubmit`, `TaskCreated`/`TaskCompleted`, Stop hook y una
   tarea que falle antes de pasar.
6. Repetir el smoke en modo interactivo si el flujo print no expone alguna
   transición de UI; sólo después declarar que el gate está activo. Un smoke
   `--init-only` sí prueba la carga del motor de hooks y `SessionStart`, pero
   no sustituye la observación de `UserPromptSubmit`, `TaskCreated`/
   `TaskCompleted` y `Stop` durante una conversación.

En pruebas conversacionales reales posteriores con Claude Code 2.1.234 y el
runtime efectivo se observaron dos niveles de evidencia:

- un oneshot directo llegó a `CLAUDE_RC=0`: Claude creó el artefacto, corrigió
  el formato del roadmap, ejecutó `./test.sh`, escribió el receipt y Stop
  terminó con `exit_code: 0`; Claude Code trató `.claude/task-roadmap.md` como
  `sensitive file`, por lo que usó temporalmente `TASK-ROADMAP.md` en la raíz;
- un oneshot con dos tareas mostró dos `TaskCreate`, `TaskCreated` PASS,
  dependencia `T002 -> T001`, `TaskCompleted` bloqueado una vez por un
  `TASK_ID` de receipt incorrecto, corrección, `TaskCompleted` PASS y Stop
  PASS. La misma corrida reveló que el modelo había creado dos aliases de
  roadmap (`TASK-ROADMAP.md` y `task-roadmap.md`), por lo que la fuente ahora
  exige una sola ruta y Stop bloquea copias distintas.

Una corrida adicional fue bloqueada antes de inferencia por el detector de
secretos: el `cwd` temporal contenía `task-oneshot-...` y el detector escaneaba
el payload JSON completo, confundiendo el substring `sk-` con una clave. La
fuente ya corrige esto parseando sólo `.prompt`; el detector quedó incluido en
la lista administrada por el sincronizador y debe pasar parity antes del
próximo smoke efectivo.

El sincronizador acotado activa sólo el enforcement del harness. No actualiza
providers ni cambia el profile OpenSpec, porque esas son decisiones de alcance
distintas y pueden alterar el comportamiento normal de Claude.

### Fase 5 — Paridad y evaluación de providers

La configuración fuente contiene overlays para DeepSeek, GLM, Kimi, MiniMax,
Ollama, OpenRouter y Qwen. Antes de atribuir una mejora al harness hay que
separar tres gates:

- **configuración:** JSON, endpoint, variables, modelo, contexto y helper;
- **runtime:** el overlay fuente correcto existe en `~/.claude` y no está
  driftado;
- **servicio:** una llamada autenticada real responde y soporta el contrato de
  Claude Code.

El gate de configuración no prueba autenticación ni inferencia. Para cada
provider se debe registrar modelo solicitado, respuesta HTTP, latencia, tokens,
errores, retries y comportamiento de tools; nunca se deben imprimir claves.
La comparación final debe usar el mismo corpus de tareas y separar el efecto
del provider del efecto del harness.

### Estado y límites

Las Fases 1, 2 y 3.1 están implementadas en la configuración fuente. El gate
tiene fixtures de bloqueo/recuperación, smoke del CLI OpenSpec 1.9.0, smoke de
motor `SessionStart` y dos conversaciones reales que probaron UserPromptSubmit,
Task tools, receipts y Stop. La corrección más reciente de ruta única y
secret-detect todavía está sólo en la fuente hasta una sincronización
autorizada; por eso el resultado correcto sigue siendo parcial, no “harness
superior”. No se añade scheduler, base de datos, agente nuevo ni paralelismo
global. La integración Qwen queda como gate independiente: parseo/carga aislada
no equivale a una llamada autenticada.

### Auditoría de cumplimiento del objetivo

La investigación no declara éxito por ausencia de errores visibles. Cada
requisito tiene una evidencia concreta y una brecha explícita:

| Requisito | Estado actual | Evidencia fuerte | Brecha que impide declararlo completo |
|---|---|---|---|
| Plan de investigación reproducible | Implementado | Este documento, gap analysis, métricas y fases 0–3 | Falta ejecutar la evaluación comparativa multi-run |
| Roadmap durable y reanudable | Parcialmente implementado | `compact-resume.py`, validador DAG, single-roadmap gate y OpenSpec `status/doctor` | No se restaura automáticamente el task registry nativo |
| Serialización con dependencias verificables | Implementado a nivel de contrato | `validate-task-roadmap.py`, receipts y hooks | No existe Planner/Executor que infiera ownership o independencia |
| Iteración hasta aceptación | Implementado como política y gate Stop bloqueante, con smoke conversacional real | `CLAUDE.md`, `sdd-workflow`, `openspec/config.yaml`, hooks automáticos, fixtures y stream real con TaskCompleted bloqueado/corregido y Stop PASS | La aceptación semántica no se puede inferir sólo desde shell; falta repetir contra baseline y probar OpenSpec conversacional |
| Activación desde lenguaje natural | Verificada parcialmente en runtime real | `UserPromptSubmit` real, contexto automático, dos `TaskCreate`, `TaskCreated`/`TaskCompleted`, Stop y receipts observados en stream JSON | La fuente tiene correcciones nuevas de roadmap único y secret-detect aún no sincronizadas; faltan falsos positivos/negativos multi-run y provider alternativo |
| OpenSpec operativo | Verificado en este repo | `openspec --version`, `status --json`, `doctor --json` | Profile `core` no genera `/opsx:verify`; `.gitignore` requiere decisión |
| Comandos OpenSpec dentro de Claude Code | No demostrado; actualmente ausentes en el runtime auditado | `openspec --help` expone CLI y `find ~/.claude` sólo encuentra `sdd-workflow/SKILL.md` | Falta autorizar/verificar `openspec init --tools claude`; status del CLI no prueba detección de `/opsx:*` |
| Superioridad frente al harness actual | No demostrado | Sólo hay fixtures deterministas y validaciones locales | Faltan baseline, repetición, latencia, tokens, correctness y serialización innecesaria |

La conclusión correcta por ahora es **fuente preparada y parcialmente
verificada**, no "harness superior". Esa afirmación sólo será válida después
de ejecutar la Fase 3 con varias corridas y comparar contra un baseline sin
contratos ni recuperación.

### Estado OpenSpec verificado

OpenSpec sí está operativo en este repositorio. La evidencia observada en el
runtime es:

- `openspec --version` devuelve `1.9.0`;
- `openspec status --json` resuelve la raíz del checkout de `dotfiles` y
  reporta que no hay changes activos;
- `openspec doctor --json` es saludable;
- `openspec validate --all --json` termina bien, aunque actualmente es vacuo
  porque no hay un change activo;
- el profile global observado es `core`, por lo que el runtime generado no
  incluye `/opsx:verify`;
- el runtime auditado no contiene comandos `/opsx:*`; sólo aparece la skill
  `sdd-workflow`. Tener el CLI instalado no prueba que Claude Code detecte los
  comandos, que se generan por separado con `openspec init --tools claude`;
- la auditoría read-only `config/claude/scripts/check-runtime-parity.sh
  --json` separa fuente y runtime: antes de las últimas correcciones el
  runtime efectivo tenía parity PASS; ahora reporta drift en los archivos
  modificados de ruta única y en `hooks/secret-detect.sh` hasta una
  sincronización autorizada;
- existe un sincronizador acotado `sync-convergence-runtime.sh`, pero sólo se
  puede ejecutar con `--apply` después de autorización: crea backups, fusiona
  los cuatro registros de hooks y no elimina archivos runtime-only;
- un smoke en un proyecto temporal con el CLI real validó un change completo:
  el gate permitió PASS con receipt y suite verde, y después devolvió exit 2
  con `stop_hook_active=true` cuando la suite pasó a RED;
- un smoke aislado con `claude --init-only` y el runtime fusionado confirmó que
  Claude Code 2.1.234 carga los settings y ejecuta `SessionStart`; no hubo
  llamada de inferencia ni modificación de `~/.claude`;
- dos smokes separados con `claude -p --include-hook-events` confirmaron que el
  motor real ejecuta `UserPromptSubmit`, recibe el contexto automático, usa
  Task tools y llega a Stop PASS en repos temporales; uno bloqueó y corrigió un
  receipt con `TASK_ID` incorrecto. El fake endpoint de la prueba inicial no
  completó la llamada, por lo que esa evidencia inicial queda limitada a
  activación/context injection;
- el smoke reproducible está encapsulado en
  `config/claude/scripts/smoke-claude-hook-engine.sh` y valida además paridad
  del runtime temporal;
- `openspec/` existe, pero el proyecto todavía requiere decidir si sus
  artefactos locales quedan ignorados o versionados; no se modifica `.gitignore`
  automáticamente.

La fuente ya usa `openspec/specs/` + `openspec/changes/`; los templates y el
scaffolder `specs/` quedaron marcados como compatibilidad legacy. Para una
implementación real, `/opsx:apply` se activa con
`~/.claude/scripts/convergence-start.sh <change-name>` y el Stop gate bloquea
hasta que los checks pasen. La instalación/configuración del CLI y el profile
no sustituyen ese gate.

El criterio de convergencia queda explícito: los ciclos de fallo/replanificación
son límites contra repetir la misma hipótesis, no un límite para abandonar la
solución. La IA debe continuar `verify → diagnose → apply` hasta que toda la
evidencia de aceptación pase; si no puede continuar, debe declarar un bloqueo
real o pedir una decisión, nunca cerrar con una solución parcial.

## 8. Protocolo de evaluación del harness

La frase “que siga hasta que funcione” necesita una definición operativa. No
significa reintentar ciegamente ni permitir un loop infinito: significa que la
salida `PASS` queda prohibida hasta que un verificador externo al modelo
confirme todos los criterios de aceptación. Si se agota un presupuesto de
seguridad, se declara `BLOCKED`, nunca `DONE`.

### 8.1 Unidad experimental

Cada escenario debe tener un repositorio/fixture congelado, prompt inicial,
modelo, provider, versión de Claude Code, versión de OpenSpec, versión de
dependencias, timeout, presupuesto de tokens y semilla documentados. Se
comparan al menos dos tratamientos:

1. **Baseline:** mismo flujo y tarea, sin contrato de tareas, receipts ni
   Stop gate de convergencia.
2. **Candidate:** configuración fuente actual, con contrato, DAG, recuperación
   y gate de convergencia.

La comparación debe ser pareada: misma tarea y condiciones en ambos
tratamientos. Una sola corrida sólo demuestra que una corrida terminó; no
demuestra una mejora del harness.

### 8.2 Métrica primaria y regla de parada

La métrica primaria es **end-to-end acceptance pass rate**: porcentaje de
corridas donde todos los criterios de aceptación, tests nativos, validaciones
del cambio y evidencia requerida pasan en una ejecución fresca. No cuentan
como éxito:

- que el modelo diga “listo”;
- que el diff aplique limpio;
- que Git tenga cambios o quede limpio;
- que no haya tareas `pending` visibles si la aceptación no pasó;
- que un test aislado pase mientras otro criterio obligatorio falla.

La máquina de estados correcta es:

```text
PENDING → APPLYING → VERIFYING
                     ├─ PASS → DONE
                     └─ FAIL → DIAGNOSE → APPLYING
```

`DONE` requiere receipt final con `STATUS: PASS`, `ACCEPTANCE: PASS`,
`VERIFY_EXIT: 0` y evidencia no vacía. `BLOCKED` sólo representa una
impedimenta real —por ejemplo, credencial/decisión/dato externo faltante— o
un kill switch de seguridad; no es un atajo para convertir una solución
parcial en éxito.

### 8.3 Métricas secundarias

Registrar por corrida, sin usarlas para reemplazar correctness:

- premature completion: intentos de cerrar con aceptación o verificación
  fallida;
- violaciones de dependencia y tareas ejecutadas fuera del DAG;
- serialización innecesaria: camino crítico real frente al DAG mínimo
  justificado, no sólo frente a la frontera teórica;
- cantidad de iteraciones `verify → diagnose → apply`, reintentos y
  replanificaciones;
- tiempo de pared, tokens de entrada/salida, costo estimado y número de
  compactaciones/recuperaciones;
- intervención humana, cambios de alcance, regresiones y tamaño del diff;
- divergencia entre el task registry nativo, el roadmap versionado y los
  receipts en disco.

Los fallos deben clasificarse antes de modificar el harness: plan incorrecto,
dependencia falsa, dependencia omitida, ejecución defectuosa, verificador
insuficiente, pérdida de contexto, provider/modelo no disponible o bloqueo
externo. Así se evita “mejorar” el número de reintentos ocultando el problema
real.

### 8.4 Criterio para afirmar mejora

El candidate no se puede llamar “superior” por ganar en latencia o costo si
baja la tasa de aceptación. La decisión debe exigir, como mínimo:

1. no degradar la métrica primaria frente al baseline;
2. reducir premature completion y violaciones de dependencia;
3. reportar intervalos de confianza o bootstrap pareado, no sólo promedios;
4. separar resultados por clase de tarea: secuencial, paralelizable,
   dependencia falsa, fallo recuperable y tarea con compactación;
5. repetir la prueba después de cualquier cambio de modelo/provider.

Si hay trade-off, el resultado correcto es “mejora en X con regresión en Y”,
no “harness superior”. Esto es especialmente importante porque los benchmarks
de agentes muestran que la corrección end-to-end puede ser baja incluso cuando
el modelo parece competente en pasos aislados: SWE-bench mide issues reales de
repositorios, y WebArena mide tareas web largas con verificación funcional.

## 9. Fuentes verificadas y matriz de evidencia

La lista siguiente supera las 20 fuentes solicitadas. Se separa evidencia
académica de reportes industriales y documentación de producto. “Soporta”
indica qué decisión informa; no significa que la fuente pruebe que este
harness funcione ni que los resultados sean transferibles sin una evaluación
local.

### 9.1 Planificación, descomposición y feedback

| # | Fuente primaria | Tipo | Soporta | No permite concluir |
|---:|---|---|---|---|
| 1 | [LLMCompiler](https://arxiv.org/abs/2312.04511) | ICML 2024 | Plan explícito, task fetching y ejecución paralela; reporta speedup/costo/accuracy frente a ReAct | Que cualquier DAG generado sea seguro o que la paralelización preserve correctness en este repo |
| 2 | [ADaPT](https://aclanthology.org/2024.findings-naacl.264/) | Findings NAACL 2024 | Descomposición recursiva bajo demanda cuando el executor no puede ejecutar la subtarea | Que una replanificación ilimitada sea segura o barata |
| 3 | [ReAct](https://arxiv.org/abs/2210.03629) | conferencia | Intercalar razonamiento, acción y observación para adaptar el plan | Que un loop intercalado tenga aceptación durable sin un verificador externo |
| 4 | [ReWOO](https://arxiv.org/abs/2305.18323) | paper | Separar plan/razonamiento de observaciones para reducir dependencia del contexto | Que separar el plan elimine errores de ejecución o stale plans |
| 5 | [Plan-and-Solve](https://arxiv.org/abs/2305.04091) | paper | Generar primero un plan y luego resolver sus pasos | Que el plan inicial sea correcto frente a cambios del entorno |
| 6 | [Reflexion](https://arxiv.org/abs/2303.11366) | paper | Feedback verbal y memoria episódica para mejorar intentos posteriores | Que la autoevaluación del mismo modelo sea evidencia suficiente |
| 7 | [Self-Refine](https://arxiv.org/abs/2303.17651) | paper | Refinamiento iterativo usando feedback y nueva generación | Que el feedback interno detecte todos los defectos relevantes |
| 8 | [Tree of Thoughts](https://arxiv.org/abs/2305.10601) | NeurIPS 2023 | Explorar, autoevaluar y retroceder entre caminos de solución | Que explorar más caminos sea mejor para cambios de código con estado compartido |
| 9 | [Graph of Thoughts](https://arxiv.org/abs/2308.09687) | AAAI 2024 | Modelar dependencias y loops de feedback como grafo | Que un grafo de pensamientos sea equivalente a un DAG de archivos/tareas |

### 9.2 Frameworks, interfaces y tareas de ingeniería

| # | Fuente primaria | Tipo | Soporta | No permite concluir |
|---:|---|---|---|---|
| 10 | [TaskWeaver](https://arxiv.org/abs/2311.17541) | paper | Interfaz code-first para tareas con estructuras de datos y plugins | Que agregar una interfaz de código garantice convergencia |
| 11 | [SWE-bench](https://arxiv.org/abs/2310.06770) | ICLR 2024 | Evaluación reproducible sobre issues reales y cambios multiarchivo | Que pasar tests locales equivalga a resolver el issue completo |
| 12 | [SWE-agent](https://arxiv.org/abs/2405.15793) | paper | El diseño de la agent-computer interface afecta navegación, edición y ejecución | Que la ACI de Claude tenga los mismos resultados o contratos |
| 13 | [OpenHands](https://arxiv.org/abs/2407.16741) | ICLR 2025 | Plataforma con sandbox, coordinación y benchmarks de agentes de software | Que una plataforma general sea necesaria para este harness |
| 14 | [AgentBench](https://arxiv.org/abs/2308.03688) | ICLR 2024 | Benchmark multidimensional y fallos de razonamiento largo, decisión e instruction following | Que un benchmark agregado prediga el comportamiento en dotfiles |
| 15 | [WebArena](https://arxiv.org/abs/2307.13854) | benchmark académico | Correctness funcional end-to-end en tareas web largas y reproducibles | Que un agente que completa pasos aislados complete el objetivo real |
| 16 | [OSWorld](https://arxiv.org/abs/2404.07972) | benchmark académico | Evaluación en entornos de computador reales y tareas multimodales abiertas | Que una prueba de shell cubra interacción de escritorio |
| 17 | [MLAgentBench](https://arxiv.org/abs/2310.03302) | benchmark académico | Tareas de experimentación ML con feedback del entorno | Que todos los dominios compartan la misma granularidad de tareas |
| 18 | [AndroidWorld](https://arxiv.org/abs/2405.14573) | benchmark académico | Entorno dinámico para agentes y evaluación de tareas de larga duración | Que la repetición de una tarea sea determinista sin congelar el entorno |

### 9.3 Fallos, contexto y coordinación

| # | Fuente primaria | Tipo | Soporta | No permite concluir |
|---:|---|---|---|---|
| 19 | [Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657) | paper/preprint | Taxonomía MAST: diseño, desalineación entre agentes y verificación; 1.600+ trazas anotadas | Que la multi-agent coordination sea la solución para todo; también evidencia fallos |
| 20 | [Context Rot](https://www.trychroma.com/research/context-rot) | reporte técnico | El rendimiento no es uniforme al crecer el input; evalúa 18 LLMs y limita lo que prueba NIAH | Que aumentar el context window resuelva pérdida de saliencia o coherencia |
| 21 | [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | ingeniería Anthropic | Contexto como recurso finito; compaction, structured note-taking y just-in-time retrieval | Que una recomendación de Anthropic sea una garantía independiente para otro provider |
| 22 | [Anthropic multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) | ingeniería Anthropic | Cuándo la exploración paralela ayuda y qué costos de coordinación/evaluación introduce | Que paralelizar cambios acoplados sea seguro |
| 23 | [Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents) | ingeniería Cognition | Riesgo de decisiones incompatibles cuando subagentes trabajan con contexto parcial | Que un único agente siempre sea mejor |
| 24 | [Plan-and-Execute Agents](https://www.langchain.com/blog/planning-agents) | ingeniería LangChain | Trade-offs de planner/executor y replanificación | Que una implementación de framework sea evidencia académica de eficacia |

### 9.4 Enforcement del producto usado

| # | Fuente primaria | Tipo | Soporta | No permite concluir |
|---:|---|---|---|---|
| 25 | [Claude Code hooks](https://code.claude.com/docs/en/hooks) | documentación oficial | Hooks determinísticos pueden observar eventos y usar exit 2 para impedir una transición | Que el hook arregle el problema; sólo impide avanzar y fuerza otra iteración |
| 26 | [Claude Code hook guide](https://code.claude.com/docs/en/hooks-guide) | documentación oficial | `UserPromptSubmit` puede inyectar `additionalContext`; `Stop` puede devolver `decision: block`; los hooks prompt-based son una inferencia separada | Que un hook de shell pueda juzgar aceptación semántica o que un hook prompt sea evidencia externa |
| 27 | [Claude Code tools reference](https://code.claude.com/docs/en/tools-reference) | documentación oficial | `TaskCreate`, `TaskGet`, `TaskList` y `TaskUpdate` son la interfaz estructurada de tareas; `TaskCreated`/`TaskCompleted` son eventos gobernables | Que una task list runtime sea un roadmap durable o que el hook conozca la corrección del código |
| 28 | [Claude Code todo/task tracking](https://code.claude.com/docs/en/agent-sdk/todo-tracking) | documentación oficial | Desde Claude Code `2.1.142`, Task tools reemplazan el flujo `TodoWrite` por defecto; las dependencias se actualizan explícitamente | Que el host no pueda deshabilitar Tasks por entorno o que la sesión auditada ya los haya usado |
| 29 | [Claude Code skills](https://code.claude.com/docs/en/slash-commands) | documentación oficial | Las descripciones de skills se descubren al inicio y el cuerpo se carga cuando Claude la invoca; `user-invocable: false` permite un skill sólo de fondo | Que describir un skill garantice que el modelo lo invoque en cada prompt |
| 30 | [Claude Code context window](https://code.claude.com/docs/en/context-window) | documentación oficial | Cómo se administra contexto, compactación y memoria en Claude Code | Que la configuración fuente implique que el runtime ya esté sincronizado |
| 31 | [Claude Code CLI usage](https://code.claude.com/docs/en/cli-usage) | documentación oficial | `--include-hook-events` requiere `stream-json`; `--init-only` y `--max-budget-usd` permiten smoke controlado | Que el stream pruebe autenticación, correctness o convergencia del agente |
| 32 | [Claude Code debug configuration](https://code.claude.com/docs/en/debug-your-config) | documentación oficial | Dónde se resuelven settings/hooks y cómo diagnosticar hooks que no disparan | Que leer settings equivalga a observar una sesión real |

La conclusión metodológica de las 32 fuentes es convergente: planificar y
paralelizar puede reducir costo o tiempo cuando existe independencia real;
descomponer o delegar también puede introducir desalineación y overhead. La
propiedad que el harness debe garantizar no es “más agentes” ni “más tareas”,
sino **no permitir la transición a éxito sin evidencia fresca de aceptación**.

La distinción entre los grupos importa para la discusión universitaria: los
papers y benchmarks tienen metodología y baselines propios; los reportes de
ingeniería describen sistemas reales pero no son validación independiente; la
documentación de Claude describe el contrato del producto, no el rendimiento
de este repositorio. La única afirmación sobre este harness debe salir de la
Fase 3 y de un smoke real en el runtime efectivo.
