#!/usr/bin/env bash
# Gate consumes only the trusted, schema-validated report. No model prose or
# engine exit code can grant a pass.
set -euo pipefail
report="${1:?usage: ai-review-gate.sh <validated-report.json>}"
python3 - "$report" "${UPSTREAM_STATUS:-success}" <<'PY'
import json,sys
path,status=sys.argv[1:]
if status != "success":
    print("review: infrastructure or publication failure", file=sys.stderr); raise SystemExit(1)
try:
    with open(path,encoding="utf-8") as f: r=json.load(f)
except Exception as e:
    print(f"review: invalid trusted report: {e}", file=sys.stderr); raise SystemExit(1)
if r.get("validation") != "trusted" or r.get("version") != "dotfiles.ai-review/v1" or r.get("trusted_conclusion") not in {"PASS","BLOCK","NOT_APPLICABLE"}:
    print("review: report is not a trusted validated report", file=sys.stderr); raise SystemExit(1)
findings = r.get("findings")
if not isinstance(findings, list) or len(findings) > 7:
    print("review: report findings are invalid", file=sys.stderr); raise SystemExit(1)
severe = any(isinstance(f, dict) and f.get("severity") in {"BLOCKER", "CRITICAL"} for f in findings)
if (r.get("trusted_conclusion") == "BLOCK") != severe or (r.get("trusted_conclusion") == "NOT_APPLICABLE" and findings):
    print("review: contradictory trusted conclusion", file=sys.stderr); raise SystemExit(1)
if r["trusted_conclusion"] == "BLOCK":
    print("review: FAILED (blocking findings)", file=sys.stderr); raise SystemExit(1)
print("review: PASSED" if r["trusted_conclusion"] == "PASS" else "review: NOT_APPLICABLE")
PY
