---
name: obsidian
description: Work with Obsidian vault notes and maintain project phase documentation with safe, repeatable conventions.
---

# Obsidian Project Documentation

## When to activate

Use this skill when the user asks to document project progress/phases in Obsidian.

## Vault resolution protocol (run in order)

1. `OBSIDIAN_VAULT_PATH` env var (absolute path)
2. `~/.config/opencode/obsidian.config.json` (`vaultPath`)
3. `npx -y obsidian-cli print-default --path-only`
4. `~/Library/Application Support/obsidian/obsidian.json`
5. If still ambiguous, ask the user for an absolute vault path and STOP.

### Local config file

Preferred persisted config:

- `~/.config/opencode/obsidian.config.json`

Format:

```json
{
  "vaultPath": "/absolute/path/to/vault",
  "defaultProject": "MiProyecto",
  "notesRoot": "Projects"
}
```

## Obsidian CLI notes

If Obsidian CLI is available, use it for reliable create/append/read operations.

Quick references:

- `npx -y obsidian-cli help`
- `npx -y obsidian-cli read file="My Note"`
- `npx -y obsidian-cli create name="My Note" content="# Title" silent`

If CLI is unavailable, write Markdown files directly in the vault.

## Phase note convention

### Path

- `Projects/<project-name>/Phases/`

### Filename

- `YYYY-MM-DD-<phase-slug>.md`

## Phase note template

```md
---
project: <Project Name>
phase: <Phase Name>
date: <YYYY-MM-DD>
status: in-progress
tags: [project, phase]
---

# <Project Name> — <Phase Name>

## Objective
-

## Scope
- In:
- Out:

## Decisions
-

## Implementation Summary
-

## Risks / Blockers
-

## Verification
- Commands run:
- Results:

## Next Steps
-
```

## Update strategy (idempotent)

1. If the same project + phase + date note exists, update that file.
2. Preserve existing sections and append new evidence/changes.
3. Do not duplicate headings.
4. Keep chronological entries inside each section when appending.

## Documentation quality gate

Before finishing, verify:

1. File path matches convention.
2. Objective and scope are explicit.
3. At least one verification evidence item exists.
4. Next step is actionable.
5. Output includes final file path + short changelog.

## Safety rules

- Never edit `.obsidian/` unless explicitly asked.
- Never move/delete existing notes unless explicitly asked.
- Keep notes concise, operational, and audit-friendly.
- If vault path is uncertain, ask and STOP.

## Final response contract

Always return:

1. Vault path used
2. Note file path written
3. Created vs updated
4. 3-6 bullet summary of documented changes
