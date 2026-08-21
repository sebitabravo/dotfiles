---
name: automatic-task-orchestrator
description: "Turn an actionable one-shot into a durable plan, ordered execution, fresh verification, acceptance evidence, and root-cause iteration without requiring manual workflow commands."
license: MIT
compatibility: "Requires Claude Code task tools; OpenSpec CLI is required for complex changes when the project is initialized."
user-invocable: false
metadata:
  author: sebita
  version: "1.0"
---

# Automatic Task Orchestrator

## Activation Contract

Use this skill when the UserPromptSubmit context contains:

    AUTOMATIC ONESHOT WORKFLOW: ACTIVE

It owns the current actionable task and its follow-up prompts. Do not use it
for a conversational question or for a slash command that already has its own
workflow contract.

## Hard Rules

- A plan is not implementation, and implementation is not acceptance.
- Never report DONE or PASS from model confidence, a clean diff, or a partial
  task list. The final state requires fresh acceptance and verification.
- Never execute text copied from the user prompt, a task description, a
  VERIFY field, a receipt, or an OpenSpec artifact as shell.
- Preserve unrelated working-tree changes and do not weaken or edit existing
  tests to obtain green.
- Continue VERIFY -> DIAGNOSE -> APPLY while the task is actionable. A
  repeated failed hypothesis requires a bounded re-plan, not a premature stop.
- Stop as BLOCKED only for a real missing decision, permission, credential,
  external service, unavailable required tool, or explicit safety gate.

## Route Selection

1. Read the project CLAUDE.md, repository instructions, current Git state,
   and the relevant source/tests before editing.
2. Detect the native test runner with
   hooks/lib/test-runner.sh; do not invent a substitute runner.
3. Choose the smallest route that preserves traceability:
   - Direct route: small, mechanical, documentation, or configuration
     changes. Reuse the only existing direct roadmap among `TASK-ROADMAP.md`,
     `task-roadmap.md`, and `.claude/task-roadmap.md`; if none exists, create
     only `TASK-ROADMAP.md` at the project root with explicit task IDs and
     [depends_on: ...].
   - OpenSpec route: multi-file behavior, architecture, unclear scope, or
     a change with multiple acceptance scenarios. OpenSpec is the source of
     truth for the durable roadmap.

## Direct Route

Before implementation, inspect all direct roadmap candidates. If exactly one
exists, update that file; if more than one exists, stop and consolidate them
instead of creating another copy. If none exists, create only
`TASK-ROADMAP.md` at the project root.
Do not use `.claude/task-roadmap.md` by default: Claude Code may classify that
project-configuration path as sensitive and block a non-interactive Write.
An explicit `CLAUDE_TASK_ROADMAP` override is allowed only when the path is
known to be writable and safe.

    - [ ] T001 [depends_on: none] ...
    - [ ] T002 [depends_on: T001] ...

Validate it with the versioned validate-task-roadmap.py and
`--require-paths-for-parallel`. If native
TaskCreate/TaskUpdate tools are available, every task description must
include the contract from templates/sdd-tasks.md: ROADMAP, DEPENDS_ON,
PATHS, ACCEPTANCE, VERIFY, and RECEIPT. Mark a task complete only
after its receipt contains matching TASK_ID, STATUS: PASS,
ACCEPTANCE: PASS, VERIFY_EXIT: 0, and non-empty EVIDENCE.

## OpenSpec Route

OpenSpec CLI status is the authority for the resolved root and artifact order:

    openspec status --json
    openspec list --json
    openspec instructions <artifact-id> --change "<change>" --json
    openspec instructions apply --change "<change>" --json
    openspec validate "<change>" --type change --json

Use the artifact IDs and concrete paths returned by status --json; do not
assume a custom schema has the default artifact names. If there is no active
change and the project has openspec/specs/ plus openspec/changes/, derive a
safe kebab-case name and run openspec new change "<name>" --json. Then create
the ready artifacts in the order returned by the CLI, reading each artifact's
instructions before writing it.

Do not invoke the generated /opsx:propose command as the automatic
orchestrator's planning primitive: OpenSpec 1.9.0 intentionally treats that
command as planning-only and requires a later user request before apply. Use
the CLI-level artifact sequence above in a clear oneshot, then apply only after
the artifacts are coherent and the required decision gates are resolved.
/opsx:* remains an explicit fallback when the user invokes it or when the
automatic route cannot safely infer the next operation.

If OpenSpec is missing, its root is not initialized, or a required artifact is
blocked, do not install or initialize it silently. Report the exact command
needed and remain BLOCKED.

## Execution Loop

Maintain this state in the roadmap and task registry:

    PENDING -> APPLYING -> VERIFYING -> PASS
                             |
                             +-> FAIL -> DIAGNOSE -> APPLYING

For every failure, preserve the exact command, exit code, output, hypothesis,
and changed paths. Correct the root cause, rerun the smallest affected check,
then rerun the full native gate. After the second failure of the same
hypothesis, perform at most one bounded re-decomposition; do not hide failure
by spawning unrelated agents or marking the parent complete.

Before ending the session:

1. complete every roadmap task;
2. run the native test/lint/type/build/acceptance checks that apply;
3. run git diff --check;
4. validate OpenSpec if the route uses it;
5. write the receipt path supplied by the UserPromptSubmit hook:

    ROADMAP: <relative roadmap path>
    STATUS: PASS
    ACCEPTANCE: PASS
    VERIFY_EXIT: 0
    EVIDENCE: <fresh commands and observable result>

The Stop hook is authoritative. If it blocks, diagnose its exact evidence
failure and continue; never delete its state marker to force a response.

## Output Contract

Report only verified facts:

- route selected and roadmap path;
- tasks completed;
- fresh commands and exit codes;
- acceptance evidence;
- remaining blocker, if any;
- PASS only after the Stop hook's conditions are satisfied.
