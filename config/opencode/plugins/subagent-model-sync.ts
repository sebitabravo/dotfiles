import * as fs from "node:fs/promises"
import * as os from "node:os"
import * as path from "node:path"
import type { Plugin } from "@opencode-ai/plugin"

type ModelMap = Record<string, string>

type SyncReport = {
  scanned: number
  updated: number
  missingMappings: string[]
  extraMappings: string[]
}

const rootDir = path.join(os.homedir(), ".config", "opencode")
const configPath = path.join(rootDir, "subagent-models.json")
const agentsDir = path.join(rootDir, "agents")

function parseFrontmatter(raw: string): {
  start: number
  end: number
  body: string
  eol: "\n" | "\r\n"
} | null {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/)
  if (!match) return null

  const start = match.index ?? 0
  const end = start + match[0].length
  const body = match[1]
  const eol = raw.includes("\r\n") ? "\r\n" : "\n"

  return { start, end, body, eol }
}

function updateSubagentModel(raw: string, newModel: string): {
  changed: boolean
  updated: string
} {
  const frontmatter = parseFrontmatter(raw)
  if (!frontmatter) return { changed: false, updated: raw }

  const modeMatch = frontmatter.body.match(/^mode:\s*(.+)$/m)
  if (!modeMatch || modeMatch[1].trim() !== "subagent") {
    return { changed: false, updated: raw }
  }

  const modelMatch = frontmatter.body.match(/^model:\s*(.+)$/m)
  if (!modelMatch) return { changed: false, updated: raw }

  const currentModel = modelMatch[1].trim()
  if (currentModel === newModel) {
    return { changed: false, updated: raw }
  }

  const newBody = frontmatter.body.replace(/^model:\s*.+$/m, `model: ${newModel}`)
  const newFrontmatter = `---${frontmatter.eol}${newBody}${frontmatter.eol}---${frontmatter.eol}`
  const updated = `${raw.slice(0, frontmatter.start)}${newFrontmatter}${raw.slice(frontmatter.end)}`

  return { changed: true, updated }
}

async function loadModelMap(): Promise<ModelMap | null> {
  const content = await fs.readFile(configPath, "utf8").catch((error: NodeJS.ErrnoException) => {
    if (error.code === "ENOENT") return null
    throw error
  })

  if (content === null) return null

  const json = JSON.parse(content) as { subagentModels?: unknown }
  if (!json.subagentModels || typeof json.subagentModels !== "object") return null

  const entries = Object.entries(json.subagentModels)
  const validEntries = entries.filter(
    ([, model]) => typeof model === "string" && model.includes("/"),
  ) as Array<[string, string]>

  return Object.fromEntries(validEntries)
}

async function syncSubagentModels(): Promise<SyncReport | null> {
  const modelMap = await loadModelMap()
  if (!modelMap) return null

  const files = (await fs.readdir(agentsDir)).filter((name) => name.endsWith(".md")).sort()

  let scanned = 0
  let updated = 0
  const seen = new Set<string>()
  const missingMappings: string[] = []

  for (const fileName of files) {
    const filePath = path.join(agentsDir, fileName)
    const raw = await fs.readFile(filePath, "utf8")

    const frontmatter = parseFrontmatter(raw)
    if (!frontmatter) continue

    const modeMatch = frontmatter.body.match(/^mode:\s*(.+)$/m)
    if (!modeMatch || modeMatch[1].trim() !== "subagent") continue

    scanned += 1
    const agentName = fileName.replace(/\.md$/, "")
    seen.add(agentName)

    const desired = modelMap[agentName]
    if (!desired) {
      missingMappings.push(agentName)
      continue
    }

    const result = updateSubagentModel(raw, desired)
    if (!result.changed) continue

    await fs.writeFile(filePath, result.updated, "utf8")
    updated += 1
  }

  const extraMappings = Object.keys(modelMap).filter((name) => !seen.has(name)).sort()

  return {
    scanned,
    updated,
    missingMappings: missingMappings.sort(),
    extraMappings,
  }
}

export const SubagentModelSync: Plugin = async ({ client }) => {
  try {
    const report = await syncSubagentModels()
    if (!report) return {}

    const summary = `subagent-model-sync: scanned=${report.scanned} updated=${report.updated} missing=${report.missingMappings.length} extra=${report.extraMappings.length}`
    await client.app.log({
      body: {
        service: "subagent-model-sync",
        level: "info",
        message: summary,
      },
    })
  } catch (error) {
    await client.app
      .log({
        body: {
          service: "subagent-model-sync",
          level: "warn",
          message: `sync failed: ${error instanceof Error ? error.message : String(error)}`,
        },
      })
      .catch(() => {})
  }

  return {}
}

export default SubagentModelSync
