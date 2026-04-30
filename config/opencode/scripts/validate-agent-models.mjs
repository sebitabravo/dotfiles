#!/usr/bin/env node

import { spawnSync } from "node:child_process"
import { promises as fs } from "node:fs"
import path from "node:path"
import os from "node:os"

const args = new Set(process.argv.slice(2))
const shouldApply = args.has("--apply")
const shouldRefresh = !args.has("--no-refresh")

const root = path.join(os.homedir(), ".config", "opencode")
const configPath = path.join(root, "opencode.json")
const subagentModelsPath = path.join(root, "subagent-models.json")
const agentsDir = path.join(root, "agents")

const directFallbacks = {
  "anthropic/claude-haiku-4-20250514": "anthropic/claude-haiku-4-5",
  "anthropic/claude-sonnet-4-20250514": "anthropic/claude-sonnet-4-5",
  "anthropic/claude-opus-4-20250514": "anthropic/claude-opus-4-5",
}

function stripAnsi(text) {
  return text.replace(/\x1B\[[0-9;]*m/g, "")
}

function run(command, commandArgs) {
  const result = spawnSync(command, commandArgs, { encoding: "utf8" })
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(stripAnsi(result.stderr || result.stdout || "Command failed"))
  }
  return stripAnsi(result.stdout)
}

function backupSuffix() {
  return new Date().toISOString().replace(/[:.]/g, "-")
}

async function writeFileWithBackup(filePath, content) {
  const backupPath = `${filePath}.bak.${backupSuffix()}`
  await fs.mkdir(path.dirname(backupPath), { recursive: true })
  try {
    await fs.copyFile(filePath, backupPath)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`Failed to create backup for ${filePath}: ${message}`)
  }
  await fs.writeFile(filePath, content, "utf8")
  return backupPath
}

function parseAvailableModels(output) {
  const models = new Set()
  for (const line of output.split("\n")) {
    const candidate = line.trim()
    if (/^[a-z0-9-]+(?:\/[a-z0-9._:-]+)+$/i.test(candidate)) {
      models.add(candidate)
    }
  }
  return models
}

function splitModelId(fullModelId) {
  const firstSlash = fullModelId.indexOf("/")
  if (firstSlash <= 0 || firstSlash === fullModelId.length - 1) return null
  return {
    provider: fullModelId.slice(0, firstSlash),
    id: fullModelId.slice(firstSlash + 1),
  }
}

function candidateScore(fullModelId) {
  const id = splitModelId(fullModelId)?.id ?? ""
  let score = 0
  if (!/\d{8}$/.test(id)) score += 100
  if (!id.includes("latest")) score += 25
  const numbers = id.match(/\d+/g)?.map(Number) ?? []
  numbers.forEach((n, idx) => {
    score += n / 10 ** idx
  })
  return score
}

function bestCandidate(candidates) {
  if (!candidates.length) return null
  return [...candidates].sort((a, b) => candidateScore(b) - candidateScore(a))[0]
}

function resolveReplacement(model, availableModels) {
  if (availableModels.has(model)) return model

  const direct = directFallbacks[model]
  if (direct && availableModels.has(direct)) return direct

  const parsed = splitModelId(model)
  if (!parsed) return null

  const { provider, id } = parsed

  const withoutDate = id.replace(/-\d{8}$/, "")
  const sameWithoutDate = `${provider}/${withoutDate}`
  if (availableModels.has(sameWithoutDate)) return sameWithoutDate

  const providerModels = [...availableModels].filter((m) => m.startsWith(`${provider}/`))
  if (!providerModels.length) return null

  const familyPrefix = withoutDate.split("-").slice(0, 3).join("-")
  const familyCandidates = providerModels.filter((m) => splitModelId(m)?.id.startsWith(familyPrefix))
  const pickedFamily = bestCandidate(familyCandidates)
  if (pickedFamily) return pickedFamily

  return bestCandidate(providerModels)
}

function upsert(resultList, item) {
  resultList.push(item)
}

