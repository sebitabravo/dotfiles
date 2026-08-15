---
name: quality-metrics
description: Code quality thresholds and measurement tools — coverage (line/branch/function), cyclomatic complexity, Halstead difficulty, maintainability index, plus the coverage and complexity tool for each language. Use when configuring coverage reporting, setting up a quality gate, interpreting a complexity report, or deciding whether code needs a refactor.
---

# Quality Metrics

## Coverage

- **Line coverage >= 80%**. Non-negotiable floor for production code.
- **Branch coverage >= 70%**. More important than line coverage: detects unexplored paths.
- **Function coverage >= 90%**. Every public function must have at least one test calling it.
- 100% coverage is NOT the goal. Coverage measures execution, not quality. See `mutation-testing.md`.
- Exclude from coverage: tests, mocks, fixtures, config, migrations, generated code, `index.ts` re-exports.

## Complexity

- **Cyclomatic complexity <= 10** per function. Above that, refactor (extract subfunctions, polymorphism > conditionals).
- **Lines per function <= 20**. Above that, the function likely does too much.
- **Lines per file <= 300**. Above 500, split into modules. **Hard limit: 1000 lines** (see `thermo-nuclear-code-quality-review` skill).
- **Params per function <= 4**. If you need more, group into an object/struct.
- **Indentation <= 4 levels**. If deeper, extract logic or use early returns.

## CRAP risk

Coverage alone says that a line executed; it does not say that the test would
fail when the behavior is wrong. Use CRAP to prioritize functions where
complexity and weak coverage combine into change risk:

```text
CRAP(fn) = CC^2 * (1 - coverage)^3 + CC
```

- `CC` is cyclomatic complexity.
- `coverage` is the function's covered fraction from the project's coverage
  report.
- 1-5 is low risk, 5-30 is moderate risk, and 30+ is high risk.
- Use the report to choose the next characterization test or refactor; do not
  blindly refactor every reported duplicate or high score.
- Run the project's native or explicitly approved analyzer. Examples include
  `crap4go`, `crap4java`, or `crap4clj`; use the project environment (`go run`,
  Maven, Clojure CLI, or a checked-in wrapper), never a silently installed
  global binary.

For changed high-risk code, the minimum evidence is: baseline tests, fresh
coverage, the CRAP report, and focused tests for the risky branches.

## Halstead and maintainability

- **Halstead difficulty <= 15** per function. Indicates how hard the code is to understand.
- **Maintainability Index >= 65** (0-100 scale). Below this, the code is hard to maintain.
- These metrics are reference points, not hard blocks. Use as signals to prioritize refactors.

## Tools by language

| Language | Coverage | Complexity | Lint |
|---|---|---|---|
| JS/TS | c8, nyc, istanbul | eslint-plugin-complexity, typhonjs | ESLint, Biome |
| Python | coverage.py, pytest-cov | radon, mccabe | ruff, pylint |
| Go | go test -cover | gocyclo, cyclo | golangci-lint |
| Rust | tarpaulin, grcov | clippy | clippy |
| Java | JaCoCo | PMD, Checkstyle | SpotBugs, SonarQube |
| Ruby | SimpleCov | flog, rubycritic | RuboCop |
| PHP | xdebug, pcov | php-metrics | PHPStan, Psalm |

## Rules

- **Coverage without assertions does not count**. A test that runs code without `expect`/`assert` inflates coverage without validating anything.
- **Do not write tests to inflate coverage**. Filler tests (calling functions without real assertions) are worse than no tests.
- **Coverage threshold is verified in CI**, not on every commit. The pre-commit hook (`quality-gate.sh`) checks it only if the project has it configured.
- **Metrics are signals, not laws**. If a function has complexity 12 but is clear and cannot be simplified, document the exception.
- **CRAP is a prioritization signal, not a universal merge threshold**. A
  project may choose a threshold; Claude must not invent one from this skill.
- **Technical debt is tracked**. If a metric is below threshold and not fixed now, create TODO with justification.

## Quality gates (see hooks/quality-gate.sh)

Before declaring `done` or before commit, the project must pass:

1. **Lint**: 0 errors. Warnings allowed but reviewed.
2. **Tests**: 0 failures. 0 skipped without justification.
3. **Coverage**: line >= 80%, branch >= 70%, function >= 90%.
4. **Complexity**: no function > 10 (or documented exception).
5. **Risk focus**: for complex or risky changed code, inspect CRAP and address
   the highest-risk functions before polishing low-risk code.

If the project does not have these tools configured, the hook skips (defensive mode). But the agent must report that verification was not performed.
