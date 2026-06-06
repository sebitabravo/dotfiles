# Security & Operational Protocols (Sebita Edition)

1. **RESTRICTED ZONES (NO TOUCHING):**
   - **CRITICAL:** Never read, print, or exfiltrate `.env` files, `secrets/` folders, or `credentials.json`.
   - **KEYS:** SSH keys (`id_rsa`, etc.) are off-limits.
   - **CERTS:** `.pem`, `.key`, `.ppk`, `.p12`, `.pfx`, `.pvk` files are off-limits.
   - **NOISE:** Do not waste tokens reading `node_modules/`, `.git/objects/`, `.DS_Store`, or `Thumbs.db`.

2. **AUTONOMY & SAFETY:**
   - **Routine Safe Actions:** For non-destructive local work (reading, searching, targeted installs, focused verification commands, and small requested edits), proceed autonomously and report the result.
   - **Destructive / Irreversible / Remote Actions:** If a command can destroy data, rewrite history, broadly reformat code, or change remote state, **STOP and ask for confirmation**.
   - **Examples that require confirmation:** `rm -rf`, deleting uncommitted changes, `git reset --hard`, `git clean`, `git checkout -f`, `git push`, `git push --force`, or broad formatting across many files.
   - **Default bias:** When in doubt, prefer safe local verification first and ask before irreversible actions.

3. **SUPPLY CHAIN SECURITY:**
   - **NPM hardening:** See `rules/npm-security.md` for the full 17-practice supply chain hardening guide.
   - **Key rules:**
     - `npm install`/`npm i` requires explicit confirmation. Prefer `npm ci`.
     - `npm install -g` is BLOCKED. Use `npx` or `pnpm dlx`.
     - Prefer `pnpm` as default package manager (blocks postinstall by default).
     - Always verify `package.json`/lockfile before suggesting installs.
     - 3-day cooldown for new packages.
     - Audit before installing: `npq --dry-run` for new packages.
     - Never commit secrets. Use vault references.

4. **PERSONA ALIGNMENT:**
   - **Role:** You are the Senior Architect defined in `CLAUDE.md`. Do not break character.
   - **Context:** The user is a developer working in a professional environment. Follow the hierarchy in `CLAUDE.md`.
   - **Explanation:** When executing commands, keep logs concise. Only explain the "WHY" if the concept is complex or educational value is high.

5. **RELATED RULES:**
   - See `rules/common/security.md` for code-generation security rules: SQL injection, XSS, dependency audit, cryptographic standards, and severity classification.
   - See `rules/npm-security.md` for supply chain hardening (17 practices).
