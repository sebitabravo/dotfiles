/**
 * background-agents
 * Sistema de delegación async para OpenCode
 *
 * Reemplaza la delegación sync-only con persistencia a disco.
 * Los outputs de sub-agentes se persisten, el orchestrator recibe solo referencias.
 *
 * Basado en oh-my-opencode por @code-yeongyu (MIT License)
 * https://github.com/code-yeongyu/oh-my-opencode
 *
 * Adaptado de kdcokenny/opencode-background-agents (MIT License)
 * https://github.com/kdcokenny/opencode-background-agents
 *
 * Adaptado de Gentleman.Dots/GentlemanOpenCode (MIT License)
 * https://github.com/gentleman-programming/Gentleman.Dots
 *
 * Adaptaciones para config de Sebastian:
 * - Sin dependencia de Engram (memoria persistente no configurada)
 * - Compaction recovery via plugin hooks propios
 * - Compatible con agentes existentes (sebastian, sdd-*, domain agents)
 */

import * as crypto from "node:crypto"
import * as fs from "node:fs/promises"
import * as os from "node:os"
import * as path from "node:path"
import { stat } from "node:fs/promises"
import { type Plugin, type ToolContext, tool } from "@opencode-ai/plugin"
import type { createOpencodeClient } from "@opencode-ai/sdk"
import type { Event, Message, Part, TextPart } from "@opencode-ai/sdk"

// ==========================================
// TIPOS INLINED: kdco-primitives
// ==========================================

export type OpencodeClient = ReturnType<typeof createOpencodeClient>

// ==========================================
// TIMEOUT HELPER
// ==========================================

class TimeoutError extends Error {
  readonly name = "TimeoutError" as const
  readonly timeoutMs: number
  constructor(message: string, timeoutMs: number) {
    super(message)
    this.timeoutMs = timeoutMs
  }
}

async function withTimeout<T>(
  promise: Promise<T>,
  ms: number,
  message = "Operation timed out",
): Promise<T> {
  if (typeof ms !== "number" || ms < 0)
    throw new Error(`withTimeout: timeout must be a non-negative number, got ${ms}`)
  if (ms === 0) throw new TimeoutError(message, ms)
  let timeoutId: ReturnType<typeof setTimeout>
  return Promise.race([
    promise.finally(() => clearTimeout(timeoutId)),
    new Promise<never>((_, reject) => {
      timeoutId = setTimeout(() => {
        reject(new TimeoutError(message, ms))
      }, ms)
    }),
  ])
}

// ==========================================
// LOGGING
// ==========================================

function logWarn(
  client: OpencodeClient | undefined,
  service: string,
  message: string,
): void {
  if (!client) {
    console.warn(`[${service}] ${message}`)
    return
  }
  client.app.log({ body: { service, level: "warn", message } }).catch(() => {})
}

// ==========================================
// PROJECT ID (identifica el proyecto por git root)
// ==========================================

function hashPath(projectRoot: string): string {
  const hash = crypto.createHash("sha256").update(projectRoot).digest("hex")
  return hash.slice(0, 16)
}

async function getProjectId(projectRoot: string): Promise<string> {
  if (!projectRoot || typeof projectRoot !== "string") {
    throw new Error("getProjectId: projectRoot is required and must be a string")
  }
  const gitPath = path.join(projectRoot, ".git")
  const gitStat = await stat(gitPath).catch(() => null)
  if (!gitStat) return hashPath(projectRoot)

  let gitDir = gitPath
  if (gitStat.isFile()) {
    const content = await Bun.file(gitPath).text()
    const match = content.match(/^gitdir:\s*(.+)$/m)
    if (!match)
      throw new Error(`getProjectId: .git file exists but has invalid format at ${gitPath}`)
    const gitdirPath = match[1].trim()
    const resolvedGitdir = path.resolve(projectRoot, gitdirPath)
    const commondirPath = path.join(resolvedGitdir, "commondir")
    const commondirFile = Bun.file(commondirPath)
    if (await commondirFile.exists()) {
      const commondirContent = (await commondirFile.text()).trim()
      gitDir = path.resolve(resolvedGitdir, commondirContent)
    } else {
      gitDir = path.resolve(resolvedGitdir, "../..")
    }
    const gitDirStat = await stat(gitDir).catch(() => null)
    if (!gitDirStat?.isDirectory())
      throw new Error(`getProjectId: Resolved gitdir ${gitDir} is not a directory`)
  }

  const cacheFile = path.join(gitDir, "opencode")
  const cache = Bun.file(cacheFile)
  if (await cache.exists()) {
    const cached = (await cache.text()).trim()
    if (/^[a-f0-9]{40}$/i.test(cached) || /^[a-f0-9]{16}$/i.test(cached)) return cached
  }

  try {
    const proc = Bun.spawn(["git", "rev-list", "--max-parents=0", "--all"], {
      cwd: projectRoot,
      stdout: "pipe",
      stderr: "pipe",
      env: { ...process.env, GIT_DIR: undefined, GIT_WORK_TREE: undefined },
    })
    const exitCode = await withTimeout(proc.exited, 5000, "git rev-list timed out").catch((e) => {
      if (e instanceof TimeoutError) proc.kill()
      return 1
    })
    if (exitCode === 0) {
      const output = await new Response(proc.stdout).text()
      const roots = output
        .split("\n")
        .filter(Boolean)
        .map((x) => x.trim())
        .sort()
      if (roots.length > 0 && /^[a-f0-9]{40}$/i.test(roots[0])) {
        const projectId = roots[0]
        try {
          await Bun.write(cacheFile, projectId)
        } catch {}
        return projectId
      }
    }
  } catch {}
  return hashPath(projectRoot)
}

