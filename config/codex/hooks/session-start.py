#!/usr/bin/env python3
"""Load a bounded HANDOFF.md into a new Codex session when one exists."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0

    cwd = Path(payload.get("cwd") or os.getcwd()).resolve()
    candidates = (cwd / "HANDOFF.md", cwd / ".codex" / "HANDOFF.md")
    handoff = next((path for path in candidates if path.is_file()), None)
    if handoff is None:
        return 0

    try:
        content = handoff.read_text(encoding="utf-8")
    except OSError:
        return 0

    content = content[:12000]
    if len(content) == 12000:
        content += "\n\n[HANDOFF truncado a 12000 caracteres]"

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": (
                f"HANDOFF encontrado en {handoff}. Léelo como contexto de continuidad; "
                "verifica su estado contra los archivos actuales antes de actuar.\n\n"
                + content
            ),
        }
    }
    print(json.dumps(output, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
