import type { Plugin } from "@opencode-ai/plugin"

// Maneja el ciclo de compaction:
// 1. Inyecta contexto de reglas criticas antes de compactar
// 2. Auto-commitea cambios pendientes antes de compaction

const CRITICAL_RULES = `
IMPORTANTE: Segui aplicando TODAS las reglas de AGENTS.md y rules/common/*.md:
- NO AI FOOTPRINT en commits
- VERIFY FIRST (sin "should work")
- EVIDENCE BEFORE CLAIMS
- LEVERAGE ≠ RELY (ownership total, CI ≠ seguro)
- PRE-COMMIT LITMUS (3 preguntas)
- GOAL-DRIVEN (loop hasta verificado)
- STOP & WAIT en preguntas
- ANTI-TELEPHONE RULE (subagents → archivos, no chat)
- One feature at a time
- No relajes estas reglas post-compaction.
`.trim()

export const CompactionHandler: Plugin = async ({ $ }) => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      // Auto-commit de cambios pendientes
      try {
        await $`git add -A && git diff --cached --quiet || git commit -m "auto-save: pre-compaction checkpoint"`
      } catch {
        // No es un repo git o no hay cambios — ignorar
      }

      // Inyectar reglas criticas en el contexto de compaction
      output.context.push(CRITICAL_RULES)
    },

    "session.compacted": async (_input, _output) => {
      // Post-compaction: intentar guardar en Engram si esta disponible
      try {
        await $`command -v engram >/dev/null 2>&1 && engram save "Compaction checkpoint" "Session compacted at $(date -u +%Y-%m-%dT%H:%M:%SZ)" --type discovery --project session-checkpoints 2>/dev/null || true`
      } catch {
        // Engram no disponible — ignorar
      }
    },
  }
}