// ==========================================
// GENERACIÓN DE IDs LEGIBLES (sin dependencia externa)
// ==========================================

// Diccionarios compactos para IDs memorables tipo "swift-amber-falcon"
const ADJECTIVES = [
  "swift","bold","calm","dark","eager","fair","glad","keen","loud","mild",
  "neat","pale","quick","rare","safe","tall","vast","warm","wise","young",
  "brave","crisp","deep","firm","grand","harsh","icy","just","lush","noble",
  "odd","plain","rich","sharp","thin","vivid","wild","zesty","bright","cool",
  "dry","fresh","gentle","happy","light","merry","proud","quiet","smooth","tough",
]
const COLORS = [
  "amber","azure","beige","black","blue","brass","bronze","brown","coral","cream",
  "crimson","cyan","ebony","emerald","fawn","gold","gray","green","indigo","ivory",
  "jade","khaki","lemon","lilac","lime","maroon","mint","navy","olive","onyx",
  "orange","peach","pearl","pink","plum","red","rose","ruby","rust","sage",
  "sand","scarlet","silver","slate","tan","teal","violet","white","wine","yellow",
]
const ANIMALS = [
  "ant","ape","bat","bear","bee","bird","boar","bull","cat","cod",
  "cow","crab","crow","deer","dog","dove","duck","eagle","eel","elk",
  "emu","falcon","fish","fly","fox","frog","goat","goose","gull","hare",
  "hawk","hen","hog","horse","ibis","jay","kite","lark","lion","lynx",
  "mole","moth","mule","newt","owl","ox","panda","pike","pony","puma",
  "ram","rat","raven","robin","seal","shark","slug","snail","snake","stork",
  "swan","tiger","toad","trout","viper","wasp","whale","wolf","wren","yak",
]

function pickRandom(arr: readonly string[]): string {
  const bytes = crypto.randomBytes(4)
  const index = bytes.readUInt32BE(0) % arr.length
  return arr[index]
}

function generateReadableId(): string {
  return `${pickRandom(ADJECTIVES)}-${pickRandom(COLORS)}-${pickRandom(ANIMALS)}`
}

// ==========================================
// METADATA (usa small_model si está configurado)
// ==========================================

interface GeneratedMetadata {
  title: string
  description: string
}

async function generateMetadata(
  _client: OpencodeClient,
  resultContent: string,
  _parentID: string,
  debugLog: (msg: string) => Promise<void>,
): Promise<GeneratedMetadata> {
  const fallbackMetadata = (): GeneratedMetadata => {
    const firstLine =
      resultContent.split("\n").find((l) => l.trim().length > 0) || "Delegation result"
    const title = firstLine.slice(0, 30).trim() + (firstLine.length > 30 ? "..." : "")
    const description =
      resultContent.slice(0, 150).trim() + (resultContent.length > 150 ? "..." : "")
    return { title, description }
  }

  // Modo estable: evitar session.prompt interno para metadata.
  // Esto previene parse/race issues en runtime y mantiene títulos determinísticos.
  await debugLog("generateMetadata: local-only mode (no model call)")
  return fallbackMetadata()
}

// ==========================================
// TIPOS
// ==========================================

interface SessionMessageItem {
  info: Message
  parts: Part[]
}

interface AssistantSessionMessageItem {
  info: Message & { role: "assistant" }
  parts: Part[]
}

interface DelegationProgress {
  toolCalls: number
  lastUpdate: Date
  lastMessage?: string
  lastMessageAt?: Date
}

const MAX_RUN_TIME_MS = 15 * 60 * 1000 // 15 minutos

