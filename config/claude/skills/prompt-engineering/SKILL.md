---
name: prompt-engineering
description: >
  Designing and optimizing prompts for LLMs — chain-of-thought, few-shot, XML structuring,
  model-tier calibration (Claude 5 vs 4.5 vs Haiku), self-critique loops and when they backfire,
  evaluation harnesses, and production prompt systems.
  Use when writing or debugging a prompt, building an LLM feature, designing an agent's system
  prompt, choosing a model tier, or setting up prompt evals.
---

# Prompt Engineering

## Match the technique to the model generation

The biggest mistake is applying advice written for an older generation.

| Generation | What works | What backfires |
|---|---|---|
| **Claude 5** (Opus 5, Sonnet 5, Fable 5) | State the goal and constraints, let the model exercise judgement. Progressive disclosure over upfront dumps. | Over-constraining. Anthropic removed >80% of Claude Code's system prompt for this generation with no eval loss — stacked rules start contradicting each other and cost tokens to reconcile. |
| **Claude 4.5** (Sonnet 4.5, Haiku 4.5) | Explicit, concrete instructions. Say what "good" looks like. Give the reason behind a rule. | Assuming inference. Less headroom means ambiguity gets resolved wrong more often. |
| **Haiku 4.5 specifically** | Short imperative instructions, concrete file paths and commands, acceptance criteria stated. Scoped, bounded tasks. | Open-ended planning prompts. Relying on it to surface caveats — it commits decisively and skips the tradeoff preamble unless told to. |

**Context awareness**: Sonnet 5 / 4.6 / 4.5 and Haiku 4.5 track their remaining token budget. In a harness that compacts context, say so in the prompt — otherwise the model wraps up work early thinking it is running out of room.

## Core techniques

**Be explicit about the output.** "Write a function" vs "write a function, then run the tests and show the output". If you want above-and-beyond behavior, ask for it — models do not infer ambition from vague prompts.

**Give the reason, not just the rule.** `NEVER use ellipses` → `Your response is read aloud by a TTS engine, so never use ellipses — it cannot pronounce them.` The model generalizes correctly from the reason and applies it to cases you did not enumerate.

**Few-shot with 3-5 examples.** Make them relevant (mirror the real case), diverse (cover edge cases so the model does not latch onto an accidental pattern), and structured (wrap in `<example>` tags so they read as data, not instructions).

**XML tags for multi-part prompts.** When a prompt mixes instructions, context, examples and input, tag each part (`<instructions>`, `<context>`, `<input>`). Removes ambiguity about what is a command versus background. Not needed for simple prompts.

**Chain-of-thought, three levels:**
1. Basic — "think step by step"
2. Guided — enumerate the reasoning steps you want
3. Structured — `<thinking>` and `<answer>` tags to separate reasoning from output

Use it for genuinely multi-step reasoning. On modern models with adaptive thinking, most multistep reasoning is handled internally — explicit CoT is for when you need to inspect or constrain the reasoning path.

**Role setting.** One sentence in the system prompt measurably shifts tone and focus. `You are a senior security engineer reviewing for injection flaws.`

## Self-critique: powerful and dangerous

A generate → criticize → improve loop is not free. Measured effect:

| Task difficulty | Effect of a critique loop |
|---|---|
| Easy (model already at ~98%) | **Degrades to ~57%.** The critic, primed to find errors, invents them. |
| Hard (model failing at 0%) | **Lifts to ~60%.** The critic catches real logic and calculation errors. |

**Rule: critique is for debugging, not polishing.** Apply it where the model is struggling. Skip it where output already passes its checks.

**Never let the writer grade its own work.** The same model that rationalized a shortcut while writing will rationalize it again while reviewing. Use a fresh context at minimum; a different model family is better, since same-family reviewers share correlated blind spots.

## Structuring an agent's system prompt

- **Tool descriptions carry the instructions.** Do not describe a tool's usage in the system prompt AND in its description — the duplication creates conflict. Put it in the tool.
- **Design expressive parameters** instead of writing examples of correct calls. A well-named, well-typed parameter teaches usage better than a paragraph.
- **Progressive disclosure.** Always-loaded context is paid on every turn. Move task-specific guidance into skills/tools that load on demand.
- **Safety-critical prohibitions stay always-loaded.** Never move a "never do X" rule into something that might not be loaded when it matters.

## Evaluation

A prompt without an eval is a guess.

1. **Build the test set first** — 20-50 cases covering the happy path, edge cases, and known failure modes.
2. **Define the metric before optimizing.** Exact match, rubric score, pass/fail on assertions. "Looks better" is not a metric.
3. **Change one thing at a time.** Prompt changes interact; batched edits make regressions untraceable.
4. **Watch for overfitting.** A prompt tuned until it aces 20 cases often generalizes worse than the simpler version.
5. **Use an LLM judge with a rubric**, not "rate this 1-10". Judges without explicit criteria drift.

## Production concerns

- **Version prompts like code.** Same review, same rollback path.
- **Prompt caching**: put the stable prefix (system prompt, tool definitions, few-shot examples) first and the variable part last, so the cache hits.
- **Model tiering**: route by task difficulty. A cheap fast model handles bounded, well-specified work; escalate only what needs it. This is the highest-leverage cost decision in most LLM features.
- **Failure modes to handle explicitly**: refusals, truncated output, malformed structured output, and tool-call loops.
- **Injection**: content fetched from the web, a database, or a file is untrusted input. Never let retrieved text be interpreted as instructions.

## Output format when delivering a prompt

Deliver the complete prompt text first — it is the artifact. Then:

- **Implementation notes**: techniques used and why, parameter recommendations (temperature, max tokens)
- **Testing**: suggested cases, expected behavior, known failure modes
- **Usage**: when this prompt applies and when it does not

## Anti-patterns

- **Stacking rules until behavior changes.** If the model ignores a rule, the prompt is probably too long and the rule got lost. Cut, do not add.
- **Politeness as technique.** "Please" and "I'll tip you $200" are not reliable levers.
- **Restating what the model already knows.** "Write clean code", "handle errors properly" — these consume tokens and change nothing.
- **Testing on one example.** A prompt that works once may be luck; sample variance across runs is real.
- **Copying prompt tricks across generations** without checking whether they still apply. See the table at the top.
