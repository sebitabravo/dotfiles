---
name: systematic-debugging
description: Use for bugs, test failures, unexpected behavior, and performance incidents. Enforces root-cause-first debugging before proposing fixes.
---

# Systematic Debugging

## Core Rule

**No fixes without root cause investigation first.**

If root cause is unknown, do not propose speculative patches.

## When to Use

- Test failures
- Runtime errors
- Integration regressions
- Performance degradations
- "It works on my machine" mismatches

## Process

1. **Reproduce**
   - Capture exact steps, environment, and frequency.
2. **Investigate**
   - Read errors fully, inspect recent changes, trace data flow backward.
3. **Hypothesize**
   - State one concrete hypothesis and why.
4. **Validate**
   - Make the smallest possible test change to confirm/refute.
5. **Fix at source**
   - Implement the smallest root-cause fix.
6. **Protect**
   - Add/adjust tests to prevent recurrence.

## Output Contract

Return results with these sections:

1. **Symptom** (what fails)
2. **Root cause** (why it fails)
3. **Evidence** (logs/tests/trace proving it)
4. **Fix** (source-level change)
5. **Regression protection** (tests/guards added)