interface Delegation {
  id: string
  sessionID: string
  parentSessionID: string
  parentMessageID: string
  parentAgent: string
  prompt: string
  agent: string
  status: "running" | "complete" | "error" | "cancelled" | "timeout"
  startedAt: Date
  completedAt?: Date
  progress: DelegationProgress
  error?: string
  title?: string
  description?: string
  result?: string
}

interface DelegateInput {
  parentSessionID: string
  parentMessageID: string
  parentAgent: string
  prompt: string
  agent: string
}

interface DelegationListItem {
  id: string
  status: string
  title?: string
  description?: string
  agent?: string
}

// ==========================================
// LOGGER
// ==========================================

function createLogger(client: OpencodeClient) {
  const log = (level: "debug" | "info" | "warn" | "error", message: string) =>
    client.app.log({ body: { service: "background-agents", level, message } }).catch(() => {})
  return {
    debug: (msg: string) => log("debug", msg),
    info: (msg: string) => log("info", msg),
    warn: (msg: string) => log("warn", msg),
    error: (msg: string) => log("error", msg),
  }
}

type Logger = ReturnType<typeof createLogger>

// ==========================================
// DETECCIÓN DE CAPACIDADES DE AGENTES
// ==========================================

async function parseAgentMode(
  client: OpencodeClient,
  agentName: string,
  log: Logger,
): Promise<{ isSubAgent: boolean }> {
  try {
    const result = await client.app.agents({})
    const agents = (result.data ?? []) as { name: string; mode?: string }[]
    const agent = agents.find((a) => a.name === agentName)
    return { isSubAgent: agent?.mode === "subagent" }
  } catch (error) {
    log.warn(
      `Agent list fetch failed for "${agentName}", assuming non-sub-agent: ${error instanceof Error ? error.message : String(error)}`,
    )
    return { isSubAgent: false }
  }
}

type PermissionEntry = "ask" | "allow" | "deny" | Record<string, "ask" | "allow" | "deny">

function isPermissionDenied(entry: PermissionEntry | undefined): boolean {
  if (entry === undefined) return false
  if (entry === "deny") return true
  if (typeof entry === "object" && entry["*"] === "deny") return true
  return false
}

async function parseAgentWriteCapability(
  client: OpencodeClient,
  agentName: string,
  log: Logger,
): Promise<{ isReadOnly: boolean }> {
  try {
    const config = await client.config.get()
    const configData = config.data as {
      agent?: Record<
        string,
        {
          permission?: Record<string, PermissionEntry>
        }
      >
    }
    const permission = configData?.agent?.[agentName]?.permission ?? {}

    const editDenied = isPermissionDenied(permission.edit)
    const writeDenied = isPermissionDenied(permission.write)
    const bashDenied = isPermissionDenied(permission.bash)

    return { isReadOnly: editDenied && writeDenied && bashDenied }
  } catch (error) {
    log.warn(
      `Config fetch failed for "${agentName}", assuming write-capable: ${error instanceof Error ? error.message : String(error)}`,
    )
    return { isReadOnly: false }
  }
}

async function resolveAgentModel(
  client: OpencodeClient,
  agentName: string,
  log: Logger,
): Promise<{ providerID: string; modelID: string } | undefined> {
  try {
    const config = await client.config.get()
    const configData = config.data as {
      agent?: Record<string, { model?: string }>
    } | undefined

    const modelStr = configData?.agent?.[agentName]?.model
    if (!modelStr) return undefined

    const slashIndex = modelStr.indexOf("/")
    if (slashIndex === -1) return undefined

    const providerID = modelStr.substring(0, slashIndex)
    const modelID = modelStr.substring(slashIndex + 1)

    await log.info(`resolveAgentModel: ${agentName} -> ${providerID}/${modelID}`)
    return { providerID, modelID }
  } catch {
    return undefined
  }
}

// ==========================================
// DELEGATION MANAGER
// ==========================================

class DelegationManager {
  private delegations: Map<string, Delegation> = new Map()
  private client: OpencodeClient
  private baseDir: string
  private log: Logger
  private pendingByParent: Map<string, Set<string>> = new Map()

  constructor(client: OpencodeClient, baseDir: string, log: Logger) {
    this.client = client
    this.baseDir = baseDir
    this.log = log
  }

  async getRootSessionID(sessionID: string): Promise<string> {
    let currentID = sessionID
    for (let depth = 0; depth < 10; depth++) {
      try {
        const session = await this.client.session.get({
          path: { id: currentID },
        })
        if (!session.data?.parentID) {
          return currentID
        }
        currentID = session.data.parentID
      } catch {
        return currentID
      }
    }
    return currentID
  }

  private async getDelegationsDir(sessionID: string): Promise<string> {
    const rootID = await this.getRootSessionID(sessionID)
    return path.join(this.baseDir, rootID)
  }

