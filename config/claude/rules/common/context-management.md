# Context Management

## Why this matters

OpenAI documented that retaining the model's reasoning chain between turns tripled ARC-AGI-3 scores, while discarding it (even when action history was preserved) forced the model to "figure out the game anew" every turn. Compaction that preserves reasoning cut output tokens by 6x. The principle: **a summary that keeps only actions is rolling truncation in disguise.**

## The three mechanisms you actually have

There is no `compress` tool in Claude Code. Reasoning continuity comes from exactly these:

| Mechanism | When it fires | What it preserves |
|---|---|---|
| **Auto-compact** | Automatically as the window fills (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` = 50%) | Whatever the harness decides — you do not control it directly |
| **`mem_save` (Engram)** | Whenever YOU call it | Exactly what you write, across sessions and compactions |
| **`/handoff`** | Before `/clear` or at session end | A HANDOFF.md the next session's SessionStart hook injects |

Auto-compact is the one you do not control, so the other two are where the work happens. **Write the reasoning down before the window turns over, not after.**

## What a good save contains

Every `mem_save` and every handoff must preserve:

### 1. Reasoning chain (WHY, not just WHAT)
- **Decision**: what was chosen
- **Rationale**: why over the alternatives
- **Alternatives rejected**: and the reason for rejection

### 2. Discoveries & gotchas
- Non-obvious findings discovered during the work
- Edge cases, API quirks, config surprises
- Things that would save a future session from repeating a mistake

### 3. Pending state
- What was NOT resolved
- What remains for the next session or later in this one
- Open questions or [NEEDS CLARIFICATION] items

## Anti-pattern: action-only summary

```text
// BAD — glorified truncation. The model loses the reasoning.
"Fixed auth middleware bug. Added tests. All green."
```

```text
// GOOD — preserves the chain of thought.
"Auth middleware bug: token expiry used < instead of <= at L42.
 Rejected: timezone offset (tz data was correct), JWT lib bug (clean decode logs).
 Fix: changed operator + edge test at midnight boundary.
 Trade-off: one extra validation request on the edge case, prevents false rejections."
```

An action-only summary is equivalent to the ARC-AGI-3 harness discarding private reasoning between turns: the model can see what happened but not how it got there.

## When to save

- **Proactive**: save as soon as a section is genuinely closed — task completed, decision finalized, exploration exhausted. Do NOT wait for the context window to fill.
- **Before the threshold**: auto-compact triggers at 50%. Anything not written down by then survives only at the harness's discretion.
- **Lean context beats bloated context**: fuller windows slightly degrade model performance (OpenAI, 2026). Scope investigations narrowly and delegate file-heavy exploration to subagents, which read in their own window and return one conclusion.

## After a compaction

1. Re-read the files you were mid-edit on. Do not trust your summary of their contents over the file.
2. `mem_context` → `mem_search` for the reasoning behind decisions already made, instead of re-deriving them.
3. Do NOT re-litigate a decision the user already approved.

## Verification

Before ending a session, self-check the summary you are about to save:
- Can a future session understand WHY each decision was made?
- Are the rejected alternatives documented?
- Is pending work clearly marked?
