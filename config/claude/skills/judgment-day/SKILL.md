---
name: judgment-day
description: "Trigger: judgment day, dual review, adversarial review, juzgar. Run explicit blind dual review with at most two scoped fix/re-judgment rounds."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.7"
---

## Activation Contract

Load only when the user explicitly requests Judgment Day or equivalent dual/adversarial review for a concrete target. Judgment Day is a standalone developer tool: judges run whenever asked and need no review transaction or delivery machinery to start. It replaces the ordinary single-pass `code-reviewer` skill as the adversarial method for that target; never run both.

Judges and the fix actor are `general-purpose` subagents (no dedicated reviewer agents exist). Each prompt tells the subagent to load the `code-reviewer` skill (judges) or the `debugger` skill (fix actor) with the `Skill` tool before starting.

## Hard Rules

- Resolve matching project skills before starting and pass the same paths to both independent judge subagents and the bounded fix actor.
- Build one complete immutable target, then launch two independent judge subagents in parallel with identical scope and criteria. The caller must explicitly require read-only behavior and the JSON findings contract for both invocations.
- Each judge returns one neutral findings result and terminates. Wait for both; never accept a partial judgment.
- Never add a refuter; two-judge agreement is the corroboration mechanism.
- Only the parent orchestrator merges/persists findings, launches the bounded fix actor, and launches scoped re-judgment. The fix invocation must be labelled `JUDGMENT_DAY_FIX`. A third subagent loading `security-auditor` is optional for auth, secrets, and permissions; it does not replace either judge.
- Fix only severe findings confirmed by both judges. WARNING/SUGGESTION rows remain `info`.
- Permit at most two fix rounds and two scoped re-judgments. Re-judgment sees only the frozen ledger plus fix delta and may record fix-caused defects.
- The only terminal verdicts are `APPROVED | ESCALATED`; never reset or extend an exhausted round budget.
- A judgment carries no delivery authority: it satisfies no commit, push, PR, or release gate.

## Decision Gates

| Condition | Action |
|---|---|
| Target unclear | Ask one scope question and stop. |
| Both judges confirm severe finding | Ask before round-one correction; then use the bounded fix actor. |
| One judge reports it | Record suspect; do not auto-fix. |
| Judges contradict | Escalate for explicit human decision. |
| Scoped re-judgment fails before round two | Parent may launch the final bounded fix round. |
| Any issue remains after round two | Escalate and stop. |

## Execution Steps

1. Build the complete immutable target and freeze the scope both judges will inspect.
2. Launch two independent read-only `general-purpose` judge subagents in parallel, labelled Judge A and Judge B, against the same immutable target.
3. Merge findings into the frozen ledger and write it to a file so later rounds read the same ledger.
4. Ask before round-one correction; run the fix actor in `JUDGMENT_DAY_FIX` mode only for confirmed severe IDs.
5. Run both judges again only over the frozen ledger plus immutable fix delta.
6. Repeat once at most, then run independent final verification and return the terminal verdict.

## Output Contract

Return target identity, round, confirmed/suspect/contradiction/INFO counts, correction work units, scoped re-judgment result, ledger path, skill resolution, and exactly one final `JUDGMENT: APPROVED ✅` or `JUDGMENT: ESCALATED ⚠️`.

## References

- [references/prompts-and-formats.md](references/prompts-and-formats.md) - compact judge/fix prompts and verdict shape.
