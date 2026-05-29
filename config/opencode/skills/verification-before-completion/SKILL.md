---
name: verification-before-completion
description: Use before claiming "done", "fixed", "passing", or before commit/PR. Requires fresh verification evidence.
---

# Verification Before Completion

## Core Rule

**Never claim success without fresh verification output.**

## Required Gate

Before any completion claim:

1. Identify which command proves the claim.
2. Run it now (fresh run, not historical output).
3. Check exit code + failures + warnings.
4. Report evidence.
5. Only then state completion.

## Claim → Required Evidence

- "Tests pass" → full test command output
- "Build is OK" → build output with exit 0
- "Bug fixed" → reproduction no longer fails + targeted test passes
- "Ready to PR" → lint/tests/build (as requested by project)

## Output Format

Use:

- **Claim**
- **Command run**
- **Result summary**
- **Evidence snippet**
- **Final status**: pass / fail / partial