async function loadConfigModels() {
  const raw = await fs.readFile(configPath, "utf8")
  const data = JSON.parse(raw)
  const entries = []
  const agents = data.agent ?? {}

  // opencode.json owns runtime config models (small_model + primary agent model).
  // Subagent routing is canonicalized separately in subagent-models.json.

  if (typeof data?.model === "string") {
    upsert(entries, {
      kind: "config-model",
      key: "model",
      filePath: configPath,
      model: data.model,
      apply: (newModel) => {
        data.model = newModel
      },
    })
  }

  if (typeof data?.small_model === "string") {
    upsert(entries, {
      kind: "config-model",
      key: "small_model",
      filePath: configPath,
      model: data.small_model,
      apply: (newModel) => {
        data.small_model = newModel
      },
    })
  }

  for (const [agentName, agent] of Object.entries(agents)) {
    if (typeof agent?.model === "string") {
      upsert(entries, {
        kind: "config-model",
        key: `agent.${agentName}.model`,
        filePath: configPath,
        model: agent.model,
        apply: (newModel) => {
          data.agent[agentName].model = newModel
        },
      })
    }
  }

  return {
    entries,
    save: async () => {
      await writeFileWithBackup(configPath, `${JSON.stringify(data, null, 2)}\n`)
    },
  }
}

async function loadSubagentRegistryModels() {
  const raw = await fs.readFile(subagentModelsPath, "utf8")
  const data = JSON.parse(raw)
  const entries = []
  const subagentModels = data.subagentModels ?? {}

  for (const [agentName, model] of Object.entries(subagentModels)) {
    if (typeof model !== "string") continue
    upsert(entries, {
      kind: "registry-model",
      key: `subagentModels.${agentName}`,
      filePath: subagentModelsPath,
      model,
      apply: (newModel) => {
        data.subagentModels[agentName] = newModel
      },
    })
  }

  return {
    entries,
    getModelMap: () =>
      Object.fromEntries(
        Object.entries(data.subagentModels ?? {}).filter(([, model]) => typeof model === "string"),
      ),
    save: async () => {
      await writeFileWithBackup(subagentModelsPath, `${JSON.stringify(data, null, 2)}\n`)
    },
  }
}

function parseFrontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/)
  if (!match) return null

  const start = match.index ?? 0
  const end = start + match[0].length
  const body = match[1]
  const eol = raw.includes("\r\n") ? "\r\n" : "\n"

  return { start, end, body, eol }
}

