---
name: task-coordination-strategies
description: Use to decompose complex work into parallelizable tasks, define dependencies, and coordinate multi-agent execution.
---

# Task Coordination Strategies

## When to Use

- Multi-file features with parallel work opportunities
- SDD phases with multiple dependent tasks
- Agent orchestration where ordering matters

## Decomposition Rules

1. Split by independent outcomes first.
2. Keep tasks small and verifiable.
3. Assign clear ownership boundaries (files/modules).
4. Mark blockers explicitly.

## Dependency Strategy

- Prefer shallow graphs over long chains.
- Add dependency only when truly required.
- Identify critical path and optimize it first.

## Task Quality Checklist

Each task must include:

- **Objective**
- **Owned scope**
- **Acceptance criteria**
- **Out of scope**
- **Dependencies**

## Output Contract

Return:

1. **Milestones** (2-5)
2. **Ordered tasks** with acceptance criteria
3. **Dependency graph** (text form)
4. **Critical path**
5. **Quick win** (15-30 min task)
