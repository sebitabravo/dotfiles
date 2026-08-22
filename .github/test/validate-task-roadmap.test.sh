#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
VALIDATOR="$ROOT/config/claude/scripts/validate-task-roadmap.py"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/task-roadmap-test.XXXXXX")
trap 'find "$TMP" -type f -delete; rmdir "$TMP" 2>/dev/null || true' EXIT

cat >"$TMP/valid.md" <<'EOF'
# Valid DAG

- [ ] requirements.md is a prerequisite note, not a task
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] [paths: src/contract.py; tests/contract.py] Implement contract
- [>] T003 [depends_on: T001] [paths: src/evaluation.py] Prepare evaluation
- [ ] T004 [depends_on: T002,T003] Verify result
EOF

cat >"$TMP/missing.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T404] Broken dependency
EOF

cat >"$TMP/cycle.md" <<'EOF'
- [ ] T001 [depends_on: T003] First task
- [ ] T002 [depends_on: T001] Second task
- [ ] T003 [depends_on: T002] Third task
EOF

cat >"$TMP/duplicate.md" <<'EOF'
- [ ] T001 [depends_on: none] First task
- [ ] T001 [depends_on: none] Duplicate task
EOF

printf '%s\n' '== valid DAG'
python3 "$VALIDATOR" --strict --json "$TMP/valid.md" \
  | jq -e '.valid and .task_count == 4 and .graph.available and .graph.critical_path_length == 3 and .graph.max_parallel_frontier == 2 and .graph.independence.status == "verified" and (.graph.runnable_now | index("T001")) != null' \
  >/dev/null

printf '%s\n' '== parallel ownership required'
python3 "$VALIDATOR" --strict --require-paths-for-parallel "$TMP/valid.md" >/dev/null

cat >"$TMP/unannotated.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] First independent-looking task
- [ ] T003 [depends_on: T001] Second independent-looking task
EOF
if python3 "$VALIDATOR" --strict --require-paths-for-parallel "$TMP/unannotated.md" >/dev/null 2>&1; then
  printf 'unannotated parallel frontier was accepted\n' >&2
  exit 1
fi

cat >"$TMP/conflict.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] [paths: src/shared.py] First task
- [ ] T003 [depends_on: T001] [paths: src/shared.py] Second task
EOF
if python3 "$VALIDATOR" --strict --require-paths-for-parallel "$TMP/conflict.md" >/dev/null 2>&1; then
  printf 'overlapping parallel paths were accepted\n' >&2
  exit 1
fi

cat >"$TMP/none-ownership.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] [paths: none] First task
- [ ] T003 [depends_on: T001] [paths: none] Second task
EOF
if python3 "$VALIDATOR" --strict --require-paths-for-parallel "$TMP/none-ownership.md" >/dev/null 2>&1; then
  printf 'paths: none was accepted as parallel ownership\n' >&2
  exit 1
fi

cat >"$TMP/glob-ownership.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] [paths: src/*.py] First task
- [ ] T003 [depends_on: T001] [paths: tests/*.py] Second task
EOF
if python3 "$VALIDATOR" --strict --require-paths-for-parallel "$TMP/glob-ownership.md" >/dev/null 2>&1; then
  printf 'unresolved glob ownership was accepted\n' >&2
  exit 1
fi
python3 "$VALIDATOR" --strict --json "$TMP/glob-ownership.md" \
  | jq -e '.graph.independence.status == "unproven" and (.graph.independence.ambiguous_parallel_tasks | sort) == ["T002", "T003"]' \
  >/dev/null

cat >"$TMP/unsafe-path.md" <<'EOF'
- [ ] T001 [depends_on: none] Establish baseline
- [ ] T002 [depends_on: T001] [paths: ../outside.py] Unsafe ownership
EOF
if python3 "$VALIDATOR" --strict "$TMP/unsafe-path.md" >/dev/null 2>&1; then
  printf 'unsafe ownership path was accepted\n' >&2
  exit 1
fi

printf '%s\n' '== missing dependency'
if python3 "$VALIDATOR" "$TMP/missing.md" >/dev/null 2>&1; then
  printf 'missing dependency was accepted\n' >&2
  exit 1
fi

printf '%s\n' '== cycle'
if python3 "$VALIDATOR" "$TMP/cycle.md" >/dev/null 2>&1; then
  printf 'cycle was accepted\n' >&2
  exit 1
fi

printf '%s\n' '== duplicate id'
if python3 "$VALIDATOR" "$TMP/duplicate.md" >/dev/null 2>&1; then
  printf 'duplicate id was accepted\n' >&2
  exit 1
fi

printf '%s\n' 'PASS: task roadmap validator fixtures'
