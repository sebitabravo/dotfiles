# {{PROJECT_NAME}}

<!--
HOW TO USE THIS TEMPLATE
  1. Copy it to the project root as AGENTS.md (or configure another project instruction filename as a Codex fallback)
  2. Fill in only what the agent CANNOT deduce by reading the code
  3. Delete sections that don't apply — a half-filled template is worse than a short one
  4. Target: under 150 lines. It loads in EVERY session; every line is paid for every time

GOLDEN RULE — the derivability test:
  Before writing a line, ask: "would an agent reading the code figure this out on its own?"
    YES -> don't write it (stack, folder structure, package.json scripts, API signatures)
    NO  -> write it (why it exists, which business rules are inviolable, what breaks in production)

  The code says WHAT the system does. This file says WHY, and what happens if you break it.
-->

## What this is

<!-- 2-4 lines. The business, not the technology. Someone outside the project must understand what problem it solves. -->

{{One or two sentences: what real problem it solves and for whom.}}

**Target user**: {{who uses it, in what context, with what technical level}}

**How it makes money / the metric that matters**: {{revenue, retention, time saved, regulatory compliance... whatever defines success}}

## Domain rules (inviolable)

<!--
The BUSINESS rules the code must always respect, and that are not obvious from reading it.
Breaking one has a real consequence: money lost, a fine, corrupted data, a harmed user.
Number them. Be specific. No "handle errors properly".

Examples of the right format:
  1. An order is NEVER dispatched without confirmed payment. The `paid` state is the only one that enables `dispatch()`.
  2. Prices are stored in cents (integer). Never float — a 0.01 rounding across 10k transactions is a real accounting gap.
  3. A user cannot see another tenant's data. Every query carries `WHERE tenant_id = ?`. No exceptions.
  4. Issued invoices are never edited or deleted. A correction is a credit note. It is a tax authority requirement.
-->

1. {{rule}}
2. {{rule}}
3. {{rule}}

## What NOT to build (anti-goals)

<!--
Decisions already made about what stays OUT. Prevents the agent from "helping" by adding things you don't want.
Include the why: without the reason, the agent reads it as a pending item instead of a decision.

Examples:
  - NO multi-language. Single market, adding i18n now is complexity with no return.
  - NO in-house admin panel. Retool is used instead; decided so we don't maintain an internal CRUD.
  - NO microservices. Modular monolith up to 50k users — measured, and it holds.
-->

- NO {{thing}} — {{why}}
- NO {{thing}} — {{why}}

## Domain glossary

<!--
Business terms that appear in the code and mean something specific here.
Only the ones a new dev would misread. If the term is obvious, leave it out.

Examples:
  | Term | Means here |
  | "customer" | The company that signs the contract, NOT the end user. The end user is "beneficiary". |
  | "active" | Paid up AND with a session in the last 30 days. A paying but idle user is NOT "active". |
  | "cycle" | Billing period, not the order lifecycle. |
-->

| Term | Means here |
|---|---|
| {{term}} | {{precise definition}} |

## Gotchas

<!--
Things that look like a bug but are intentional, and traps that already cost time.
Each one stops the agent from "fixing" something that works, or repeating a known mistake.

Examples:
  - `sync_legacy()` runs sequentially on purpose. The provider returns 429 under concurrency. Do not parallelize it.
  - Tests in `billing/` need `TZ=America/Santiago`. Under another timezone they fail on the midnight boundary.
  - The `status` field has a `pending_v1` value that looks dead — 300 historical records use it. Do not remove it.
-->

- {{gotcha}}
- {{gotcha}}

## Non-obvious commands

<!--
Only the ones the agent CANNOT get from package.json / Makefile / pyproject.toml.
If it's `npm test`, don't write it. If it needs an odd flag, an env var, or a specific order, do.

Examples:
  | For | Command |
  | Run integration tests | `docker compose up -d db && TZ=America/Santiago npm run test:int` |
  | Regenerate schema types | `npm run db:types` (after EVERY migration, or the CI build fails) |
  | Seed realistic data | `npm run seed -- --profile=demo` |
-->

| For | Command |
|---|---|
| {{task}} | `{{command}}` |

## Environment setup

<!-- Only what is not in the README, or what the README gets wrong. Required variables, external services, credentials. Delete this section if the README already covers it. -->

{{non-obvious requirements}}

---

<!--
WHAT NOT TO PUT HERE (the agent already knows it or derives it):
  - The stack (package.json / go.mod / pyproject.toml says it)
  - The folder structure (it sees it with ls)
  - How React/Django/Laravel works (it knows)
  - "write clean code", "handle errors", "add tests" (that's in the global rules)
  - API documentation copied from the code (it goes stale and lies)
  - Rules the linter already enforces (redundant — the linter wins anyway)

If the agent repeatedly gets something wrong and the rule is ALREADY written here, the file is too long
and the rule is lost in the noise. Trim before adding.
-->