  private async ensureDelegationsDir(sessionID: string): Promise<string> {
    const dir = await this.getDelegationsDir(sessionID)
    await fs.mkdir(dir, { recursive: true })
    return dir
  }

  async delegate(input: DelegateInput): Promise<Delegation> {
    const id = generateReadableId()
    await this.debugLog(`delegate() called, generated ID: ${id}`)

    let finalId = id
    let attempts = 0
    while (this.delegations.has(finalId) && attempts < 10) {
      finalId = generateReadableId()
      attempts++
    }
    if (this.delegations.has(finalId)) {
      throw new Error("Failed to generate unique delegation ID after 10 attempts")
    }

    // Validar que el agente existe
    const agentsResult = await this.client.app.agents({})
    const agents = (agentsResult.data ?? []) as {
      name: string
      description?: string
      mode?: string
    }[]
    const validAgent = agents.find((a) => a.name === input.agent)

    if (!validAgent) {
      const available = agents
        .filter((a) => a.mode === "subagent" || a.mode === "all" || !a.mode)
        .map((a) => `- ${a.name}${a.description ? ` - ${a.description}` : ""}`)
        .join("\n")

      throw new Error(
        `Agent "${input.agent}" not found.\n\nAvailable agents:\n${available || "(none)"}`,
      )
    }

    // Crear sesión aislada para la delegación
    const sessionResult = await this.client.session.create({
      body: {
        title: `Delegation: ${finalId}`,
        parentID: input.parentSessionID,
      },
    })

    await this.debugLog(`session.create result: ${JSON.stringify(sessionResult.data)}`)

    if (!sessionResult.data?.id) {
      throw new Error("Failed to create delegation session")
    }

    const delegation: Delegation = {
      id: finalId,
      sessionID: sessionResult.data.id,
      parentSessionID: input.parentSessionID,
      parentMessageID: input.parentMessageID,
      parentAgent: input.parentAgent,
      prompt: input.prompt,
      agent: input.agent,
      status: "running",
      startedAt: new Date(),
      progress: {
        toolCalls: 0,
        lastUpdate: new Date(),
      },
    }

    await this.debugLog(`Created delegation ${delegation.id}`)
    this.delegations.set(delegation.id, delegation)

    // Tracking para notificación batched
    const parentId = input.parentSessionID
    if (!this.pendingByParent.has(parentId)) {
      this.pendingByParent.set(parentId, new Set())
    }
    this.pendingByParent.get(parentId)?.add(delegation.id)
    await this.debugLog(
      `Tracking delegation ${delegation.id} for parent ${parentId}. Pending count: ${this.pendingByParent.get(parentId)?.size}`,
    )

    // Timer de timeout global
    setTimeout(() => {
      const current = this.delegations.get(delegation.id)
      if (current && current.status === "running") {
        this.handleTimeout(delegation.id)
      }
    }, MAX_RUN_TIME_MS + 5000)

    await this.ensureDelegationsDir(input.parentSessionID)

    // Resolver modelo del agente para que use su propio modelo, no el del orchestrator
    const agentModel = await resolveAgentModel(this.client, input.agent, this.log)

    // Lanzar el prompt (async, no bloquea)
    // Anti-recursión: deshabilitar delegación anidada y tools de estado
    this.client.session
      .prompt({
        path: { id: delegation.sessionID },
        body: {
          agent: input.agent,
          ...(agentModel && { model: agentModel }),
          parts: [{ type: "text", text: input.prompt }],
          tools: {
            task: false,
            delegate: false,
            todowrite: false,
            plan_save: false,
          },
        },
      })
      .catch((error: Error) => {
        delegation.status = "error"
        delegation.error = error.message
        delegation.completedAt = new Date()
        this.persistOutput(delegation, `Error: ${error.message}`)
        this.notifyParent(delegation)
      })

    return delegation
  }

  private async handleTimeout(delegationId: string): Promise<void> {
    const delegation = this.delegations.get(delegationId)
    if (!delegation || delegation.status !== "running") return

    await this.debugLog(`handleTimeout for delegation ${delegation.id}`)

    delegation.status = "timeout"
    delegation.completedAt = new Date()
    delegation.error = `Delegation timed out after ${MAX_RUN_TIME_MS / 1000}s`

    try {
      await this.client.session.delete({
        path: { id: delegation.sessionID },
      })
    } catch {}

    const result = await this.getResult(delegation)
    await this.persistOutput(delegation, `${result}\n\n[TIMEOUT REACHED]`)
    await this.notifyParent(delegation)
  }

