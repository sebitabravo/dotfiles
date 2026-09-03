#!/usr/bin/env python3
"""Publish one owned summary and finding comments with fail-closed API semantics."""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys
import base64
SUMMARY = "<!-- dotfiles-ai-review:summary:v1 -->"
FINDING = re.compile(r"^<!-- dotfiles-ai-review:finding:([A-Za-z0-9_-]+):v1 -->$")
ANCHOR = re.compile(r"^<!-- dotfiles-ai-review:anchor:v1:(?P<commit>[0-9a-f]{40,64}):(?P<side>LEFT|RIGHT):(?P<line>[0-9]+):(?P<path>[A-Za-z0-9_-]+) -->$")

class ApiError(RuntimeError): pass

def gh(args, data=None):
    p = subprocess.run(["gh", "api", *args], input=(json.dumps(data).encode() if data is not None else None), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0: raise ApiError(p.stderr.decode("utf-8", "replace").strip() or f"gh api failed ({p.returncode})")
    return p.stdout

def comments(url):
    raw = gh(["--paginate", "--slurp", url])
    if not raw.strip(): return []
    value = json.loads(raw)
    if value and isinstance(value[0], list):
        return [x for page in value for x in page]
    return value if isinstance(value, list) else []

def is_bot(c): return isinstance(c, dict) and (c.get("user") or {}).get("login") == "github-actions[bot]"
def body(c): return c.get("body", "") if isinstance(c.get("body"), str) else ""
def first_marker(c, pattern):
    lines=body(c).splitlines()
    return pattern.match(lines[0]) if lines else None
def encoded_path(path):
    return base64.urlsafe_b64encode(path.encode("utf-8", "surrogateescape")).decode().rstrip("=")
def display_path(path):
    return path.encode("utf-8", "surrogateescape").decode("utf-8", "replace")
def anchor_marker(report, finding):
    return f"<!-- dotfiles-ai-review:anchor:v1:{report['head_sha']}:{finding['side']}:{finding['line']}:{encoded_path(finding['path'])} -->"
def mutation(url, method, payload):
    return gh([url, "--method", method, "--input", "-"], payload)

def render(report):
    findings = report["findings"]
    title = "Review passed" if report["trusted_conclusion"] != "BLOCK" else "Review blocked"
    lines = [SUMMARY, "", f"## 🤖 Code review: {title}", "", f"Base: `{report['base_sha']}`", f"Head: `{report['head_sha']}`", ""]
    if not findings: lines.append("No verified findings.")
    else:
        lines += ["| Severity | Location | Finding |", "|---|---|---|"]
        for f in findings:
            lines.append(f"| {f['severity']} | `{display_path(f['path'])}:{f['line']}` ({f['side']}) | {f['title']} |")
    summary = "\n".join(lines) + "\n"
    inline = {}
    for f in findings:
        inline[f["id"]] = (
            f"<!-- dotfiles-ai-review:finding:{f['id']}:v1 -->\n{anchor_marker(report, f)}\n**{f['severity']}** `{display_path(f['path'])}:{f['line']}` ({f['side']})\n\n"
            f"**{f['title']}**\n\n{f['trigger']}\n\nImpact: {f['impact']}\n\nFix: {f['fix']}\n\nEvidence: `{f['evidence']}`\n")
    return summary, inline

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("report"); ap.add_argument("--publish", action="store_true"); ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY")); ap.add_argument("--pr", default=os.environ.get("PR_NUMBER")); ap.add_argument("--head-sha", default=os.environ.get("HEAD_SHA")); ap.add_argument("--base-sha", default=os.environ.get("BASE_SHA"))
    ns=ap.parse_args()
    with open(ns.report, encoding="utf-8") as f: report=json.load(f)
    if (ns.head_sha and report.get("head_sha") != ns.head_sha) or (ns.base_sha and report.get("base_sha") != ns.base_sha):
        print("report identity does not match workflow SHAs", file=sys.stderr); return 1
    summary, inline = render(report)
    with open("comment.md", "w", encoding="utf-8", newline="\n") as f: f.write(summary)
    if not ns.publish:
        print("comment generated (publish skipped): " + os.path.abspath("comment.md")); return 0
    if not ns.repo or not ns.pr: print("repo and PR number are required", file=sys.stderr); return 2
    try:
        def assert_identity():
            current = json.loads(gh([f"repos/{ns.repo}/pulls/{ns.pr}"]))
            if current.get("head", {}).get("sha") != report["head_sha"] or current.get("base", {}).get("sha") != report["base_sha"]:
                raise ApiError("PR base or head changed; refusing stale review")
        assert_identity()
        issue_url=f"repos/{ns.repo}/issues/{ns.pr}/comments"
        issue=[c for c in comments(issue_url) if is_bot(c) and first_marker(c, re.compile(re.escape(SUMMARY) + r"$"))]
        successes=0
        if issue:
            current=issue[0]; mutation(f"repos/{ns.repo}/issues/comments/{current['id']}", "PATCH", {"body": summary}); successes += 1
        else:
            mutation(issue_url, "POST", {"body": summary}); successes += 1
        pr_url=f"repos/{ns.repo}/pulls/{ns.pr}/comments"
        owned=[c for c in comments(pr_url) if is_bot(c) and first_marker(c, FINDING)]
        by_id={}; duplicate_owned=[]
        for c in owned:
            marker=first_marker(c, FINDING); fid=marker.group(1)
            if fid in by_id: duplicate_owned.append(c)
            else: by_id[fid]=(c, marker.group(0))
        replace_old=[]
        for fid, text in inline.items():
            f=next(x for x in report["findings"] if x["id"]==fid)
            if f["side"] == "SUMMARY":
                continue
            payload={"body":text,"path":f["path"],"line":f["line"],"side":f["side"],"commit_id":report["head_sha"]}
            anchor_lines=body(by_id[fid][0]).splitlines() if fid in by_id else []
            expected_anchor=anchor_marker(report, f)
            if fid in by_id and len(anchor_lines) > 1 and anchor_lines[1] == expected_anchor:
                mutation(f"repos/{ns.repo}/pulls/comments/{by_id[fid][0]['id']}", "PATCH", {"body":text}); successes += 1
            else:
                mutation(pr_url, "POST", payload); successes += 1
                if fid in by_id: replace_old.append(by_id[fid][0])
        # Recheck both immutable PR identities after current upserts and before
        # deleting stale comments.
        assert_identity()
        # Only after every current summary/finding mutation succeeded, remove
        # exact-marker stale comments. Never touch human or non-owned comments.
        keep={f["id"] for f in report["findings"] if f["side"] != "SUMMARY"}
        for c in issue[1:]: mutation(f"repos/{ns.repo}/issues/comments/{c['id']}", "DELETE", {}); successes += 1
        for fid, (c, marker) in by_id.items():
            if fid not in keep or c in replace_old: mutation(f"repos/{ns.repo}/pulls/comments/{c['id']}", "DELETE", {}); successes += 1
        for c in duplicate_owned:
            mutation(f"repos/{ns.repo}/pulls/comments/{c['id']}", "DELETE", {}); successes += 1
        assert_identity()
        print(f"published {successes} successful API mutations")
        return 0
    except (ApiError, json.JSONDecodeError, OSError) as e:
        print(f"publication failed: {e}", file=sys.stderr); return 1
if __name__ == "__main__": raise SystemExit(main())
