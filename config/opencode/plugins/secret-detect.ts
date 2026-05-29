import type { Plugin } from "@opencode-ai/plugin"

// Detecta secrets en inputs de herramientas antes de ejecucion.
// Basado en el hook secret-detect.sh de Claude Code.

const SECRET_PATTERNS: Array<{
  pattern: RegExp
  label: string
}> = [
  // OpenAI
  { pattern: /\bsk-[a-zA-Z0-9]{20,}T3BlbkFJ[a-zA-Z0-9]{16,}\b/, label: "OpenAI API Key" },
  { pattern: /\bsk-proj-[a-zA-Z0-9_-]{40,}\b/, label: "OpenAI Project Key" },
  { pattern: /\bsk-svc[a-zA-Z0-9_-]{40,}\b/, label: "OpenAI Service Key" },

  // Anthropic
  { pattern: /\bsk-ant-api[a-zA-Z0-9_-]{40,}\b/, label: "Anthropic API Key" },

  // Stripe
  { pattern: /\b(sk|pk)_(test|live)_[a-zA-Z0-9]{24,}\b/, label: "Stripe Key" },

  // GitHub
  { pattern: /\bghp_[a-zA-Z0-9]{36,}\b/, label: "GitHub PAT" },
  { pattern: /\bgho_[a-zA-Z0-9]{36,}\b/, label: "GitHub OAuth" },
  { pattern: /\bghu_[a-zA-Z0-9]{36,}\b/, label: "GitHub User-to-Server" },
  { pattern: /\bghs_[a-zA-Z0-9]{36,}\b/, label: "GitHub Server-to-Server" },
  { pattern: /\bghr_[a-zA-Z0-9]{36,}\b/, label: "GitHub Refresh" },

  // AWS
  { pattern: /\bAKIA[0-9A-Z]{16}\b/, label: "AWS Access Key" },
  { pattern: /\b(?:aws_access_key_id|aws_secret_access_key)\s*[:=]\s*['"]?[A-Za-z0-9/+=]{20,}['"]?/, label: "AWS Credential" },

  // Google
  { pattern: /\bAIza[0-9A-Za-z_-]{35}\b/, label: "Google API Key" },
  { pattern: /\b[0-9]+-[a-z0-9_]{32}@developer\.gserviceaccount\.com\b/, label: "Google Service Account" },

  // Slack
  { pattern: /\bxox[baprs]-[0-9a-zA-Z-]{10,}\b/, label: "Slack Token" },

  // JWT (bearer)
  { pattern: /\beyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\b/, label: "JWT Token" },

  // Private key
  { pattern: /-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----/, label: "Private Key" },

  // Square
  { pattern: /\bsq0i-[a-zA-Z0-9_-]{22}\b/, label: "Square Application Secret" },
  { pattern: /\bEAAA[a-zA-Z0-9_-]{40,}\b/, label: "Square Access Token" },

  // Generic high-entropy tokens
  { pattern: /\b(?:api[_-]?key|secret[_-]?key|auth[_-]?token|access[_-]?token|private[_-]?key)\s*[:=]\s*['"][A-Za-z0-9+/=_-]{20,}['"]/, label: "Generic Secret Assignment" },
]

export const SecretDetect: Plugin = async ({ client }) => {
  return {
    "tool.execute.before": async (input, output) => {
      // Escanear comandos bash y writes de archivos
      const targets: string[] = []

      if (input.tool === "bash") {
        targets.push(output.args?.command ?? "")
      } else if (input.tool === "write" || input.tool === "edit") {
        targets.push(output.args?.content ?? "")
        targets.push(output.args?.oldText ?? "")
        targets.push(output.args?.newText ?? "")
      }

      const fullText = targets.join("\n")
      if (!fullText) return

      const found: string[] = []
      for (const { pattern, label } of SECRET_PATTERNS) {
        if (pattern.test(fullText)) {
          found.push(label)
        }
      }

      if (found.length > 0) {
        throw new Error(
          `[SecretDetect] Posible secret detectado: ${found.join(", ")}. ` +
          `Revisa el contenido antes de proceder. ` +
          `Si es intencional, ejecuta manualmente.`
        )
      }
    },
  }
}
