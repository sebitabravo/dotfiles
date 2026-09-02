#!/usr/bin/env bash
# Create/finalize the head-bound terminal check. Requires GH_TOKEN and gh.
set -euo pipefail
op="${1:?usage: ai-review-check-run.sh create|finalize ...}"
repo="${REPOSITORY:?REPOSITORY required}"
pr="${PR_NUMBER:?PR_NUMBER required}"
base="${BASE_SHA:?BASE_SHA required}"
head="${HEAD_SHA:?HEAD_SHA required}"
identity() {
  local live
  live=$(gh api "repos/${repo}/pulls/${pr}")
  python3 - "$live" "$base" "$head" <<'PY'
import json,sys
d=json.loads(sys.argv[1]); base,head=sys.argv[2:]
if d.get("base",{}).get("sha") != base or d.get("head",{}).get("sha") != head:
    raise SystemExit("PR base/head identity mismatch")
PY
}
case "$op" in
  create)
    identity
    payload=$(
      python3 - "$head" "${RUN_ID:?RUN_ID required}" "${RUN_ATTEMPT:?RUN_ATTEMPT required}" <<'PY'
import json,sys
print(json.dumps({"name":"review-gate","head_sha":sys.argv[1],"status":"in_progress","external_id":sys.argv[2]+"-"+sys.argv[3]}))
PY
    )
    response=$(printf '%s' "$payload" | gh api "repos/${repo}/check-runs" --method POST --input -)
    python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d.get("id"),int); print(d["id"])' <<<"$response"
    ;;
  finalize)
    check_id="${CHECK_RUN_ID:?CHECK_RUN_ID required}"
    conclusion="${GATE_CONCLUSION:?GATE_CONCLUSION required}"
    [[ "$conclusion" == success || "$conclusion" == failure ]] || {
      echo "invalid gate conclusion" >&2
      exit 2
    }
    identity
    payload=$(
      python3 - "$conclusion" <<'PY'
import json,sys
print(json.dumps({"status":"completed","conclusion":sys.argv[1],"output":{"title":"Trusted AI review gate","summary":"Final immutable head check for the review workflow."}}))
PY
    )
    response=$(printf '%s' "$payload" | gh api "repos/${repo}/check-runs/${check_id}" --method PATCH --input -)
    python3 - "$response" "$conclusion" "$check_id" <<'PY'
import json,sys
d=json.loads(sys.argv[1])
if d.get("id") != int(sys.argv[3]) or d.get("status") != "completed" or d.get("conclusion") != sys.argv[2]:
    raise SystemExit("check run finalization mismatch")
PY
    ;;
  *)
    echo "unknown operation" >&2
    exit 2
    ;;
esac