  private async waitForCompletion(delegationId: string): Promise<void> {
    const pollInterval = 1000
    const startTime = Date.now()

    const delegation = this.delegations.get(delegationId)
    if (!delegation) return

    while (
      delegation.status === "running" &&
      Date.now() - startTime < MAX_RUN_TIME_MS + 10000
    ) {
      await new Promise((resolve) => setTimeout(resolve, pollInterval))
    }
  }

  async handleSessionIdle(sessionID: string): Promise<void> {
    const delegation = this.findBySession(sessionID)
    if (!delegation || delegation.status !== "running") return

    await this.debugLog(`handleSessionIdle for delegation ${delegation.id}`)

    delegation.status = "complete"
    delegation.completedAt = new Date()

    const result = await this.getResult(delegation)
    delegation.result = result

    // Generar título y descripción con small_model
    const metadata = await generateMetadata(
      this.client,
      result,
      delegation.sessionID,
      (msg) => this.debugLog(msg),
    )
    delegation.title = metadata.title
    delegation.description = metadata.description

    await this.persistOutput(delegation, result)
    await this.notifyParent(delegation)
  }

  private async getResult(delegation: Delegation): Promise<string> {
    try {
      const messages = await this.client.session.messages({
        path: { id: delegation.sessionID },
      })

      const messageData = messages.data as SessionMessageItem[] | undefined

      if (!messageData || messageData.length === 0) {
        await this.debugLog(`getResult: No messages found for session ${delegation.sessionID}`)
        return `Delegation "${delegation.description}" completed but produced no output.`
      }

      const isAssistantMessage = (m: SessionMessageItem): m is AssistantSessionMessageItem =>
        m.info.role === "assistant"

      const assistantMessages = messageData.filter(isAssistantMessage)

      if (assistantMessages.length === 0) {
        return `Delegation "${delegation.description}" completed but produced no assistant response.`
      }

      const lastMessage = assistantMessages[assistantMessages.length - 1]
      const isTextPart = (p: Part): p is TextPart => p.type === "text"
      const textParts = lastMessage.parts.filter(isTextPart)

      if (textParts.length === 0) {
        return `Delegation "${delegation.description}" completed but produced no text content.`
      }

      return textParts.map((p) => p.text).join("\n")
    } catch (error) {
      await this.debugLog(
        `getResult error: ${error instanceof Error ? error.message : "Unknown error"}`,
      )
      return `Delegation "${delegation.description}" completed but result could not be retrieved: ${
        error instanceof Error ? error.message : "Unknown error"
      }`
    }
  }

  private async persistOutput(delegation: Delegation, content: string): Promise<void> {
    try {
      const dir = await this.ensureDelegationsDir(delegation.parentSessionID)
      const filePath = path.join(dir, `${delegation.id}.md`)

      const title = delegation.title || delegation.id
      const description = delegation.description || "(No description generated)"

      const header = `# ${title}

${description}

**ID:** ${delegation.id}
**Agent:** ${delegation.agent}
**Status:** ${delegation.status}
**Started:** ${delegation.startedAt.toISOString()}
**Completed:** ${delegation.completedAt?.toISOString() || "N/A"}

---

`
      await fs.writeFile(filePath, header + content, "utf8")
      await this.debugLog(`Persisted output to ${filePath}`)
    } catch (error) {
      await this.debugLog(
        `Failed to persist output: ${error instanceof Error ? error.message : "Unknown error"}`,
      )
    }
  }

  private async notifyParent(delegation: Delegation): Promise<void> {
    try {
      const statusText = delegation.status === "complete" ? "complete" : delegation.status

      const pendingSet = this.pendingByParent.get(delegation.parentSessionID)
      if (pendingSet) {
        pendingSet.delete(delegation.id)
      }

      const allComplete = !pendingSet || pendingSet.size === 0

      if (allComplete && pendingSet) {
        this.pendingByParent.delete(delegation.parentSessionID)
      }

      // Modo ultra-estable: NO inyectar mensajes en la sesión padre.
      // Esto evita crashes de TUI observados al llegar task notifications.
      await this.debugLog(
        `Silent completion recorded for ${delegation.id} status=${statusText} (allComplete=${allComplete}, remaining=${pendingSet?.size || 0})`,
      )
      await this.log.info(
        `delegation ${delegation.id} completed status=${statusText} parent=${delegation.parentSessionID} allComplete=${allComplete}`,
      )

      await this.debugLog(
        `Updated parent delegation state ${delegation.parentSessionID} (allComplete=${allComplete}, remaining=${pendingSet?.size || 0})`,
      )
    } catch (error) {
      await this.debugLog(
        `Failed to notify parent: ${error instanceof Error ? error.message : "Unknown error"}`,
      )
    }
  }

