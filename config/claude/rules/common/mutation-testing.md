# Mutation Testing

## What it is

Mutation testing measures test QUALITY: the framework mutates production code (changes `>` to `>=`, negates conditions, deletes statements) and checks whether tests detect the change. If a mutant survives, the tests are insufficient.

## When to run

- **In CI**, not on every commit. It is expensive (minutes).
- **On critical features** where test confidence is vital.
- **Do NOT run on**: scripts, config, trivial code, prototypes.

## Thresholds

- **Mutation score >= 80%**. Below this, tests fail to detect enough mutants.
- If score < 80%, write additional tests that kill the surviving mutants.
- "Equivalent" mutants (changes that do not alter behavior) are flagged and excluded from the calculation.

## Frameworks by language

| Language | Framework | Command |
|---|---|---|
| JavaScript/TypeScript | Stryker | `npx stryker run` |
| Python | mutmut | `mutmut run` |
| Python (alt) | cosmic-ray | `cosmic-ray init config.toml; cosmic-ray exec` |
| Go | go-mutesting | `go-mutesting ./...` |
| Java | PIT | `mvn org.pitest:pitest-maven:mutationCoverage` |
| Ruby | Mutant | `mutant --include lib --require lib/app.rb 'App*'` |
| PHP | Infection | `infection` |

## Configuration

- Stryker: `stryker.conf.json` with `mutator`, `thresholds.high: 80`, `thresholds.low: 60`.
- mutmut: config in `setup.cfg` or `mutmut_config.py`, paths to mutate.
- Exclude from mutation: tests, mocks, fixtures, config, migrations, generated code.

## Rules

- **Do not mutate tests**. Only production code.
- **Do not mutate generated code** (ORM models, protobuf, OpenAPI stubs).
- **Report surviving mutants** as technical debt. If not killed now, document in TODO.
- **Mutation score is not coverage**. 100% coverage with surviving mutants = tests that validate nothing.
- **Run before merge** on critical features. In regular CI, run on nightly or PRs in critical areas.

## Anti-patterns

- **Tests that only check execution**: `expect(result).toBeDefined()` does not kill mutants. Specific assertions.
- **Excessive mocking**: if you mock everything, mutants in real dependencies are never detected.
- **Running mutation on every commit**: kills dev cycle time. CI tool, not fast feedback.
- **Chasing 100% mutation score**: equivalent mutants and trivial code generate noise. 80-90% is realistic.