---
name: acceptance-pipeline
description: Portable acceptance-test workflow for Gherkin features, generated entry points, project-native runners, acceptance mutation, and evidence-based QA. Use for complex business behavior, multi-step user journeys, or when a project has an acceptance-test pipeline.
---

# Acceptance Pipeline

Use this skill for behavior that must be readable by a stakeholder and
executable against the real project. It is not a reason to add Gherkin to
trivial utilities or to install a second test framework beside the project's
native runner.

## Boundary

- Unit and integration tests prove implementation contracts at the fastest
  useful boundary.
- Acceptance tests prove externally observable behavior and business rules.
- Conventional mutation testing mutates production source code.
- Acceptance mutation changes example values in the specification-derived test
  representation. It verifies that examples are connected to the application;
  it does not replace source mutation testing.

## Workflow

1. Read the project's test scripts, CI configuration, domain documentation, and
   existing feature files before writing a scenario.
2. Write small, stakeholder-readable `.feature` files in business language.
   Keep each scenario focused on one observable rule.
3. Validate the feature with the stakeholder when the requirement is
   ambiguous. Do not silently turn an assumption into an acceptance contract.
4. If the project already provides a parser or the portable Acceptance Pipeline
   Specification, parse the feature into its canonical JSON IR.
5. Run the project's report-only Gherkin DRY checker when available. Normalize
   accidental duplicate or synonymous steps, but do not merge steps merely
   because their text looks similar.
6. Generate or write the project-native acceptance entry point and step
   handlers. Step definitions translate; business logic stays in production
   code.
7. Run the normal acceptance command and record the exact command and result.
8. For critical behavior, run acceptance mutation after the normal suite is
   green. Improve scenarios until important example mutations are killed.

## Portable stage contract

When a project adopts the portable
[Acceptance Pipeline Specification](https://github.com/unclebob/Acceptance-Pipeline-Specification),
the stages are these. Reproduced so the signatures are never guessed — if what
the repository has does not match, the repository wins.

```text
normal:    feature -> parser -> JSON IR -> [IR-DRY checker] -> generator -> entry points -> project runner
mutation:  feature -> parser -> base JSON IR -> generator -> reusable entry points -> mutator -> runner adapter -> report
```

| Stage | Command | Who owns it |
| --- | --- | --- |
| Parse | `bb gherkin-parser <feature-file> <json-output>` | portable |
| DRY report | `bb gherkin-ir-dry-checker [--include-exact] <json-ir> <report-output>` | portable |
| Mutate | `bb gherkin-mutator [options]` | portable |
| Generate | `acceptance-entrypoint-generator <json-ir> <generated-test-output>` | project |
| Run | project runner adapter, runtime and step handlers | project |

The Babashka tasks have Go binary fallbacks under the same names without the
`bb` prefix. Conventional generated paths: `features/`, `build/acceptance/`,
`build/acceptance-mutation/`, `acceptance/generated/`. Generated output is a
build artifact — regenerate it, never hand-edit it.

The portable half is only the parser, the DRY checker and the mutator. The
generator, runtime, step handlers and runner adapter are project-specific by
design: that is why inventing them is out of scope rather than merely risky.

## Command policy

Prefer, in order:

1. A project-documented acceptance target (`make`, `just`, package script, or
   equivalent).
2. The project's checked-in wrapper or test runner.
3. A tool explicitly requested by the user and documented by the project.

Never invent a command, install a global tool, or replace the project's runner
with FitNesse/Cucumber/another framework without an explicit project decision.
If the parser, generator, runner adapter, or step handlers are missing, report
the exact blocked stage instead of claiming acceptance coverage.

## Scenario rules

- `Given` establishes state, `When` performs the action, and `Then` asserts an
  observable result.
- One step maps to one reusable translation function.
- No business logic, branching, sleeps, real credentials, or live third-party
  calls in step definitions.
- Prefer API/domain-level steps over CSS selectors; reserve UI steps for the
  user journeys that actually need browser verification.
- Keep a feature small. Split a feature that becomes a catalogue of unrelated
  scenarios.
- Generated tests are evidence, not a license to edit or weaken the source
  feature.

## Evidence contract

Every acceptance result must state:

- feature files and scenarios exercised;
- exact parser/generator/runner command, if those stages exist;
- normal acceptance result;
- acceptance-mutation result, or why it was not run;
- external gates not exercised (browser, production, credentials, hardware,
  or unavailable project dependencies).

## Uncle Bob workflow mapping

Use the smallest workflow that owns the needed quality gates; do not launch a
swarm by default:

- **Small technical change**: coder -> cleaner -> coder; unit tests and local
  cleanup.
- **Moderate business feature**: specifier -> coder -> refactorer -> architect
  -> specifier; accepted Gherkin, TDD, refactoring, CRAP/DRY and mutation
  review.
- **Major or high-risk feature**: specifier -> coder -> cleaner -> architect ->
  hardener -> QA; separate acceptance, architecture, mutation and final QA.

The first two flows close the loop on purpose. Cleanup returns to the coder and
architectural review returns to the specifier, because a behavior-preserving
refactor still has to be re-checked against the specification that was
approved. Only the six-pack terminates, and it terminates at QA.

This is a responsibility map for Claude's delegation and verification. It does
not require copying SwarmForge into every project.