  async readOutput(sessionID: string, id: string): Promise<string> {
    let filePath: string | undefined
    try {
      const dir = await this.getDelegationsDir(sessionID)
      filePath = path.join(dir, `${id}.md`)
      await fs.access(filePath)
      return await fs.readFile(filePath, "utf8")
    } catch {}

    const delegation = this.delegations.get(id)
    if (delegation) {
      if (delegation.status === "running") {
        await this.debugLog(`readOutput: waiting for delegation ${delegation.id} to complete`)
        await this.waitForCompletion(delegation.id)

        const dir = await this.getDelegationsDir(sessionID)
        filePath = path.join(dir, `${id}.md`)
        try {
          return await fs.readFile(filePath, "utf8")
        } catch {}

        const updated = this.delegations.get(id)
        if (updated && updated.status !== "running") {
          const title = updated.title || updated.id
          return `Delegation "${title}" ended with status: ${updated.status}. ${updated.error || ""}`
        }
      }
    }

    throw new Error(
      `Delegation "${id}" not found.\n\nUse delegation_list() to see available delegations.`,
    )
  }

  async listDelegations(sessionID: string): Promise<DelegationListItem[]> {
    const results: DelegationListItem[] = []

    for (const delegation of this.delegations.values()) {
      results.push({
        id: delegation.id,
        status: delegation.status,
        title: delegation.title || "(generating...)",
        description: delegation.description || "(generating...)",
      })
    }

    try {
      const dir = await this.getDelegationsDir(sessionID)
      const files = await fs.readdir(dir)

      for (const file of files) {
        if (file.endsWith(".md")) {
          const id = file.replace(".md", "")
          if (!results.find((r) => r.id === id)) {
            let title = "(loaded from storage)"
            let description = ""
            let agent: string | undefined
            try {
              const filePath = path.join(dir, file)
              const content = await fs.readFile(filePath, "utf8")
              const titleMatch = content.match(/^# (.+)$/m)
              if (titleMatch) title = titleMatch[1]
              const agentMatch = content.match(/^\*\*Agent:\*\* (.+)$/m)
              if (agentMatch) agent = agentMatch[1]
              const lines = content.split("\n")
              if (lines.length > 2 && lines[2]) {
                description = lines[2].slice(0, 150)
              }
            } catch {}
            results.push({
              id,
              status: "complete",
              title,
              description,
              agent,
            })
          }
        }
      }
    } catch {}

    return results
  }

  async deleteDelegation(sessionID: string, id: string): Promise<boolean> {
    let delegationId: string | undefined
    for (const [dId, d] of this.delegations) {
      if (d.id === id) {
        delegationId = dId
        break
      }
    }

    if (delegationId) {
      const delegation = this.delegations.get(delegationId)
      if (delegation?.status === "running") {
        try {
          await this.client.session.delete({
            path: { id: delegation.sessionID },
          })
        } catch {}
        delegation.status = "cancelled"
        delegation.completedAt = new Date()
      }
      this.delegations.delete(delegationId)
    }

    try {
      const dir = await this.getDelegationsDir(sessionID)
      const filePath = path.join(dir, `${id}.md`)
      await fs.unlink(filePath)
      return true
    } catch {
      return false
    }
  }

  findBySession(sessionID: string): Delegation | undefined {
    return Array.from(this.delegations.values()).find((d) => d.sessionID === sessionID)
  }

  handleMessageEvent(sessionID: string, messageText?: string): void {
    const delegation = this.findBySession(sessionID)
    if (!delegation || delegation.status !== "running") return

    delegation.progress.lastUpdate = new Date()
    if (messageText) {
      delegation.progress.lastMessage = messageText
      delegation.progress.lastMessageAt = new Date()
    }
  }

  getPendingCount(parentSessionID: string): number {
    const pendingSet = this.pendingByParent.get(parentSessionID)
    return pendingSet ? pendingSet.size : 0
  }

  getRunningDelegations(): Delegation[] {
    return Array.from(this.delegations.values()).filter((d) => d.status === "running")
  }

  async getRecentCompletedDelegations(
    sessionID: string,
    limit: number = 10,
  ): Promise<DelegationListItem[]> {
    const all = await this.listDelegations(sessionID)
    return all.filter((d) => d.status !== "running").slice(-limit)
  }

  async debugLog(msg: string): Promise<void> {
    const timestamp = new Date().toISOString()
    const line = `${timestamp}: ${msg}\n`
    const debugFile = path.join(this.baseDir, "background-agents-debug.log")

    try {
      await fs.appendFile(debugFile, line, "utf8")
    } catch {}
  }
}

// ==========================================
// TOOL CREATORS
// ==========================================

interface DelegateArgs {
  prompt: string
  agent: string
}

function createDelegate(manager: DelegationManager): ReturnType<typeof tool> {
  return tool({
    description: `Delegate a task to an agent. Returns immediately with a readable ID.

Use this for:
- Research tasks (will be auto-saved)
- Parallel work that can run in background
- Any task where you want persistent, retrievable output

No inline chat notification is injected (stability mode).
Use \`delegation_list()\` to inspect status and \`delegation_read(id)\` to retrieve full output.
Results are persisted to disk and survive compaction.`,
    args: {
      prompt: tool.schema
        .string()
        .describe("The full detailed prompt for the agent. Must be in English."),
      agent: tool.schema
        .string()
        .describe(
          "Agent to delegate to. Use any configured agent name (e.g. 'explore', 'general', 'frontend-developer', 'backend-architect', 'debugger', etc.).",
        ),
    },
    async execute(args: DelegateArgs, toolCtx: ToolContext): Promise<string> {
      if (!toolCtx?.sessionID) {
        return "delegate requires sessionID. This is a system error."
      }
      if (!toolCtx?.messageID) {
        return "delegate requires messageID. This is a system error."
      }

      try {
        const delegation = await manager.delegate({
          parentSessionID: toolCtx.sessionID,
          parentMessageID: toolCtx.messageID,
          parentAgent: toolCtx.agent,
          prompt: args.prompt,
          agent: args.agent,
        })

        const pendingSet = manager.getPendingCount(toolCtx.sessionID)
        const totalActive = pendingSet

        let response = `Delegation started: ${delegation.id}\nAgent: ${args.agent}`
        if (totalActive > 1) {
          response += `\n\n${totalActive} delegations now active.`
        }
        response += `\nNo auto-notification (stability mode). Use delegation_list() when needed, then delegation_read(id).`

        return response
      } catch (error) {
        return `Delegation failed:\n\n${error instanceof Error ? error.message : "Unknown error"}`
      }
    },
  })
}

function createDelegationRead(manager: DelegationManager): ReturnType<typeof tool> {
  return tool({
    description: `Read the output of a delegation by its ID.
Use this to retrieve results from delegated tasks if the inline notification was lost during compaction.`,
    args: {
      id: tool.schema.string().describe("The delegation ID (e.g., 'elegant-blue-tiger')"),
    },
    async execute(args: { id: string }, toolCtx: ToolContext): Promise<string> {
      if (!toolCtx?.sessionID) {
        return "delegation_read requires sessionID. This is a system error."
      }

      return await manager.readOutput(toolCtx.sessionID, args.id)
    },
  })
}

function createDelegationList(manager: DelegationManager): ReturnType<typeof tool> {
  return tool({
    description: `List all delegations for the current session.
Shows both running and completed delegations.`,
    args: {},
    async execute(_args: Record<string, never>, toolCtx: ToolContext): Promise<string> {
      if (!toolCtx?.sessionID) {
        return "delegation_list requires sessionID. This is a system error."
      }

      const delegations = await manager.listDelegations(toolCtx.sessionID)

      if (delegations.length === 0) {
        return "No delegations found for this session."
      }

      const lines = delegations.map((d) => {
        const titlePart = d.title ? ` | ${d.title}` : ""
        const descPart = d.description ? `\n  -> ${d.description}` : ""
        return `- **${d.id}**${titlePart} [${d.status}]${descPart}`
      })

      return `## Delegations\n\n${lines.join("\n")}`
    },
  })
}

// ==========================================
// REGLAS DE DELEGACIÓN (inyectadas en system prompt)
// ==========================================

const DELEGATION_RULES = `<task-notification>
<delegation-system>

## Async Background Delegation

You have tools for parallel background work:
- \`delegate(prompt, agent)\` - Launch background task, returns ID immediately
- \`delegation_read(id)\` - Retrieve completed result
- \`delegation_list()\` - List delegations (use sparingly)

## When to Use delegate vs task

| Tool | Behavior | Use When |
|------|----------|----------|
| \`delegate\` | Async, background, persisted to disk | You want to continue working while it runs |
| \`task\` | Synchronous, blocks until complete | You need the result before continuing |

Any agent can be used with \`delegate\`. Results survive context compaction.

## How It Works

1. Call \`delegate(prompt, agent)\` with a detailed prompt and agent name
2. Continue productive work while it runs in the background
3. Check status with \`delegation_list()\` when needed (avoid tight polling loops)
4. Use \`delegation_read(id)\` to retrieve the full result when completed

## Critical Constraints

**Avoid aggressive polling loops with \`delegation_list\`.**
Check status only when you actually need it.

**NEVER wait idle.** Always have productive work while delegations run.

**NOTE:** Background delegations run in isolated sessions. Changes made by write-capable
agents in background sessions are NOT tracked by OpenCode's undo/branching system.

</delegation-system>
</task-notification>`

// ==========================================
// CONTEXTO DE COMPACTION
// ==========================================

interface DelegationForContext {
  id: string
  agent?: string
  title?: string
  description?: string
  status: string
  startedAt?: Date
  prompt?: string
}

function formatDelegationContext(
  running: DelegationForContext[],
  completed: DelegationForContext[],
): string {
  const sections: string[] = ["<delegation-context>"]

  if (running.length > 0) {
    sections.push("## Running Delegations")
    sections.push("")
    for (const d of running) {
      sections.push(`### \`${d.id}\`${d.agent ? ` (${d.agent})` : ""}`)
      if (d.startedAt) {
        sections.push(`**Started:** ${d.startedAt.toISOString()}`)
      }
      if (d.prompt) {
        const truncatedPrompt = d.prompt.length > 200 ? `${d.prompt.slice(0, 200)}...` : d.prompt
        sections.push(`**Prompt:** ${truncatedPrompt}`)
      }
      sections.push("")
    }

    sections.push(
      "> **Note:** Auto task notifications are disabled in stability mode.",
    )
    sections.push("> Check `delegation_list` only when needed, then use `delegation_read(id)`.")
    sections.push("")
  }

  if (completed.length > 0) {
    sections.push("## Recent Completed Delegations")
    sections.push("")
    for (const d of completed) {
      sections.push(`- \`${d.id}\` [${d.status}]`)
    }
    sections.push("")
    sections.push("> Use `delegation_read(id)` to get full output for any completed delegation.")
    sections.push("")
  }

  sections.push("## Retrieval")
  sections.push('Use `delegation_read("id")` to access full delegation output.')
  sections.push("</delegation-context>")

  return sections.join("\n")
}

// ==========================================
// PLUGIN EXPORT
// ==========================================

interface SystemTransformInput {
  agent?: string
  sessionID?: string
}

export const BackgroundAgents: Plugin = async (ctx) => {
  const { client, directory } = ctx

  const log = createLogger(client as OpencodeClient)

  // Storage por proyecto (compartido entre sesiones)
  const projectId = await getProjectId(directory)
  const baseDir = path.join(os.homedir(), ".local", "share", "opencode", "delegations", projectId)

  await fs.mkdir(baseDir, { recursive: true })

  const manager = new DelegationManager(client as OpencodeClient, baseDir, log)

  await manager.debugLog("BackgroundAgents initialized")

  return {
    tool: {
      delegate: createDelegate(manager),
      delegation_read: createDelegationRead(manager),
      delegation_list: createDelegationList(manager),
    },

    // Inyectar reglas de delegación en system prompt
    "experimental.chat.system.transform": async (_input: SystemTransformInput, output) => {
      output.system.push(DELEGATION_RULES)
    },

    // Hook de compaction — inyectar contexto de delegaciones para recovery
    "experimental.session.compacting": async (
      input: { sessionID: string },
      output: { context: string[]; prompt?: string },
    ) => {
      const rootSessionID = await manager.getRootSessionID(input.sessionID)

      const running = manager
        .getRunningDelegations()
        .filter(
          (d) =>
            d.parentSessionID === input.sessionID || d.parentSessionID === rootSessionID,
        )
        .map((d) => ({
          id: d.id,
          agent: d.agent,
          title: d.title,
          description: d.description,
          status: d.status,
          startedAt: d.startedAt,
          prompt: d.prompt,
        }))

      const allDelegations = await manager.listDelegations(input.sessionID)
      const completed = allDelegations
        .filter((d) => d.status !== "running")
        .slice(-10)
        .map((d) => ({
          id: d.id,
          agent: d.agent,
          title: d.title,
          description: d.description,
          status: d.status,
        }))

      if (running.length === 0 && completed.length === 0) return

      output.context.push(formatDelegationContext(running, completed))
    },

    // Event hook para tracking
    event: async ({ event }: { event: Event }): Promise<void> => {
      if (event.type === "session.idle") {
        const sessionID = event.properties.sessionID
        const delegation = manager.findBySession(sessionID)
        if (delegation) {
          void manager
            .handleSessionIdle(sessionID)
            .catch((error) =>
              manager.debugLog(
                `handleSessionIdle async error: ${error instanceof Error ? error.message : "Unknown error"}`,
              ),
            )
        }
      }

      if (event.type === "message.updated") {
        const sessionID = event.properties.info.sessionID
        if (sessionID) {
          manager.handleMessageEvent(sessionID)
        }
      }
    },
  }
}

export default BackgroundAgents
