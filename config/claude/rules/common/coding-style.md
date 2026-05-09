---
description: "Universal coding standards — applies to all languages"
globs: []
alwaysApply: true
---

# Coding Style

## Principles

- **Readability first**. Code is read 10x more than written.
- **Expressive names**. No cryptic abbreviations. `getUserById` not `gUBI`.
- **Short functions**. One responsibility, one abstraction level. If the name needs "and", split it.
- **Under 4 parameters**. More than that → use an object/DTO.
- **No obvious comments**. Code should explain itself. Comments only for WHY, not WHAT.

## Structure

- **DRY at module scale**, not project scale. 3 lines duplicated in 2 places = helper. 2 lines in 1 place = leave it.
- **Immutability by default**. `const` > `let`. Avoid parameter mutation.
- **Early returns** over nested if/else.
- **No magic numbers**. Named constants or enums.

## Format

- The language formatter rules. No debates.
- Max 120 chars per line (except URLs, long strings).
- One blank line between top-level functions. No blank lines inside short blocks.
