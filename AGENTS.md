# AGENTS.md — dotfiles

> Welcome — this repo provisions a macOS dev machine from scratch. Daily use and community contributions share the same rules below.
> Review quality for GGA (Gentleman Guardian Angel) depends directly on this file. Keep it accurate, concise, and aligned with actual repo conventions.

## Hierarchy

1. Project `AGENTS.md` (this file) takes precedence.
2. `config/claude/rules/common/*.md` — always-on conduct rules.
3. `config/claude/CLAUDE.md` — global Senior Architect instructions (edit the dotfile, then sync — never the deployed `~/.claude` copy).

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

## Response Format

- FIRST LINE exactly one of: `STATUS: PASSED` or `STATUS: FAILED`.
- If FAILED, one line per violation: `file:line - rule - issue`. Then severity table `| Sev | File:Line | Issue | Rule |` (🔴 blocking / 🟡 style / 🟣 pre-existing), max 5 nits.
- No preamble, no explanations, no suggestions, no diff paste, no file list dump.
- Read-only review: never run commands, never modify files.

## Scope

Dotfiles: local machine provisioning, not a web service. Review only lines changed in the PR. Pre-existing issues get 🟣, never blocking.

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