function updateSubagentModel(raw, newModel) {
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

async function syncSubagentMarkdown(modelMap) {
  const entries = []
  let files = []
  try {
    files = await fs.readdir(agentsDir)
  } catch {
    return {
      scanned: 0,
      updated: 0,
      missingMappings: [],
      extraMappings: Object.keys(modelMap).sort(),
      stale: [],
    }
  }

  let scanned = 0
  let updated = 0
  const seen = new Set()
  const missingMappings = []

  for (const fileName of files) {
    if (!fileName.endsWith(".md")) continue
    const filePath = path.join(agentsDir, fileName)
    const raw = await fs.readFile(filePath, "utf8")
    const frontmatter = parseFrontmatter(raw)
    if (!frontmatter) continue

    const modeMatch = frontmatter.body.match(/^mode:\s*(.+)$/m)
    if (!modeMatch || modeMatch[1].trim() !== "subagent") continue

    scanned += 1
    const agentName = fileName.replace(/\.md$/, "")
    seen.add(agentName)

    const desiredModel = modelMap[agentName]
    if (!desiredModel) {
      missingMappings.push(agentName)
      continue
    }

    const modelMatch = frontmatter.body.match(/^model:\s*(.+)$/m)
    if (!modelMatch) continue

    const currentModel = modelMatch[1].trim()
    if (currentModel === desiredModel) continue

    upsert(entries, {
      agentName,
      currentModel,
      desiredModel,
    })

    if (shouldApply) {
      const result = updateSubagentModel(raw, desiredModel)
      if (result.changed) {
        await writeFileWithBackup(filePath, result.updated)
        updated += 1
      }
    }
  }

  const extraMappings = Object.keys(modelMap).filter((name) => !seen.has(name)).sort()

  return {
    scanned,
    updated,
    missingMappings: missingMappings.sort(),
    extraMappings,
    stale: entries.sort((a, b) => a.agentName.localeCompare(b.agentName)),
  }
}

async function main() {
  const modelArgs = ["models"]
  if (shouldRefresh) modelArgs.push("--refresh")

  let modelsOutput = ""
  try {
    modelsOutput = run("opencode", modelArgs)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(
      `Unable to run \`opencode ${modelArgs.join(" ")}\`. Verify the CLI is installed and available on PATH. ${message}`,
    )
  }

  const availableModels = parseAvailableModels(modelsOutput)

  if (availableModels.size === 0) {
    throw new Error("No models were detected from `opencode models`.")
  }

  const configBundle = await loadConfigModels()
  const subagentRegistryBundle = await loadSubagentRegistryModels()
  const allEntries = [...configBundle.entries, ...subagentRegistryBundle.entries]

  const report = []
  let changes = 0
  let unresolved = 0
  let configChanged = false
  let subagentRegistryChanged = false

  for (const entry of allEntries) {
    if (availableModels.has(entry.model)) {
      report.push({ key: entry.key, current: entry.model, status: "valid" })
      continue
    }

    const replacement = resolveReplacement(entry.model, availableModels)
    if (!replacement) {
      unresolved += 1
      report.push({ key: entry.key, current: entry.model, status: "invalid", replacement: null })
      continue
    }

    report.push({ key: entry.key, current: entry.model, status: "replaced", replacement })
    if (shouldApply) {
      entry.apply(replacement)
      if (entry.kind === "config-model") configChanged = true
      if (entry.kind === "registry-model") subagentRegistryChanged = true
      changes += 1
    }
  }

  if (shouldApply && configChanged) {
    await configBundle.save()
  }

  if (shouldApply && subagentRegistryChanged) {
    await subagentRegistryBundle.save()
  }

  const subagentSyncReport = await syncSubagentMarkdown(subagentRegistryBundle.getModelMap())
  const hasSubagentSyncIssues =
    subagentSyncReport.missingMappings.length > 0 ||
    subagentSyncReport.extraMappings.length > 0 ||
    (!shouldApply && subagentSyncReport.stale.length > 0)

  process.stdout.write(`Available models: ${availableModels.size}\n`)
  process.stdout.write(`Configured models checked: ${allEntries.length}\n`)
  process.stdout.write(`Changes applied: ${shouldApply ? changes : 0}\n`)
  process.stdout.write(`Unresolved invalid models: ${unresolved}\n\n`)

  for (const item of report) {
    if (item.status === "valid") {
      process.stdout.write(`✓ ${item.key} -> ${item.current}\n`)
      continue
    }
    if (item.status === "replaced") {
      const mode = shouldApply ? "updated" : "would update"
      process.stdout.write(`~ ${item.key} -> ${item.current} (${mode} to ${item.replacement})\n`)
      continue
    }
    process.stdout.write(`✗ ${item.key} -> ${item.current} (no fallback found)\n`)
  }

  process.stdout.write("\n")
  process.stdout.write(`Subagent markdown scanned: ${subagentSyncReport.scanned}\n`)
  process.stdout.write(`Subagent markdown updated: ${shouldApply ? subagentSyncReport.updated : 0}\n`)
  process.stdout.write(`Subagent mappings missing: ${subagentSyncReport.missingMappings.length}\n`)
  process.stdout.write(`Subagent mappings extra: ${subagentSyncReport.extraMappings.length}\n`)

  for (const item of subagentSyncReport.stale) {
    const mode = shouldApply ? "synced to" : "would sync to"
    process.stdout.write(
      `~ agents/${item.agentName}.md:model -> ${item.currentModel} (${mode} ${item.desiredModel})\n`,
    )
  }

  for (const agentName of subagentSyncReport.missingMappings) {
    process.stdout.write(`✗ agents/${agentName}.md -> no mapping in subagent-models.json\n`)
  }

  for (const agentName of subagentSyncReport.extraMappings) {
    process.stdout.write(`✗ subagentModels.${agentName} -> no matching agents/${agentName}.md\n`)
  }

  if (unresolved > 0 || hasSubagentSyncIssues) {
    process.exitCode = 2
  }
}

main().catch((error) => {
  process.stderr.write(`Model validation failed: ${error.message}\n`)
  process.exit(1)
})
