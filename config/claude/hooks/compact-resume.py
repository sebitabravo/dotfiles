#!/usr/bin/python3
"""SessionStart hook — reinyecta las reglas y el protocolo post-compactacion.

POR QUE ESTA EN SessionStart Y NO EN PostCompact: la referencia de hooks dice
que PostCompact solo honra `systemMessage`, y que ese campo va al usuario. El
unico canal que llega al MODELO despues de una compactacion es SessionStart con
`session_start_reason == "compact"`, donde si se honra `additionalContext`.
El hook de PostCompact que emitia additionalContext se descartaba entero: la
compactacion se comia las reglas y nada las reponia.

`hookEventName` dentro de hookSpecificOutput es obligatorio; sin ese campo
Claude Code descarta el additionalContext aunque el evento si lo soporte.
"""
import json
import os
import subprocess
import sys

try:
    payload = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    sys.exit(0)

if payload.get('session_start_reason') != 'compact':
    sys.exit(0)

cwd = payload.get('cwd') or os.environ.get('PWD', '')

# El estado del working tree es lo primero que la compactacion vuelve incierto:
# el resumen dice que archivos se tocaron, no cuales siguen sucios ahora.
try:
    status = subprocess.run(
        ['git', '-C', cwd, 'status', '--short'],
        capture_output=True, text=True, timeout=5, check=False,
    ).stdout.strip()
except (OSError, subprocess.SubprocessError):
    status = ''

status_lines = status.splitlines()[:40]
if len(status.splitlines()) > 40:
    status_lines.append(f'... (+{len(status.splitlines()) - 40} archivos mas)')
status_block = '\n'.join(status_lines) or 'working tree limpio'

context = f"""CONTEXTO COMPACTADO. Las reglas NO se relajan post-compactacion.

Siguen vigentes TODAS las de CLAUDE.md y rules/common/*.md — NO AI FOOTPRINT,
VERIFY FIRST (sin "should work"), EVIDENCE BEFORE CLAIMS, LEVERAGE != RELY
(ownership total, CI != seguro), PRE-COMMIT LITMUS (3 preguntas), GOAL-DRIVEN
(loop hasta verificado), STOP & WAIT ante ambiguedad.

Protocolo de reanudacion (rules/common/context-management.md):
1. Re-lee los archivos que estabas editando. NO confies en tu resumen de su
   contenido por encima del archivo.
2. `mem_context` y `mem_search` para recuperar el razonamiento de decisiones ya
   tomadas, en vez de re-derivarlas.
3. NO re-litigues una decision que el usuario ya aprobo.
4. La compactacion no es fin de tarea: retoma el trabajo pendiente, no cierres
   con un resumen.

git status actual:
{status_block}"""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}, ensure_ascii=False))
