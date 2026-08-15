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
    status_lines.append(f'... (+{len(status.splitlines()) - 40} more files)')
status_block = '\n'.join(status_lines) or 'working tree clean'

context = f"""CONTEXT COMPACTED. The rules are NOT relaxed after compaction.

ALL of CLAUDE.md and rules/common/*.md remain in force — NO AI FOOTPRINT,
VERIFY FIRST (no "should work"), EVIDENCE BEFORE CLAIMS, LEVERAGE != RELY
(full ownership, CI != guarantee), PRE-COMMIT LITMUS (3 questions), GOAL-DRIVEN
(loop until verified), STOP & WAIT on ambiguity.

Resumption protocol (rules/common/context-management.md):
1. Re-read the files you were editing. Do NOT trust your summary of their
   contents over the file.
2. `mem_context` and `mem_search` to recover the reasoning behind decisions
   already made, instead of re-deriving them.
3. Do NOT re-litigate a decision the user already approved.
4. Compaction is not the end of the task: resume the pending work, do not close
   with a summary.

current git status:
{status_block}"""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}, ensure_ascii=False))
