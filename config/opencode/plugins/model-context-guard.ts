import * as fs from "node:fs/promises"
import * as os from "node:os"
import * as path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

type ModelRef = {
  providerID: string
  modelID: string
  context: number
}

const SMALL_CONTEXT_THRESHOLD = 250000
const DEFAULT_OUTPUT_CAP = 64000

function modelKey(model: ModelRef): string {
  return `${model.providerID}/${model.modelID}`
}

export const ModelContextGuard: Plugin = async ({ client, project }) => {
  const lastModelBySession = new Map<string, ModelRef>()
  const compacting = new Set<string>()

  const logDir = path.join(
    os.homedir(),
    ".local",
    "share",
    "opencode",
    "model-guard",
    project.id,
  )
  const logFile = path.join(logDir, "model-guard.log")

  async function debug(message: string): Promise<void> {
    try {
      await fs.mkdir(logDir, { recursive: true })
      await fs.appendFile(logFile, `${new Date().toISOString()}: ${message}\n`)
    } catch {
      // best-effort logging only
    }
  }

  async function summarizeWithModel(
    sessionID: string,
    model: ModelRef,
    label: string,
  ): Promise<boolean> {
    try {
      await client.session.summarize({
        sessionID,
        providerID: model.providerID,
        modelID: model.modelID,
        auto: true,
      })
      await debug(
        `compaction success (${label}) session=${sessionID} model=${modelKey(model)} context=${model.context}`,
      )
      return true
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error)
      await debug(
        `compaction failed (${label}) session=${sessionID} model=${modelKey(model)} error=${text}`,
      )
      return false
    }
  }

  return {
    // Auto-compact when user switches from a larger-context model to a smaller one.
    // This prevents immediate overflow errors after model switches in long sessions.
    "chat.message": async (input) => {
      if (!input.model) return

      const current: ModelRef = {
        providerID: input.model.providerID,
        modelID: input.model.modelID,
        context: input.model.limit?.context ?? 0,
      }

      const previous = lastModelBySession.get(input.sessionID)

      if (
        previous &&
        modelKey(previous) !== modelKey(current) &&
        !compacting.has(input.sessionID)
      ) {
        const switchedToSmaller =
          previous.context > 0 && current.context > 0 && current.context < previous.context
        const switchedToSmallWindow = current.context > 0 && current.context <= SMALL_CONTEXT_THRESHOLD

        if (switchedToSmaller || switchedToSmallWindow) {
          compacting.add(input.sessionID)
          await debug(
            `model switch detected session=${input.sessionID} from=${modelKey(previous)}(${previous.context}) to=${modelKey(current)}(${current.context})`,
          )

          // Prefer compacting with the previous (usually larger-window) model.
          // Fall back to the current model if previous is unavailable.
          const ok = await summarizeWithModel(input.sessionID, previous, "previous")
          if (!ok) {
            await summarizeWithModel(input.sessionID, current, "current-fallback")
          }

          compacting.delete(input.sessionID)
        }
      }

      lastModelBySession.set(input.sessionID, current)
    },

    // Keep a generous output cap aligned with the preferred Claude-style setup.
    "chat.params": async (input, output) => {
      const modelOutputLimit = input.model.limit?.output
      if (typeof modelOutputLimit === "number" && modelOutputLimit > 0) {
        output.options = {
          ...output.options,
          maxOutputTokens: Math.min(modelOutputLimit, DEFAULT_OUTPUT_CAP),
        }
      }
    },
  }
}

export default ModelContextGuard
