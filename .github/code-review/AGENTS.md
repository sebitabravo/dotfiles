# AGENTS.md — dotfiles

> Welcome — this repo provisions a macOS dev machine from scratch. Daily use and community contributions share the same rules below.
> Review quality for GGA (Gentleman Guardian Angel) depends directly on this file. Keep it accurate, concise, and aligned with actual repo conventions.

## Hierarchy

1. Project `AGENTS.md` (this file) takes precedence.
2. `config/claude/rules/common/*.md` — always-on conduct rules.
3. `config/claude/CLAUDE.md` — global Senior Architect instructions (edit the dotfile, then sync — never the deployed `~/.claude` copy).

## Response Language

RESPONSE LANGUAGE: All review output MUST be in neutral Spanish (español neutro) — table headers, Issue descriptions, Rule citations context, verification summaries. The ONLY English tokens allowed are the first-line STATUS: PASSED / STATUS: FAILED and severity emojis. The STATUS line is the ONLY English line allowed; everything AFTER the first line must be in neutral Spanish. Never answer in Chinese, English, or any other language. If uncertain, default to Spanish neutro.

CRITICAL: The FIRST LINE of the review MUST be EXACTLY `STATUS: PASSED` or `STATUS: FAILED` in ENGLISH, UPPERCASE, verbatim. NEVER translate STATUS to ESTAO/ESTADO. NEVER write `ESTADO:`. This line is machine-parsed (STRICT_MODE) and must stay English. Everything AFTER the first line must be in neutral Spanish.

REJECT if review output is not in neutral Spanish (except the STATUS line and emojis). STRICT_MODE enforces this.

## Stack

- Shell: `zsh` / `bash` (`set -euo pipefail`), macOS `defaults` via `config/macos/defaults.sh`.
- Packages: `Brewfile` (`brew bundle`), `install.sh` is idempotent and re-runnable (`--dry-run` for preflight).
- Configs: deployed as independent copies (no symlinks) to `~/.config`, `~/.claude`, `~/Library`.

## Review Rules

REJECT if (blocking — shell safety, SHA256, idempotency, backup correctness):
- REJECT if a change to `install.sh` or any remote installer bypasses SHA256 fail-closed verification against `config/install/remote-installers.sha256`.
- REJECT if a deployment change breaks idempotency/re-runnability or removes `--dry-run` support (must not touch filesystem/network in dry-run).
- REJECT if a change introduces symlinks for deployed configs (independent copies only) or skips backups to `~/.dotfiles-backups/<timestamp>/`.
- REJECT if a changed shell script fails `shellcheck -S warning` or drops `set -euo pipefail` where error-prone.
- REJECT if PR commits include AI attribution (`Co-Authored-By`), `--no-verify`, or auto-save/WIP commits.
- REJECT if the PR commits directly to `main` (branch required).

REQUIRE (FAILED if missing):
- REQUIRE Conventional Commits format on every commit.
- REQUIRE evidence before claims: lint/tests actually executed and output observed.
- REQUIRE `git diff --check` clean for staged changes.

PREFER (soft, non-blocking):
- PREFER targeted edits over rewrites; keep diffs reviewable.
- PREFER ASCII straight quotes (no smart quotes, em dashes, ellipsis).
- PREFER neutral Spanish comments unless the project standard says otherwise.

## Review Quality

REQUIRE: apply the thermo-nuclear code quality review skill appended below (after the `---` separator). Its rules are part of your binding instructions, not optional context. Its quality bar is the binding one for structural findings.

REQUIRE two passes in a single review:
- REQUIRE pass 1 (Find): list candidate issues from the diff.
- REQUIRE pass 2 (Verify): check every candidate against the ACTUAL file content, not the diff alone. Drop any that does not fail with the code as written. Only verified findings are reported.
- REQUIRE every finding cites `file:line` + the literal code snippet + why it fails NOW. No evidence, no finding.

