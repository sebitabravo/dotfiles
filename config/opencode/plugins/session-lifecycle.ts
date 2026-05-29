import type { Plugin } from "@opencode-ai/plugin"

// Maneja eventos del ciclo de vida de sesion:
// - Inicio: log de informacion del sistema
// - Idle: notificacion (macOS)

export const SessionLifecycle: Plugin = async ({ client, $ }) => {
  await client.app.log({
    body: {
      service: "session-lifecycle",
      level: "info" as const,
      message: `Session started at ${new Date().toISOString()}`,
    },
  })

  return {
    "session.idle": async () => {
      try {
        await $`osascript -e 'display notification "Session idle" with title "OpenCode"'`
      } catch {
        // osascript no disponible — ignorar
      }
    },
  }
}

// Nota: el checkpoint de fin de sesion se maneja en compaction-handler.ts
// ya que OpenCode no tiene un evento "session.stop" directo.
