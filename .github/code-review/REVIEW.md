# Review Instructions

- Reserve 🔴 for shell safety, idempotency, SHA256 fail-closed, and backup correctness.
- Reserve 🟡 for style/nits (ASCII, quoting). Cap at 5 nits per review; collapse rest in <details>.
- Reserve 🟣 for pre-existing issues not introduced by this diff — do not block.
- Do not report: **/*.lock, **/*.md (docs only), config/claude/skills/**, .github/test/**, *.backup.*
- Keep output violations-only: table | Sev | File:Line | Issue | Rule |, no full file list, no diff paste. Summarize changed files as "N files — see Files changed".
- Max output 300 lines.