REJECT fabrication:
- REJECT speculative findings: "could fail if..." is NOT a bug. The code must fail with current inputs and current state, not under a hypothetical 3-condition scenario. Mentally execute with 3 concrete values before reporting.
- REJECT taste as a finding: "I would write it differently" and "this name is too short" are not violations. "THIS name is misleading" or "THIS flow breaks with X" can be, with evidence.
- REJECT reviewing beyond the diff: the diff does not lie, only changed lines are yours to judge.

REQUIRE calibration:
- REQUIRE severity per line: 🔴 blocking (shell safety, SHA256 bypass, idempotency break, backup loss, secrets) / 🟡 style / 🟣 pre-existing (never blocking).
- REQUIRE confidence per finding: High (reproducible from the diff alone), Medium (depends on unseen context), Low (speculative — discarded unless verified). Never report findings with confidence below Medium.
- REQUIRE max 7 findings total. If everything is 🟡, lead with "Sin incidencias bloqueantes." (neutral Spanish). If this is a synchronize push, prioritize findings in the labeled diff section; do not re-report already-fixed files.

PREFER security flow analysis for installer paths (install.sh, remote installers, cleanup):
- PREFER tracing Source (curl | bash, remote URL, dynamic path) → Transformation (SHA256 verification, sanitization) → Sink (file write, backup move, `~/.dotfiles-backups/<timestamp>/`). Any security finding must cite source and sink.
- PREFER "Clean code = silence": no compliments, no strengths list. If no violations, say PASSED with one line. Silence is the judgment.

PREFER the tools as style judges:
- PREFER letting shellcheck, validate.sh, and `git diff --check` decide formatting/lint. Your taste is not a bug; report behavior, not preference.

## Response Format

- FIRST LINE exactly one of: `STATUS: PASSED` or `STATUS: FAILED` (English, for GGA parsing) — see Response Language above.
- STATUS: FAILED only when at least one 🔴 finding exists. If only 🟡/🟣, use STATUS: PASSED and lead with "Sin incidencias bloqueantes." (neutral Spanish).
- If FAILED, one line per violation: `file:line - rule - issue` (issue text in Spanish). Then severity table `| Sev | File:Line | Incidencia | Regla |` (🔴 bloqueo / 🟡 estilo / 🟣 preexistente), max 7 findings — headers and content in Spanish neutro.
- No preamble, no explanations, no suggestions, no diff paste, no file list dump — all in Spanish neutro.
- Read-only review: never run commands, never modify files.
- Example: first line `STATUS: PASSED`, second line "Sin incidencias bloqueantes." in Spanish neutro — e.g., table headers "Sev | Archivo:Línea | Incidencia | Regla".

## Scope

Dotfiles: local machine provisioning, not a web service. Scope is whatever the appended "Diff" or "Changed files" section lists; if a path is not listed, it is out of scope and pre-existing issues on it get 🟣, never blocking.

Review ONLY the changed lines shown in the diff (unified diff + name-status), cite file:line from '+' side. The appended section always contains both name-status and a unified diff (per-file truncated, cap 600k) — on synchronize it is the push delta, on opened it is the full PR diff. Report the `file:line` of every finding using the line number on the `+` side of that diff (new-file line numbers) — this is what lets the finding anchor as an inline PR comment. If this is a synchronize push, prioritize findings in the labeled diff section; do not re-report already-fixed files.

## Structure

```
config/               # managed configs (claude, ghostty, git, vscode, btop, fastfetch, herdr)
.github/test/*.test.sh  # test suites (install, hooks, convergence, quality-gate)
install.sh            # idempotent bootstrap + deploy (preflight, backups, rsync)
Brewfile              # CLI tools and casks
git-hooks/            # commit-msg, pre-push
```

## Verification

- `bash .github/test.sh` / `bash .github/validate.sh` / `shellcheck -S warning <file>`
- `git diff --check` before commit; `git log origin/main..HEAD --oneline` before push.
