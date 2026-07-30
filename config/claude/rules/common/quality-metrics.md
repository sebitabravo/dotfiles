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
- **Technical debt is tracked**. If a metric is below threshold and not fixed now, create TODO with justification.

## Quality gates (see hooks/quality-gate.sh)

Before declaring `done` or before commit, the project must pass:

1. **Lint**: 0 errors. Warnings allowed but reviewed.
2. **Tests**: 0 failures. 0 skipped without justification.
3. **Coverage**: line >= 80%, branch >= 70%, function >= 90%.
4. **Complexity**: no function > 10 (or documented exception).

If the project does not have these tools configured, the hook skips (defensive mode). But the agent must report that verification was not performed.