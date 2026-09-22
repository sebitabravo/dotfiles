# macOS dotfiles port

## Objective and scope
Port the ten portable files differing from `/Users/sebitabravo/Downloads/dotfiles-main` into this repository, preserving exact source contents and modes. User authorized all functional changes including installer pins. Exclude generated Herdr hook, caches, .atl, odd, install logs and Git internals. Use a new branch; no commits, installs, sourcing shell configuration, or active home configuration changes.

## Rationale
Preserve the user's working macOS adaptations. Six installer hashes differ; copying hashes does not establish payload trust. Spicetify becomes optional through two `|| true` changes, which may mask failures and must be reported.

## Tasks
- [x] T1 (done): Create branch and port the ten files; confirm exact source parity and clean diff formatting.
- [x] T2 (done): Independent verification executed; two pre-existing failures found (below), user authorized fixing both.
- [x] T3 (done): Fixed `.github/test/smoke-claude-hook-engine.sh` — dropped the `config/claude/scripts` copy/mkdir, dead since commit `e298570` removed that directory and stopped requiring it from `install.sh`. `.github/validate.sh` now reports `ALL GREEN`.
- [x] T4 (done): Updated the Pi installer pin in `.github/install/remote-installers.sha256` from `a3a3604e...` to `6dd66554...` after downloading the payload to a file, hashing it, and eyeballing it for exfiltration/obfuscation (none found — standard Node bootstrap with SHASUMS256 verification and `--ignore-scripts`).

## Acceptance and verification
All ten files match the reference; unrelated files remain untouched except this progress document. Report all failed/skipped checks. Do not claim a working installation without running one.
TDD: no configuration discovered; exact-copy port checked via parity/syntax, no RED/GREEN claim. Writer checks passed: `bash -n install.sh`, `zsh -n .zshenv`, `zsh -n .zshrc`, `git diff --check`, Python JSON parsing and byte/mode parity for all ten files.
RDD: off, observed via `gentle-ai review mode status`.

## Evidence
Initial Git worktree clean on main. Exhaustive read-only Python comparison of content hashes, modes and symlink types found zero extra portable files and ten modified files.

## Independent verification
- Exact parity: 364 portable files in each tree, zero differences or extra files (agreed exclusions).
- Passed: shell syntax, `git diff --check`, JSON parsing (12 files), TOML parsing (2 files), `bash .github/test.sh`.
- Failed: `bash .github/validate.sh`; its smoke test copies missing `config/claude/scripts`. Same missing path and test reference exist in HEAD; pre-existing failure.
- All six changed installer pins match current HTTPS payloads. Six other unchanged pins also match.
- Unchanged Pi installer pin mismatches: expected `a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5b`, observed `6dd66554d87aaf3b655f862392bff173f5810ff37bfc38da04eeace0890781df`. No hash updated beyond reference.
- No installers executed, no active HOME changes, no commits. End-to-end installation not tested.
- Native assessment unavailable (missing package-local binary); independent verifier completed under fail-closed plan. RDD off.

## Tasks (continued)
- [x] T5 (done): Read-only audit comparing repo vs live machine (not the Downloads reference). Found real drift both directions.
- [x] T6 (done): Removed Kilo Code entirely (user confirmed no longer used) — install.sh, .github/test.sh, sha256 pins, MANUAL_INSTALL.md, .zshenv.
- [x] T7 (done): Verified via `gentle-ai sync --dry-run` which settings.json keys gentle-ai actually manages (persona/sdd/engram/context7/gga/skills by default; permissions/theme need --include-permissions/--include-theme). Wired those two flags into install.sh's resync call instead of hand-copying JSON.
- [x] T8 (done): Ported real, never-tracked config found only on the live machine: .gitconfig hardening, config/git/.gitignore_global, new config/ripgrep/.ripgreprc, .zshrc env block, .zshenv DOTNET_CLI_TELEMETRY_OPTOUT. Verified each against WebSearch that no installer auto-writes these (git-delta, .NET SDK don't self-configure shell/gitconfig).
- [x] T9 (done): Self-corrected two mistakes from T1's port: dead `.lmstudio/bin` path_promote (LM Studio self-injects PATH via .zshrc append) and a redundant guarded Unity CLI line (Unity's installer already self-appends unguarded, confirmed via websearch).

## Next step
All authorized work is complete on `fix/macos-dotfiles-port` (18 commits total). `bash .github/validate.sh` and `bash .github/test.sh` both green. Not tested: end-to-end real installation (no installer executed, no HOME changes). Remaining known asymmetry, not fixed (harmless): live `.zshenv` still has a dead `path_promote "$HOME/.cargo/bin"` line the repo no longer carries — machine-only cleanup, not a repo concern.
