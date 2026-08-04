---
name: engram-memory
description: Use only when the Engram MCP server is installed and its memory tools are visible. Stores and retrieves concise durable decisions without saving secrets or hidden reasoning.
---

# Optional Engram memory

This skill is opt-in. First confirm that the current session exposes Engram MCP
tools such as `mem_context`, `mem_search`, `mem_save`, or
`mem_session_summary`. If they are unavailable, stop using this skill and use
the normal Codex context or the `handoff` skill instead.

## Search

- Search before a non-trivial architectural decision when prior project context may matter.
- Search by concrete topic, repository, decision, or failure; do not dump the whole memory store into context.
- Treat retrieved memory as historical context, not current fact. Verify against the repository.

## Save

Save only durable, verified information:

- architecture and API decisions;
- project conventions and tool choices;
- root causes and regression patterns;
- user preferences that are explicitly stated;
- non-obvious operational gotchas.

Never save credentials, private keys, raw secret-bearing prompts, personal data
that is not needed, speculative conclusions, or private chain-of-thought.

## Session close

When the session is genuinely ending, save a compact summary containing Goal,
Discoveries, Accomplished, Risks, Next steps, and Memories saved. Do not claim a
memory was saved unless the tool returned success.
