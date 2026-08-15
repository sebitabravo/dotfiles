---
name: mutation-testing
description: Mutation testing to measure test quality. Configure Stryker for JavaScript/TypeScript, PIT for Java, Infection for PHP, and other project-local runners. Run mutants, interpret the score, and write tests that kill surviving mutants. Use when tests pass but there is low confidence they detect real bugs, or on critical features where test quality is vital.
---

# Mutation Testing

## When to use this skill

Activate when:
- Tests pass but there is **low confidence** they detect real bugs
- It's a **critical feature** where a bug has high cost (payments, auth, data)
- **Coverage is high but tests are superficial** (100% coverage, 0 real assertions)
- You need to **measure test quality**, not just quantity

Do NOT use when:
- It's trivial code, config, or prototype
- The project has no tests yet (write tests first, then mutate)
- You're in a fast dev loop (mutation is expensive, runs in CI)

Mutation testing is a quality measurement, not a replacement for a green
baseline suite. Run the baseline first and fail closed if it is red.

## What it does

1. The framework **mutates production code**:
   - Changes `>` to `>=`, `==` to `!=`, `+` to `-`
   - Negates conditions (`if (x)` -> `if (!x)`)
   - Deletes statements (`return x;` -> `return null;`)
   - Modifies literals (`0` -> `1`, `true` -> `false`)
2. **Runs tests** against each mutant
3. If tests **fail**: the mutant was **killed** (good test)
4. If tests **pass**: the mutant **survived** (insufficient test)
5. Reports **mutation score** = killed mutants / total mutants

## Thresholds

- **>= 80%**: good. Tests catch most mutants.
- **60-80%**: moderate. Test gaps exist.
- **< 60%**: poor. Tests are not validating the code.

## Frameworks by language

### JavaScript/TypeScript — Stryker

```bash
npm install -D @stryker-mutator/core
npx stryker init
```

`stryker.conf.json`:
```json
{
  "mutator": "typescript",
  "packageManager": "npm",
  "reporters": ["html", "clear-text", "progress"],
  "testRunner": "jest",
  "coverageAnalysis": "off",
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": 50
  }
}
```

Run:
```bash
npx stryker run
```

### Java — PIT (Pitest)

`pom.xml`:
```xml
<plugin>
  <groupId>org.pitest</groupId>
  <artifactId>pitest-maven</artifactId>
  <version>1.15.0</version>
  <configuration>
    <targetClasses>
      <param>com.example.*</param>
    </targetClasses>
    <targetTests>
      <param>com.example.*Test</param>
    </targetTests>
    <mutationThreshold>80</mutationThreshold>
  </configuration>
</plugin>
```

Run:
```bash
mvn org.pitest:pitest-maven:mutationCoverage
```

### PHP — Infection

```bash
composer require --dev infection/infection
vendor/bin/infection
```

### Go — go-mutesting

```bash
go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest
go-mutesting ./...
```

### Ruby — Mutant

```bash
gem install mutant
mutant --include lib --require lib/app.rb 'App*'
```

## Interpreting results

### Killed mutant
The test detected the change. Good.

### Survived mutant
The test did NOT detect the change. Write a test that fails when this mutant is active.

### Equivalent mutant
The change does not alter behavior (e.g., `i++` vs `++i` in a for loop). Flag and exclude from calculation.

### Timeout mutant
The change caused an infinite loop or extreme slowness. The test hung. Treat as a killed mutant (the test detected something).

## How to kill surviving mutants

1. **Identify the mutant**: what specific change survived?
2. **Understand what the test should catch**: if the mutant changed `>` to `>=`, the boundary is not covered.
3. **Write a test that fails with the mutant**:
   ```ts
   // Mutant: changed `if (age >= 18)` to `if (age > 18)`
   // Test that kills it:
   it('allows voting at 18', () => {
     expect(canVote(18)).toBe(true);  // fails if mutant changed >= to >
   });
   ```
4. **Re-run mutation testing** to confirm the mutant is killed.

## Differential workflow

Prefer the smallest useful surface:

1. Run the normal project suite and fresh coverage.
2. Scan the changed production file or changed function range when the tool
   supports differential mutation.
3. Mutate one source file at a time, with isolated workers only when the tool
   supports them safely.
4. Fix uncovered sites and surviving mutants before moving to the next file.
5. Run a full-file or full-module mutation pass before a major release when the
   risk justifies the cost.

Some Uncle Bob tools persist a source manifest to make later runs differential.
Treat that generated manifest as a project-owned artifact and verify whether
the project's workflow permits it before updating it. Do not edit tests to kill
mutants; improve the production behavior or add an authorized test.

## Tool and dependency policy

Use a checked-in project command, local wrapper, or project package manager.
Do not run `go install ...@latest`, `gem install`, or a global package install
as an automatic setup step. If a language-specific tool is absent, report the
missing dependency and continue with the strongest available tests; do not call
the mutation gate green.

Acceptance mutation is separate: it mutates Gherkin example values in an
acceptance IR and checks that the acceptance test fails. Use
`acceptance-pipeline` for that workflow.

## Anti-patterns

1. **Tests that only check execution**: `expect(result).toBeDefined()` does not kill mutants. Specific assertions.
2. **Excessive mocking**: if you mock everything, mutants in real dependencies are never detected.
3. **Running on every commit**: kills dev cycle time. CI tool.
4. **Chasing 100%**: equivalent mutants and trivial code generate noise. 80-90% is realistic.
5. **Ignoring surviving mutants**: each one is technical debt. If not killed now, document it.

## CI Integration

```yaml
# GitHub Actions example
- name: Mutation testing
  run: npx stryker run
  continue-on-error: true  # do not block PR, just report
```

For critical features, use `continue-on-error: false` and set `thresholds.break` to block merge.

The conduct rule that decides *when* mutation testing applies lives in `rules/common/testing.md`; this skill is the full how-to.
