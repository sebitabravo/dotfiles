#!/usr/bin/env bash
# Compara dos roadmaps validos como DAGs y reporta solo evidencia estructural.
#
# Esto no es un Planner/Executor: no ejecuta tareas, no infiere ownership de
# archivos y no autoriza paralelismo. Sirve para medir si un cambio reduce el
# camino critico o abre una frontera teorica mayor antes de una evaluacion real.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: compare-task-roadmaps.sh <baseline.md> <candidate.md>" >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
VALIDATOR=${CLAUDE_VALIDATOR:-$REPO_ROOT/config/claude/scripts/validate-task-roadmap.py}
BASELINE=$1
CANDIDATE=$2
TMP=$(mktemp -d "${TMPDIR:-/tmp}/task-roadmap-compare.XXXXXX")
trap 'find "$TMP" -type f -delete; rmdir "$TMP" 2>/dev/null || true' EXIT

if ! python3 "$VALIDATOR" --strict --json "$BASELINE" >"$TMP/baseline.json"; then
  cat "$TMP/baseline.json" >&2
  exit 1
fi
if ! python3 "$VALIDATOR" --strict --require-paths-for-parallel --json "$CANDIDATE" >"$TMP/candidate.json"; then
  cat "$TMP/candidate.json" >&2
  exit 1
fi

jq -e '(.valid == true) and (.graph.available == true)' \
  "$TMP/baseline.json" "$TMP/candidate.json" >/dev/null

jq -n \
  --slurpfile baseline "$TMP/baseline.json" \
  --slurpfile candidate "$TMP/candidate.json" '
  ($baseline[0]) as $b |
  ($candidate[0]) as $c |
  {
    schema: "task-roadmap-structural-v1",
    baseline: {
      roadmap: $b.roadmap,
      task_count: $b.task_count,
      graph: $b.graph
    },
    candidate: {
      roadmap: $c.roadmap,
      task_count: $c.task_count,
      graph: $c.graph
    },
    delta: {
      task_count: ($c.task_count - $b.task_count),
      critical_path_length: ($c.graph.critical_path_length - $b.graph.critical_path_length),
      max_parallel_frontier: ($c.graph.max_parallel_frontier - $b.graph.max_parallel_frontier),
      candidate_independence: $c.graph.independence.status
    },
    limitations: [
      "Structural comparison only; it does not prove correctness.",
      "The candidate must have explicit paths and no static overlap, but this does not prove repository ownership or runtime safety.",
      "Latency, tokens, retries, and unnecessary serialization require a real multi-run evaluation."
    ]
  }'
