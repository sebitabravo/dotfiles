#!/usr/bin/env python3
"""SessionStart hook — inyecta HANDOFF.md si existe."""
import os, json, sys

handoff_path = os.path.join(os.environ.get('PWD', ''), 'HANDOFF.md')
archived_path = handoff_path + '.archived'

if not os.path.isfile(handoff_path):
    sys.exit(0)

with open(handoff_path) as f:
    content = f.read().strip()

if not content:
    sys.exit(0)

os.rename(handoff_path, archived_path)

output = {
    "hookSpecificOutput": {
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
