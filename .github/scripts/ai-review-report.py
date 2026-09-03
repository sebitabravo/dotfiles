#!/usr/bin/env python3
"""Validate the sole trusted JSON result emitted by OpenCode."""
from __future__ import annotations
import argparse, json, re, sys

MAX_FINDINGS = 7
MAX_TEXT = 600
SEVERITIES = {"BLOCKER", "CRITICAL", "WARNING", "SUGGESTION"}
CONFIDENCE = {"HIGH", "MEDIUM"}
RULES = {"SECURITY", "CORRECTNESS", "RELIABILITY", "SHELL_SAFETY", "SECRETS", "DEPENDENCY", "TESTING", "POLICY", "DOCUMENTATION", "MAINTAINABILITY", "ARCHITECTURE", "FILE_SIZE"}
SUBJECTIVE = {"MAINTAINABILITY", "ARCHITECTURE", "FILE_SIZE"}
HEX = re.compile(r"^[0-9a-f]{40,64}$")


def load(path):
    with open(path, encoding="utf-8") as f: return json.load(f)


def extract(raw):
    """Accept OpenCode JSONL/events but exactly one assistant result object."""
    text_chunks = []
    for line in raw.splitlines():
        try: obj = json.loads(line)
        except json.JSONDecodeError: continue
        if not isinstance(obj, dict): continue
        # OpenCode emits text parts/events; accept only assistant text payloads.
        texts = []
        if obj.get("type") in {"text", "assistant"}:
            part = obj.get("part", obj)
            if isinstance(part, dict) and isinstance(part.get("text"), str): texts.append(part["text"])
            elif isinstance(obj.get("text"), str): texts.append(obj["text"])
        if obj.get("role") == "assistant" and isinstance(obj.get("content"), str): texts.append(obj["content"])
        text_chunks.extend(texts)
    objects = []
    if text_chunks:
        # Streaming JSON format may split one assistant object across several
        # text events. Concatenate those events, but never search/repair prose.
        candidate = "".join(text_chunks).strip()
        if candidate.startswith("{") and candidate.endswith("}"):
            try: objects = [json.loads(candidate)]
            except json.JSONDecodeError: objects = []
    if not objects:
        # Fixtures and direct CLI captures may contain exactly one JSON object.
        stripped = raw.strip()
        if stripped.startswith("{") and stripped.endswith("}"):
            objects = [json.loads(stripped)]
    if len(objects) != 1 or not isinstance(objects[0], dict):
        raise ValueError("REVIEW_INVALID: output must contain exactly one assistant JSON object")
    return objects[0]


def fail(msg): raise ValueError("REVIEW_INVALID: " + msg)


