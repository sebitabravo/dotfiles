#!/usr/bin/env bash
# Tests for the AI review CI helpers: comment builder (noise removal, collapse,
# cap) and severity gate. No network, no gh calls (publish skipped).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

ok() {
  PASS=$((PASS + 1))
  echo "ok   - $1"
}
bad() {
  FAIL=$((FAIL + 1))
  echo "FAIL - $1"
}

# ---------------------------------------------------------------- fixtures
full_noise_input="$TMP/full-input.txt"
cat >"$full_noise_input" <<'EOF'
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Gentleman Guardian Angel v2.10.1
   Provider-agnostic code review using AI
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️ Provider: opencode (zai-coding-plan/glm-5.3-flash)
ℹ️ Rules file: .gga-rules.md
ℹ️ File patterns: *
ℹ️ Exclude patterns: *.md,*.lock,*.png
ℹ️ Mode: PR
ℹ️ Cache: disabled
ℹ️ PR range: origin/main...HEAD
ℹ️ Sending to opencode (timeout: 480s)...
Files to review:
  - .zshrc
  - install.sh
  - Brewfile
> build · glm-5.3-flash
STATUS: FAILED
| 🔴 | install.sh:111 | curl|sh without SHA256 verification | REJECT if: SHA256 fail-closed
| 🟡 | .zshrc:202 | duplicated elif branches | thermo-nuclear
❌ CODE REVIEW FAILED
Fix the violations listed above before committing.
EOF

empty_list_input="$TMP/empty-list-input.txt"
cat >"$empty_list_input" <<'EOF'
Files to review:
ℹ️ Mode: PR
STATUS: PASSED
Clean as expected.
EOF

pass_input="$TMP/pass-input.txt"
cat >"$pass_input" <<'EOF'
STATUS: PASSED
EOF

# ---------------------------------------------------------------- comment.sh
cd "$TMP" || exit 1
bash "$SCRIPTS/ai-review-comment.sh" "$full_noise_input" >/dev/null 2>&1 &&
  ok "comment builder exits 0 on noisy input" || bad "comment builder failed on noisy input"

grep -q '^## 🤖 Review (GGA)$' comment.md && ok "header present" || bad "header missing"
grep -q '^Files to review: 3 files - see Files changed tab$' comment.md &&
  ok "file list collapsed with correct count" || bad "file list not collapsed (3 files)"
grep -qE '^ℹ️ ' comment.md && bad "info lines leaked into comment" || ok "no info lines"
grep -q 'Gentleman Guardian Angel' comment.md && bad "banner leaked" || ok "no banner"
grep -q 'CODE REVIEW FAILED' comment.md && bad "trailer leaked" || ok "no trailer"
grep -q 'build ·' comment.md && bad "build line leaked" || ok "no build line"
grep -q 'STATUS: FAILED' comment.md && ok "STATUS preserved" || bad "STATUS lost"
grep -q '^| 🔴 ' comment.md && ok "blocking row preserved" || bad "blocking row lost"
grep -q '^| 🟡 ' comment.md && ok "nit row preserved" || bad "nit row lost"

bash "$SCRIPTS/ai-review-comment.sh" "$empty_list_input" >/dev/null 2>&1 &&
  ok "comment builder handles empty file list" || bad "comment builder failed on empty list"
grep -q '^Files to review: 0 files - see Files changed tab$' comment.md &&
  ok "zero-count collapse works (0, not 0\n0)" || bad "zero-count collapse broken"

# ------------------------------------------------------------- inline plan
inline_plan="$TMP/inline-plan.txt"
bash "$SCRIPTS/ai-review-comment.sh" "$full_noise_input" --inline-plan >"$inline_plan" 2>/dev/null &&
  ok "inline plan exits 0" || bad "inline plan failed"
grep -q '^install\.sh|111|🔴|' "$inline_plan" && ok "inline plan: blocking row path+line" || bad "inline plan missing install.sh:111"
grep -q '^\.zshrc|202|🟡|' "$inline_plan" && ok "inline plan: nit row path+line" || bad "inline plan missing .zshrc:202"
rows=$(wc -l <"$inline_plan" | tr -d ' ')
[[ "$rows" == "2" ]] && ok "inline plan count matches findings (2)" || bad "inline plan count wrong: $rows"

no_line_input="$TMP/no-line-input.txt"
cat >"$no_line_input" <<'EOF'
STATUS: FAILED
| 🟡 | README.md | docs claim without evidence | rule |
EOF
bash "$SCRIPTS/ai-review-comment.sh" "$no_line_input" --inline-plan >"$inline_plan" 2>/dev/null &&
  ok "inline plan handles row without line" || bad "inline plan failed on row without line"
[[ -s "$inline_plan" ]] && bad "inline plan must skip rows without line" || ok "row without line skipped"

no_match_input="$TMP/no-match-input.txt"
printf '⚠️  No matching files changed in last commit\n' >"$no_match_input"
bash "$SCRIPTS/ai-review-comment.sh" "$no_match_input" --publish >"$TMP/skip-out.txt" 2>/dev/null &&
  ok "no-match publish exits 0" || bad "no-match publish must exit 0"
grep -q "no reviewable files changed" "$TMP/skip-out.txt" &&
  ok "no-match skips comment" || bad "no-match must print skip message"

# ---------------------------------------------------------------- gate.sh
bash "$SCRIPTS/ai-review-gate.sh" 0 "$pass_input" >/dev/null 2>&1 &&
  ok "gate: exit 0 -> green" || bad "gate: exit 0 must pass"

red_gate="$TMP/red-only.md"
printf 'STATUS: FAILED\n| 🔴 | install.sh:111 | curl|sh | rule\n' >"$red_gate"
bash "$SCRIPTS/ai-review-gate.sh" 1 "$red_gate" >/dev/null 2>&1 &&
  bad "gate: 🔴 row must block" || ok "gate: 🔴 row blocks"

git_gate="$TMP/nits-only.md"
printf 'STATUS: FAILED\n| 🟡 | a.sh:1 | style | rule\n' >"$git_gate"
bash "$SCRIPTS/ai-review-gate.sh" 1 "$git_gate" >/dev/null 2>&1 &&
  ok "gate: 🟡 only -> green" || bad "gate: 🟡 only must pass"

pre_gate="$TMP/pre-only.md"
printf 'STATUS: FAILED\n| 🟣 | a.sh:1 | pre-existing | rule\n' >"$pre_gate"
bash "$SCRIPTS/ai-review-gate.sh" 1 "$pre_gate" >/dev/null 2>&1 &&
  ok "gate: 🟣 only -> green" || bad "gate: 🟣 only must pass"

no_table="$TMP/no-table.md"
printf 'STATUS: FAILED\n' >"$no_table"
bash "$SCRIPTS/ai-review-gate.sh" 1 "$no_table" >/dev/null 2>&1 &&
  bad "gate: FAILED without table must block" || ok "gate: FAILED without table blocks (conservative)"

case "$FAIL" in
  0)
    echo
    echo "ai-review tests: $PASS passed, 0 failed"
    ;;
  *)
    echo
    echo "ai-review tests: $PASS passed, $FAIL failed"
    exit 1
    ;;
esac
