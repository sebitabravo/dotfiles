---
name: fuzzing-primer
description: >
  Bounded local fuzzing methodology for vulnerability discovery in owned source,
  parsers, binaries, and loopback services. Covers AFL++, libFuzzer, sanitizer
  builds, property-based tests, and safe ffuf use. Trigger: fuzzing, fuzz,
  AFL++, libFuzzer, parameter mutation, parser testing, crash triage.
---

# Fuzzing Primer

Use this skill only after a first-pass scope and static review. The objective is
to find reproducible robustness and security defects in code the user owns, not
to scan external systems or develop an exploit.

## Safety gate

- Target only a local file, local binary, local test harness, or an explicitly
  owned service bound to `localhost`/`127.0.0.1`.
- Do not use credentials, password lists, exploit payloads, persistence,
  destructive inputs, or external targets.
- Prefer a disposable copy, fixture, or worktree. Do not mutate the product
  source just to make a fuzzer run.
- Set a hard time or iteration budget and stop when it expires.
- Preserve the exact seed, command, sanitizer output, and exit status.

## Choose the smallest useful strategy

| Target | First choice | Evidence |
|---|---|---|
| Parser or file format | Sanitizers + libFuzzer/AFL++ | minimized crashing seed and stack trace |
| Pure function | Property-based test or deterministic mutation | failing input and assertion |
| CLI parser | Harness with bounded stdin/argv mutations | exit status, stderr, seed |
| Loopback HTTP service | ffuf with a tiny non-secret wordlist | local URL, request budget, response delta |
| Existing binary | `file`, `strings`, `nm`, `objdump`, then a harness | input boundary and crash report |

Do not start with maximum concurrency. One deterministic worker makes triage
and reproduction more valuable than a noisy high-volume run.

## Sanitizer-first native workflow

Compile a dedicated local harness with the project's existing compiler flags.
Do not replace the project's build system or change production flags.

```bash
clang -fsanitize=address,undefined,fuzzer -g \
  -o /tmp/vh-fuzz-harness path/to/harness.c

/tmp/vh-fuzz-harness \
  -seed=1 -runs=10000 -max_len=4096 /tmp/vh-corpus
```

If the project already uses AFL++, use its existing build recipe:

```bash
afl-fuzz -i /tmp/vh-corpus -o /tmp/vh-findings \
  -m none -V 60 -- /tmp/vh-fuzz-harness @@
```

A crash is not automatically an exploitable vulnerability. Classify the
sanitizer result, minimize the input, reproduce it twice, and report the
affected code path and realistic impact.

## Local HTTP fuzzing

Only fuzz a service the user explicitly owns and that is bound to loopback.
Use a tiny deterministic wordlist with no credential or exploit payloads:

```bash
ffuf -u http://127.0.0.1:8080/FUZZ \
  -w /tmp/vh-local-words.txt \
  -mc all -t 1 -rate 5 -maxtime 30 -of json -o /tmp/vh-ffuf.json
```

Never replace the loopback target with a domain copied from source, a public
IP, or a third-party URL. If the service is not clearly local, stop and emit a
VM handoff instead.

## Mutation and property testing

- Start from valid fixtures and mutate one field at a time.
- Keep seeds deterministic and record the random seed when the runner supports
  it.
- Exercise empty, truncated, oversized, duplicated, reordered, invalid-UTF-8,
  and boundary values appropriate to the format.
- Assert invariants such as no panic, bounded memory, bounded execution time,
  correct rejection, and no sensitive data in errors.
- Use the project's own test runner; do not install a global fuzzing framework.

## Crash triage

1. Save the smallest reproducing seed in a temporary or requested fixture path.
2. Rerun the exact command twice with the same result.
3. Capture sanitizer class, stack, signal, exit code, and affected function.
4. Check whether the failure is a test-harness defect or a product defect.
5. Report the minimum safe reproduction, not a weaponized payload or exploit
   chain.

## Stop conditions

Stop immediately when:

- the target resolves outside loopback;
- the command would require credentials or an external service;
- the run would modify production data or the user's real filesystem;
- the budget expires;
- the result is non-deterministic and cannot be isolated safely.

## Output

Return the fuzzer, target scope, budget, seed/corpus path, exact command, exit
status, crash or invariant evidence, reproduction count, and next action. A
zero-crash run means only that this bounded campaign found no crash; it is not a
security certificate.