def validate(report, manifest):
    if report.get("version") != "dotfiles.ai-review/v1": fail("unknown version")
    for field in ("base_sha", "head_sha", "merge_base", "manifest_sha256", "policy_sha256"):
        if not isinstance(report.get(field), str) or not HEX.fullmatch(report[field]): fail(f"invalid {field}")
    for field in ("base_sha", "head_sha", "merge_base", "policy_sha256"):
        if report[field].lower() != manifest[field].lower(): fail(f"{field} does not bind to manifest")
    if report["manifest_sha256"].lower() != manifest["manifest_sha256"].lower(): fail("manifest hash mismatch")
    findings = report.get("findings")
    if not isinstance(findings, list) or len(findings) > MAX_FINDINGS: fail("findings must be an array of at most seven")
    state = manifest.get("state")
    if state == "NOT_APPLICABLE" and findings: fail("NOT_APPLICABLE cannot include findings")
    anchors = {(a["path"], x["side"], x["line"]): x for a in manifest.get("files", []) for x in a.get("anchors", [])}
    paths = {f["path"] for f in manifest.get("files", [])}
    ids = set(); severe = False
    normalized = []
    for f in findings:
        if not isinstance(f, dict): fail("finding must be an object")
        required = ("id", "rule_id", "severity", "confidence", "path", "side", "line", "evidence", "title", "trigger", "impact", "fix")
        if any(k not in f for k in required): fail("finding missing required field")
        if not isinstance(f["id"], str) or not re.fullmatch(r"F[0-9]{1,3}", f["id"]): fail("invalid finding id")
        if f["id"] in ids: fail("duplicate model finding id")
        if f["rule_id"] not in RULES: fail("unknown rule id")
        if f["severity"] not in SEVERITIES or f["confidence"] not in CONFIDENCE: fail("unknown severity or confidence")
        if f["rule_id"] in SUBJECTIVE and f["severity"] in {"BLOCKER", "CRITICAL"}: fail("subjective rule exceeds WARNING cap")
        if f["confidence"] != "HIGH" and f["severity"] in {"BLOCKER", "CRITICAL"}: fail("only HIGH-confidence findings may block")
        canonical = {k: f[k] for k in ("rule_id", "severity", "confidence", "path", "side", "line", "evidence", "title", "trigger", "impact", "fix")}
        import hashlib
        fingerprint = hashlib.sha256(json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        derived_id = "F" + fingerprint[:12]
        if derived_id in ids: fail("duplicate canonical finding")
        ids.add(derived_id)
        if f["path"] not in paths or f["side"] not in {"LEFT", "RIGHT", "SUMMARY"} or not isinstance(f["line"], int) or (f["side"] == "SUMMARY" and f["line"] != 0) or (f["side"] != "SUMMARY" and f["line"] < 1): fail("invalid changed location")
        anchor = anchors.get((f["path"], f["side"], f["line"]))
        if anchor is None: fail("location is not a changed-line anchor")
        if not isinstance(f["evidence"], str) or not f["evidence"] or len(f["evidence"]) > MAX_TEXT or f["evidence"] not in anchor["text"]: fail("evidence is not literal anchor text")
        for k in required:
            if k in {"line"}: continue
            if not isinstance(f[k], str) or not f[k] or len(f[k]) > MAX_TEXT: fail(f"invalid bounded field {k}")
        if f["severity"] in {"BLOCKER", "CRITICAL"}: severe = True
        normalized.append({**f, "id": derived_id, "fingerprint": fingerprint})
    conclusion = report.get("conclusion")
    if conclusion not in {"PASS", "BLOCK"}: fail("invalid conclusion")
    if (conclusion == "BLOCK") != severe: fail("conclusion contradicts finding severities")
    return {"validation": "trusted", "version": report["version"], "base_sha": manifest["base_sha"], "head_sha": manifest["head_sha"], "merge_base": manifest["merge_base"], "policy_sha256": manifest["policy_sha256"],
            "manifest_sha256": manifest["manifest_sha256"], "state": state, "conclusion": conclusion,
            "trusted_conclusion": "BLOCK" if severe else ("NOT_APPLICABLE" if state == "NOT_APPLICABLE" else "PASS"),
            "findings": normalized}


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--input"); ap.add_argument("--manifest", required=True); ap.add_argument("--output", required=True); ap.add_argument("--not-applicable", action="store_true")
    ns = ap.parse_args()
    try:
        manifest = load(ns.manifest)
        if ns.not_applicable:
            if manifest.get("state") != "NOT_APPLICABLE": raise ValueError("REVIEW_INVALID: manifest is applicable")
            validated = {"validation": "trusted", "version": "dotfiles.ai-review/v1", "base_sha": manifest["base_sha"], "head_sha": manifest["head_sha"], "merge_base": manifest["merge_base"], "policy_sha256": manifest["policy_sha256"], "manifest_sha256": manifest["manifest_sha256"], "state": "NOT_APPLICABLE", "conclusion": "PASS", "trusted_conclusion": "NOT_APPLICABLE", "findings": []}
        else:
            if not ns.input: raise ValueError("REVIEW_INVALID: --input is required")
            with open(ns.input, encoding="utf-8") as f: raw = f.read()
            report = extract(raw)
            validated = validate(report, manifest)
        with open(ns.output, "w", encoding="utf-8", newline="\n") as f: json.dump(validated, f, ensure_ascii=False, sort_keys=True, indent=2); f.write("\n")
    except Exception as e:
        print(str(e), file=sys.stderr); return 1
    print(json.dumps({"valid": True, "conclusion": validated["trusted_conclusion"], "findings": len(validated["findings"])}, separators=(",", ":")))
    return 0
if __name__ == "__main__": raise SystemExit(main())
