import type { Plugin } from "@opencode-ai/plugin"

// Detecta debug statements (console.log, print, debugger, etc.)
// despues de editar archivos de codigo.

const DEBUG_PATTERNS: Record<string, RegExp[]> = {
  // JS/TS
  ".ts": [/\bconsole\.(log|warn|error|debug)\(/, /\bdebugger\b/],
  ".tsx": [/\bconsole\.(log|warn|error|debug)\(/, /\bdebugger\b/],
  ".js": [/\bconsole\.(log|warn|error|debug)\(/, /\bdebugger\b/],
  ".jsx": [/\bconsole\.(log|warn|error|debug)\(/, /\bdebugger\b/],
  // Python
  ".py": [/\bprint\s*\(/, /\bbreakpoint\s*\(/, /\bpdb\.set_trace\(/],
  // Ruby
  ".rb": [/\bputs\b/, /\bp\b/, /\bbinding\.pry/, /\bbyebug\b/],
  // Go
  ".go": [/\blog\.Printf?\(/, /\bfmt\.Print/],
  // Rust
  ".rs": [/\bprintln!\(/, /\bdbg!\(/],
  // PHP
  ".php": [/\bvar_dump\(/, /\bdd\(/, /\bdump\(/, /\bprint_r\(/],
}

function getExtension(filePath: string): string {
  const lastDot = filePath.lastIndexOf(".")
  if (lastDot === -1) return ""
  return filePath.slice(lastDot)
}

export const DebugDetect: Plugin = async ({ client }) => {
  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "write" && input.tool !== "edit") return

      const filePath: string = output.args?.filePath ?? output.args?.file_path ?? ""
      const ext = getExtension(filePath)
      const patterns = DEBUG_PATTERNS[ext]
      if (!patterns) return

      const content: string =
        output.args?.content ??
        output.args?.newText ??
        output.args?.oldText ??
        ""

      if (!content) return

      const matches: string[] = []
      for (const pattern of patterns) {
        if (pattern.test(content)) {
          const lines = content.split("\n")
          for (let i = 0; i < lines.length; i++) {
            if (pattern.test(lines[i])) {
              matches.push(`L${i + 1}: ${lines[i].trim()}`)
            }
          }
        }
      }

      if (matches.length > 0) {
        await client.app.log({
          body: {
            service: "debug-detect",
            level: "warn" as const,
            message: `Debug statements detectados en ${filePath}`,
            extra: { matches: matches.slice(0, 10) },
          },
        })
      }
    },
  }
}
