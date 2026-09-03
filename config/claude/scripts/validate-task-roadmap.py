#!/usr/bin/env python3
"""Validate a Markdown task ledger without requiring an external runtime.

Recognized task lines use the existing SDD checklist shape plus an optional
dependency annotation::

    - [ ] T001 [depends_on: none] Create the baseline
    - [ ] T002 [depends_on: T001] Implement the next step

The validator checks graph integrity and can report a conservative ownership
review for theoretical parallel frontiers. Acceptance criteria, verification
commands, and receipts remain the responsibility of the task contract hook and
the project-native test runner.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


TASK_PATTERN = re.compile(
    r"^\s*-\s*\[([ xX>])\]\s+((?:T[A-Za-z0-9_.-]*|[0-9]+(?:\.[0-9]+)*))\b(.*)$"
)
DEPENDENCY_PATTERN = re.compile(r"\[depends_on:\s*([^\]]*)\]", re.IGNORECASE)
PATHS_PATTERN = re.compile(r"\[paths?:\s*([^\]]*)\]", re.IGNORECASE)


def normalize_paths(raw: str) -> list[str]:
    """Normalize ownership claims without interpreting them as commands."""

    paths: list[str] = []
    for item in re.split(r"[,;]", raw):
        path = item.strip().strip("`\"'")
        path = re.sub(r"^[.][/\\]", "", path)
        path = path.rstrip("/\\")
        if path.lower() in {"", "-", "none", "n/a", "na"}:
            continue
        if path not in paths:
            paths.append(path)
    return paths


def invalid_ownership_path(path: str) -> str | None:
    """Reject ownership claims that can escape the project or are malformed."""

    if "\x00" in path:
        return "contains NUL"
    if path.startswith(("/", "\\")):
        return "must be relative"
    components = re.split(r"[/\\]", path)
    if any(component in {".", ".."} for component in components):
        return "cannot contain . or .. path components"
    return None


def has_unresolved_glob(path: str) -> bool:
    """Return whether a claim needs repository-aware glob expansion."""

    return any(character in path for character in "*?[")


def parse_tasks(path: Path, strict: bool) -> tuple[dict[str, dict], list[str]]:
    tasks: dict[str, dict] = {}
    errors: list[str] = []

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return {}, [f"cannot read {path}: {exc}"]

    for line_number, line in enumerate(lines, start=1):
        match = TASK_PATTERN.match(line)
        if not match:
            continue

        status, task_id, subject = match.groups()
        if task_id in tasks:
            errors.append(
                f"line {line_number}: duplicate task id {task_id} "
                f"(first seen on line {tasks[task_id]['line']})"
            )
            continue

        dependency_match = DEPENDENCY_PATTERN.search(subject)
        if dependency_match is None:
            if strict:
                errors.append(
                    f"line {line_number}: {task_id} is missing "
                    "[depends_on: ...]"
                )
            dependencies: list[str] = []
        else:
            raw_dependencies = dependency_match.group(1).strip()
            dependencies = (
                []
                if raw_dependencies.lower() in {"", "none", "-"}
                else [item.strip() for item in raw_dependencies.split(",") if item.strip()]
            )

        paths_match = PATHS_PATTERN.search(subject)
        paths = normalize_paths(paths_match.group(1)) if paths_match else []
        for path in paths:
            reason = invalid_ownership_path(path)
            if reason:
                errors.append(
                    f"line {line_number}: {task_id} has invalid ownership path "
                    f"{path!r}: {reason}"
                )

        tasks[task_id] = {
            "line": line_number,
            "status": {" ": "pending", ">": "in_progress", "x": "completed", "X": "completed"}[status],
            "depends_on": dependencies,
            "paths": paths,
        }

    if not tasks:
        errors.append(f"{path}: no Markdown task checklist entries found")

    for task_id, task in tasks.items():
        for dependency in task["depends_on"]:
            if dependency not in tasks:
                errors.append(
                    f"line {task['line']}: {task_id} depends on missing task {dependency}"
                )
            elif dependency == task_id:
                errors.append(f"line {task['line']}: {task_id} cannot depend on itself")

    errors.extend(find_cycles(tasks))
    return tasks, errors


def find_cycles(tasks: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(task_id: str, trail: list[str]) -> None:
        if task_id in visiting:
            cycle_start = trail.index(task_id)
            cycle = trail[cycle_start:] + [task_id]
            errors.append("dependency cycle: " + " -> ".join(cycle))
            return
        if task_id in visited or task_id not in tasks:
            return

        visiting.add(task_id)
        for dependency in tasks[task_id]["depends_on"]:
            visit(dependency, trail + [task_id])
        visiting.remove(task_id)
        visited.add(task_id)

    for task_id in tasks:
        visit(task_id, [])
    return errors


def graph_metrics(tasks: dict[str, dict]) -> dict:
    """Return descriptive DAG metrics without acting as a scheduler.

    The metrics are intentionally observational. They show the theoretical
    dependency depth and current runnable frontier, but they never authorize
    parallel execution or infer file ownership.
    """

    metrics = {
        "available": False,
        "critical_path_length": None,
        "max_parallel_frontier": 0,
        "levels": [],
        "runnable_now": [],
        "blocked_now": [],
        "independence": {
            "status": "unavailable",
            "parallel_tasks": [],
            "unannotated_parallel_tasks": [],
            "ambiguous_parallel_tasks": [],
            "potential_conflicts": [],
        },
        "status_counts": {
            "pending": 0,
            "in_progress": 0,
            "completed": 0,
        },
    }
    if not tasks:
        return metrics

    for task in tasks.values():
        metrics["status_counts"][task["status"]] += 1

    # Missing dependencies and cycles are reported by parse_tasks; do not
    # manufacture graph metrics from an invalid roadmap.
    if any(
        dependency not in tasks
        for task in tasks.values()
        for dependency in task["depends_on"]
    ):
        return metrics

    remaining = set(tasks)
    depth: dict[str, int] = {}
    levels: list[list[str]] = []
    while remaining:
        ready = [
            task_id
            for task_id in tasks
            if task_id in remaining
            and all(dependency in depth for dependency in tasks[task_id]["depends_on"])
        ]
        if not ready:
            return metrics

        level = len(levels) + 1
        for task_id in ready:
            dependencies = tasks[task_id]["depends_on"]
            depth[task_id] = (
                1 + max((depth[dependency] for dependency in dependencies), default=0)
            )
            remaining.remove(task_id)
        levels.append(ready)

    runnable_now: list[str] = []
    blocked_now: list[str] = []
    for task_id, task in tasks.items():
        if task["status"] == "completed":
            continue
        if all(tasks[dependency]["status"] == "completed" for dependency in task["depends_on"]):
            runnable_now.append(task_id)
        elif task["status"] in {"pending", "in_progress"}:
            blocked_now.append(task_id)

    parallel_tasks = sorted(
        {task_id for level in levels if len(level) > 1 for task_id in level}
    )
    unannotated_parallel_tasks = sorted(
        task_id for task_id in parallel_tasks if not tasks[task_id]["paths"]
    )
    ambiguous_parallel_tasks = sorted(
        task_id
        for task_id in parallel_tasks
        if any(has_unresolved_glob(path) for path in tasks[task_id]["paths"])
    )
    potential_conflicts: list[dict[str, object]] = []
    for level in levels:
        if len(level) < 2:
            continue
        for index, left_id in enumerate(level):
            for right_id in level[index + 1 :]:
                shared_paths = sorted(
                    {
                        left_path
                        for left_path in tasks[left_id]["paths"]
                        for right_path in tasks[right_id]["paths"]
                        if paths_overlap(left_path, right_path)
                    }
                )
                if shared_paths:
                    potential_conflicts.append(
                        {
                            "left": left_id,
                            "right": right_id,
                            "shared_paths": shared_paths,
                        }
                    )

    if not parallel_tasks:
        independence_status = "not_applicable"
    elif potential_conflicts:
        independence_status = "conflict"
    elif unannotated_parallel_tasks or ambiguous_parallel_tasks:
        independence_status = "unproven"
    else:
        independence_status = "verified"

    metrics.update(
        {
            "available": True,
            "critical_path_length": max(depth.values()),
            "max_parallel_frontier": max(len(level) for level in levels),
            "levels": levels,
            "runnable_now": runnable_now,
            "blocked_now": blocked_now,
            "independence": {
                "status": independence_status,
                "parallel_tasks": parallel_tasks,
                "unannotated_parallel_tasks": unannotated_parallel_tasks,
                "ambiguous_parallel_tasks": ambiguous_parallel_tasks,
                "potential_conflicts": potential_conflicts,
            },
        }
    )
    return metrics


def paths_overlap(left: str, right: str) -> bool:
    """Return true for exact paths or directory-prefix overlap only.

    Globs are intentionally not expanded: a wildcard is an ownership claim
    that needs a real repository-aware analyzer, not a reason to guess.
    """

    if left == right:
        return True
    left_prefix = left.rstrip("/") + "/"
    right_prefix = right.rstrip("/") + "/"
    return left.startswith(right_prefix) or right.startswith(left_prefix)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("roadmap", type=Path, help="Markdown task roadmap to validate")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="require [depends_on: ...] on every task entry",
    )
    parser.add_argument(
        "--require-paths-for-parallel",
        action="store_true",
        help="reject theoretical parallel tasks without [paths: ...] annotations",
    )
    parser.add_argument("--json", action="store_true", help="emit a JSON result")
    args = parser.parse_args()

    tasks, errors = parse_tasks(args.roadmap, args.strict)
    graph = graph_metrics(tasks)
    if args.require_paths_for_parallel:
        independence = graph["independence"]
        if independence["status"] == "unproven":
            if independence["unannotated_parallel_tasks"]:
                errors.append(
                    "parallel frontier lacks concrete [paths: ...] annotations for: "
                    + ", ".join(independence["unannotated_parallel_tasks"])
                )
            if independence["ambiguous_parallel_tasks"]:
                errors.append(
                    "parallel frontier has unresolved glob ownership for: "
                    + ", ".join(independence["ambiguous_parallel_tasks"])
                )
        elif independence["status"] == "conflict":
            errors.append(
                "parallel frontier has overlapping paths: "
                + ", ".join(
                    f"{item['left']}↔{item['right']}"
                    for item in independence["potential_conflicts"]
                )
            )
    result = {
        "valid": not errors,
        "roadmap": str(args.roadmap),
        "task_count": len(tasks),
        "tasks": tasks,
        "errors": errors,
        "graph": graph,
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif errors:
        for error in errors:
            print(f"[task-roadmap] {error}", file=sys.stderr)
    else:
        graph = result["graph"]
        print(
            f"[task-roadmap] valid: {args.roadmap} ({len(tasks)} tasks; "
            f"critical path {graph['critical_path_length']}, "
            f"max frontier {graph['max_parallel_frontier']})"
        )

    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
