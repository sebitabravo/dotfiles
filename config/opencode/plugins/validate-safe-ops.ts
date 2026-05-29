import type { Plugin } from "@opencode-ai/plugin"

// Bloquea comandos peligrosos antes de ejecucion.
// Inspirado en ECC AgentShield + patrones elite 2025-2026.
// Arquitectura: binario-especifico + NO_QUOTES para eliminar falsos positivos.

const DANGEROUS_PATTERNS: Array<{
  pattern: RegExp
  reason: string
  full?: boolean
}> = [
  // Pipe a bash (RCE — multi-linea)
  { pattern: /curl.*\| *(bash|sh|zsh)/, reason: "curl | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado.", full: true },
  { pattern: /wget.*-O\s*-\s*.*\| *(bash|sh|zsh)/, reason: "wget | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado.", full: true },

  // DROP TABLE via echo/printf pipe
  { pattern: /(echo|printf|cat).*\bDROP\s+(TABLE|DATABASE|SCHEMA)\b.*\|/, reason: "DROP TABLE via pipe bloqueado. Ejecuta manualmente si es intencional.", full: true },

  // Destruccion de filesystem
  { pattern: /\brm\s+-rf\b/, reason: "rm -rf bloqueado. Usa mv a trash o git clean en su lugar." },

  // Permisos inseguros
  { pattern: /\bchmod\s+777\b/, reason: "chmod 777 bloqueado. Usa permisos mas restrictivos (644, 755, 700)." },

  // sudo
  { pattern: /^\s*sudo\b/, reason: "sudo bloqueado. Ejecuta sin privilegios elevados." },

  // git push --force (no --force-with-lease)
  { pattern: /\bpush\b.*--force($|[^-])/, reason: "git push --force bloqueado. Usa --force-with-lease si es necesario." },
  { pattern: /\bpush\b.*(\s-f\b|^-f\b)/, reason: "git push -f bloqueado. Usa --force-with-lease si es necesario." },

  // git reset --hard
  { pattern: /\breset\s+.*--hard(\s|$)/, reason: "git reset --hard bloqueado. Usa git stash o git checkout -- <file> para descartes selectivos." },

  // npm install -g
  { pattern: /\b(install|i)\b.*(\s-g(\s|$)|^-g(\s|$))/, reason: "npm install -g bloqueado. Usa npx para herramientas one-shot." },

  // pip --break-system-packages
  { pattern: /\binstall\b.*--break-system-packages/, reason: "pip install --break-system-packages bloqueado. By-passea la proteccion del venv. Usa un venv o uv." },

  // kubectl delete
  { pattern: /^\s*kubectl\s+delete\b/, reason: "kubectl delete bloqueado. Operacion destructiva en el cluster." },

  // helm uninstall/delete
  { pattern: /^\s*helm\s+(uninstall|delete)\b/, reason: "helm uninstall/delete bloqueado. Operacion destructiva en el cluster." },

  // terraform destroy / apply -auto-approve
  { pattern: /\bterraform\s+destroy\b/, reason: "terraform destroy bloqueado. Infraestructura como codigo requiere revision manual." },
  { pattern: /\bterraform\s+apply\b.*-auto-approve/, reason: "terraform apply -auto-approve bloqueado. Infraestructura como codigo requiere revision manual." },

  // DROP TABLE directo
  { pattern: /\bDROP\s+(TABLE|DATABASE|SCHEMA)\b/i, reason: "DROP TABLE/DATABASE bloqueado. Ejecuta manualmente si es intencional." },

  // dd
  { pattern: /\bdd\s+.*\bif=/, reason: "dd bloqueado. Operacion de bajo nivel peligrosa." },

  // mkfs/newfs
  { pattern: /^\s*mkfs(\.\w+)?\b/, reason: "mkfs bloqueado. Formateo de filesystem es irreversible sin backup." },
  { pattern: /^\s*newfs(_msdos)?\b/, reason: "newfs bloqueado. Formateo de filesystem es irreversible sin backup." },
]

// Elimina strings quoted para evitar falsos positivos en mensajes de commit/heredocs
function stripQuotes(cmd: string): string {
  return cmd.replace(/'[^']*'/g, "").replace(/"[^"]*"/g, "")
}

export const ValidateSafeOps: Plugin = async ({ client }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return

      const command: string = output.args?.command ?? ""
      if (!command) return

      const firstLine = command.split("\n")[0]
      const noQuotes = stripQuotes(firstLine)
      const noQuotesFull = stripQuotes(command)

      for (const { pattern, reason, full } of DANGEROUS_PATTERNS) {
        const target = full ? noQuotesFull : noQuotes
        if (pattern.test(target)) {
          throw new Error(reason)
        }
      }
    },
  }
}
