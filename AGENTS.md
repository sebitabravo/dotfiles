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

## Conventions

- Conventional Commits required. No `Co-Authored-By` or AI attribution in commits.
- Never use `--no-verify`; fix the hook failure instead. Never push auto-save/WIP commits.
- Always work on a branch; no direct commits to `main`.
- `shellcheck -S warning` must pass for all shell scripts.
- No symlinks: deployment uses independent copies so installed config survives repo moves.
- Backups: existing targets are moved to `~/.dotfiles-backups/<timestamp>/` before overwrite.
- Remote installers: SHA256 fail-closed verification against `config/install/remote-installers.sha256`; abort on mismatch before execution.
- `install.sh --dry-run` must not touch filesystem or network; use for preflight.

## Prohibited

- Blind editing: read existing code before changing it.
- Drive-by refactors: touch only what the task requires.
- Unverified claims: evidence before claims — run tests/linters and observe output.
- Skipping TDD for bugs: write a failing test before touching application code.
- Guessing config syntax, CLI flags, or API signatures — verify first.

## Structure

```
config/               # managed configs (claude, ghostty, git, vscode, btop, fastfetch, herdr)
.github/test/*.test.sh  # test suites (install, hooks, convergence, quality-gate)
install.sh            # idempotent bootstrap + deploy (preflight, backups, rsync)
Brewfile              # CLI tools and casks
git-hooks/            # commit-msg, pre-push
```

## Style

- Comments in neutral Spanish unless the project standard specifies another language.
- Use straight ASCII quotes (`"`, `'`, `` ` ``); no smart quotes, em dashes, or ellipsis.
- Targeted edits (`Edit`) over full rewrites; keep diffs reviewable.

## Verification

- `bash .github/test.sh` / `bash .github/validate.sh` / `shellcheck -S warning <file>`
- `git diff --check` before commit; `git log origin/main..HEAD --oneline` before push.

## Notes for Reviewers (GGA)

- Validate shell safety, idempotency, backup correctness, and SHA256 gating for any `install.sh` change.
- Flag missing `--dry-run` handling, symlink introduction, or skipped `shellcheck`.
- This is a dotfiles repo: scope is local machine provisioning, not a web service.
