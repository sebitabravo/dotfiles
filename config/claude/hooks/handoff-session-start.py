#!/usr/bin/python3
"""SessionStart hook — inyecta HANDOFF.md si existe.

hookSpecificOutput exige hookEventName: sin ese campo Claude Code descarta el
additionalContext. El handoff se archivaba igual, asi que el traspaso se perdia
en silencio. El rename va DESPUES de emitir el JSON por la misma razon.
"""
import json
import os
import sys

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
            "📋 **HANDOFF de sesión anterior detectado:**\n\n"
            f"{content}\n\n"
            "---\n"
            "**INSTRUCCIÓN:** Leé el handoff arriba. Contiene objetivo, estado actual, "
            "archivos clave, cambios hechos, intentos fallidos y próximos pasos. "
            "Continuá EXACTAMENTE desde donde se dejó. No repitas trabajo ya hecho."
        )
    }
}
print(json.dumps(output))
sys.stdout.flush()

os.rename(handoff_path, archived_path)
