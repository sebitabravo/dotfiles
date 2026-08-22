#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
COMPARATOR="$ROOT/config/claude/scripts/compare-task-roadmaps.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/task-roadmap-compare-test.XXXXXX")
trap 'find "$TMP" -type f -delete; rmdir "$TMP" 2>/dev/null || true' EXIT

cat >"$TMP/baseline.md" <<'EOF'
# Baseline: unnecessary serialization

- [ ] T001 [depends_on: none] Inspect input
- [ ] T002 [depends_on: T001] Prepare independent branch A
- [ ] T003 [depends_on: T002] Prepare independent branch B
- [ ] T004 [depends_on: T003] Verify result
EOF

cat >"$TMP/candidate.md" <<'EOF'
# Candidate: explicit independent frontier

- [ ] T001 [depends_on: none] Inspect input
- [ ] T002 [depends_on: T001] [paths: src/a.py] Prepare independent branch A
- [ ] T003 [depends_on: T001] [paths: src/b.py] Prepare independent branch B
- [ ] T004 [depends_on: T002,T003] Verify result
EOF

OUTPUT=$("$COMPARATOR" "$TMP/baseline.md" "$TMP/candidate.md")
printf '%s\n' "$OUTPUT" | jq -e '
  .schema == "task-roadmap-structural-v1" and
  .baseline.graph.critical_path_length == 4 and
  .candidate.graph.critical_path_length == 3 and
  .baseline.graph.max_parallel_frontier == 1 and
  .candidate.graph.max_parallel_frontier == 2 and
  .candidate.graph.independence.status == "verified" and
  .delta.critical_path_length == -1 and
  .delta.max_parallel_frontier == 1 and
  .delta.candidate_independence == "verified" and
  (.limitations | length) == 3
' >/dev/null

printf '%s\n' 'PASS: structural roadmap comparison fixture'
