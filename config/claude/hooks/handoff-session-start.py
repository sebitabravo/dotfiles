#!/usr/bin/python3
"""SessionStart hook — inyecta HANDOFF.md si existe.

hookSpecificOutput exige hookEventName: sin ese campo Claude Code descarta el
additionalContext. El handoff se archivaba igual, asi que el traspaso se perdia
en silencio. El rename va DESPUES de emitir el JSON por la misma razon.
"""
import json
import os
import sys
from datetime import datetime, timezone

# El cwd real llega por stdin; PWD puede apuntar a otro lado segun como se lance.
try:
    payload = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    payload = {}

cwd = payload.get('cwd') or os.environ.get('PWD', '')
handoff_path = os.path.join(cwd, 'HANDOFF.md')
archived_path = handoff_path + '.archived'

if not os.path.isfile(handoff_path):
    sys.exit(0)

with open(handoff_path) as f:
    content = f.read().strip()

if not content:
    sys.exit(0)

output = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "📋 **HANDOFF from a previous session detected:**\n\n"
            f"{content}\n\n"
            "---\n"
            "**INSTRUCTION:** Read the handoff above. It contains the goal, current state, "
            "key files, changes made, failed attempts and next steps. "
            "Continue EXACTLY from where it was left. Do not repeat work already done."
        )
    }
}
print(json.dumps(output))
sys.stdout.flush()

# Preserve the previous archive. `os.rename()` replaces an existing destination
# on POSIX, which silently discarded the last handoff whenever two sessions
# started before the old archive was reviewed.
if os.path.exists(archived_path):
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    archived_path = f'{archived_path}.{stamp}'
    suffix = 1
    while os.path.exists(archived_path):
        archived_path = f'{handoff_path}.archived.{stamp}.{suffix}'
        suffix += 1

try:
    os.rename(handoff_path, archived_path)
except OSError as exc:
    # The context was already emitted and flushed. Do not turn a successful
    # handoff into a Claude hook error because archiving was unavailable.
    print(f'[handoff] warning: no se pudo archivar {handoff_path}: {exc}', file=sys.stderr)
