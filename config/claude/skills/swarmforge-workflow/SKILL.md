---
name: swarmforge-workflow
description: >-
  Claude-native implementation of unclebob/swarm-forge's two-pack, four-pack,
  and six-pack workflows. Use for non-trivial features when work must pass
  explicit specification, TDD, acceptance, cleanup, architecture, mutation,
  and independent QA handoffs.
version: 1.0.0
---

# SwarmForge workflow for Claude

This skill ports the **workflow semantics** of
[unclebob/swarm-forge](https://github.com/unclebob/swarm-forge) into Claude's
agent delegation model. It does not claim to be the standalone SwarmForge
launcher: tmux sessions, git worktrees, `.swarmforge/` state, Babashka, and
the `./swarm` wrapper require a project-local installation and explicit user
authorization.

## Choose the pack before editing

| Pack | Use when | Required sequence |
| --- | --- | --- |
| **two-pack** | Small technical/backend change with no user-facing behavior contract | Existing implementer -> `code-reviewer` -> implementer if corrections are needed |
| **four-pack** | Moderate behavior change needing a specification and architectural review | `product-manager` -> existing implementer -> `code-reviewer` -> `backend-architect` or domain reviewer |
| **six-pack** | Major, risky, externally visible, or cross-cutting change | `product-manager` -> existing implementer -> `code-reviewer` -> architecture reviewer -> `qa-engineer` hardening -> `qa-engineer` final QA |

Select the smallest pack that covers the risk. Do not use two-pack to avoid a
necessary acceptance or QA gate. Do not use six-pack merely to create parallel
activity. Explain the selection in the handoff ledger.

## Non-negotiable handoff contract

Every role must return a short evidence record containing:

```text
ROLE: <role>
INPUT: <approved scope or previous handoff>
CHANGED: <files, or "none">
COMMANDS: <exact relevant commands>
RESULT: <pass/fail/blocked>
EVIDENCE: <test output, report path, or explicit missing capability>
NEXT: <next role and remaining risk>
```

The coordinator must not start the next role when a required gate is blocked.
Missing runners, credentials, datasets, UI environments, or mutation tools are
reported as **blocked**, never replaced by invented evidence.

### Specification gate

For four-pack and six-pack, `product-manager` in specifier mode writes precise acceptance
criteria, Gherkin scenarios when the behavior is business-facing, and the
end-to-end/UI QA procedure when applicable. It must surface ambiguity and get
user approval before the implementer starts. A specification is not proof of
implementation.

### Coding gate

The existing domain implementer (for example `frontend-developer` for UI or
the main Claude session for backend work) implements the smallest approved
slice with failing unit tests first, then production code, then a green
project-native test run. For a real
acceptance pipeline, keep the chain explicit: Gherkin -> project IR/parser ->
generated entry point -> project runner -> acceptance mutation where supported.
Do not silently substitute a unit test for acceptance evidence.

### Quality gates

- `code-reviewer`, together with the implementer when an edit is justified,
  makes behavior-preserving cleaner/refactorer improvements,
  run coverage, inspect CRAP/complexity and DRY, and scan mutation sites.
- `backend-architect` for backend/API/data work, or `code-reviewer` plus the
  relevant domain agent for other stacks, checks boundaries, dependency direction, information
  hiding, and property-test opportunities.
- `qa-engineer` hardening mode runs source mutation and, when supported, soft acceptance
  mutation. Use a green baseline, differential/one-file-at-a-time scope, and
  the repository's native toolchain; never install global tooling.
- `qa-engineer` final-QA mode independently verifies acceptance/E2E/UI procedures, unit and
  integration evidence, architecture/release checks, and final CRAP/DRY
  status. It does not treat another agent's claim as verification.

Mutation testing, acceptance mutation, coverage, CRAP, and DRY are different
signals. Record each separately and run expensive audits deliberately, not as a
pretend hook result on every prompt.

## Runtime and repository boundaries

- Use Claude's configured agents and `Task` delegation for this port.
- Do not create branches, worktrees, commits, tmux sessions, or project-local
  `swarmforge/` files unless the user or repository workflow explicitly asks
  for them.
- Existing hooks are deterministic guardrails for safe operations and quality;
  they do not choose roles, launch agents, or prove acceptance/mutation.
- Never edit or weaken an existing test to make a gate pass. A new test for an
  approved behavior is allowed; report any authorization needed to change a
  requirement.
- Close the workflow only with fresh command output and a final ledger showing
  every required role and gate.
