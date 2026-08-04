#!/usr/bin/env python3
"""Run a bounded, project-native QA check before Codex can stop.

The hook deliberately enforces the useful invariant (changed application code
has fresh test evidence) without pretending that every dotfiles/configuration
change needs an application test suite. It never uses a shell string: project
commands are selected from known argv forms and executed without shell=True.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, NamedTuple, Optional


SOURCE_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cs",
    ".dart",
    ".ex",
    ".exs",
    ".go",
    ".h",
    ".hh",
    ".hpp",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".kts",
    ".php",
    ".py",
    ".rb",
    ".rs",
    ".scala",
    ".sh",
    ".swift",
    ".ts",
    ".tsx",
    ".vue",
    ".svelte",
}

TEST_PATH_RE = re.compile(
    r"(^|/)(test|tests|spec|specs|__tests__|fixtures|mocks|__mocks__)(/|$)"
    r"|\.(test|spec)\.[^/]+$|(^|/)(test_[^/]+|[^/]+_test)\.[^/]+$",
    re.IGNORECASE,
)

GENERATED_PARTS = {
    ".git",
    ".next",
    ".nuxt",
    ".turbo",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "target",
    "vendor",
}

# Configuration/infrastructure trees are validated with their own syntax and
# fixtures. An application test runner is the wrong gate for them; application
# code nested under `src/` or another production tree is still detected.
NON_APPLICATION_PREFIXES = (
    ".codex/",
    "config/",
)

MANIFEST_NAMES = {
    "Cargo.toml",
    "Gemfile",
    "Package.swift",
    "composer.json",
    "go.mod",
    "go.work",
    "package.json",
    "pom.xml",
    "pyproject.toml",
    "setup.cfg",
    "tox.ini",
}


class Runner(NamedTuple):
    argv: tuple[str, ...]
    label: str


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def run_command(
    argv: Iterable[str],
    *,
    cwd: Path,
    timeout: float,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(argv),
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def git_output(root: Path, args: list[str], timeout: float = 5) -> str:
    try:
        result = run_command(["git", "-C", str(root), *args], cwd=root, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def git_root(cwd: Path) -> Optional[Path]:
    output = git_output(cwd, ["rev-parse", "--show-toplevel"])
    if not output:
        return None
    try:
        return Path(output).resolve()
    except OSError:
        return None


def changed_files(root: Path) -> list[str]:
    names: set[str] = set()
    for args in (
        ["diff", "--name-only", "HEAD"],
        ["diff", "--name-only", "--cached"],
        ["ls-files", "--others", "--exclude-standard"],
    ):
        output = git_output(root, args)
        names.update(line for line in output.splitlines() if line.strip())
    return sorted(names)


def path_parts(path: str) -> tuple[str, ...]:
    return PurePosixPath(path.replace(os.sep, "/")).parts


def is_test_path(path: str) -> bool:
    return bool(TEST_PATH_RE.search(path.replace(os.sep, "/")))


def is_generated_path(path: str) -> bool:
    return any(part in GENERATED_PARTS for part in path_parts(path))


def is_non_application_path(path: str) -> bool:
    normalized = path.replace(os.sep, "/")
    return normalized.startswith(NON_APPLICATION_PREFIXES)


def is_source_file(path: str) -> bool:
    return Path(path).suffix.lower() in SOURCE_EXTENSIONS


def is_manifest(path: str) -> bool:
    return Path(path).name in MANIFEST_NAMES


def application_changes(files: list[str]) -> tuple[list[str], bool]:
    """Return production source files and whether a test must run."""

    production: list[str] = []
    verification_needed = False
    for path in files:
        if is_generated_path(path) or is_non_application_path(path):
            continue
        if is_test_path(path):
            verification_needed = True
            continue
        if is_source_file(path):
            production.append(path)
            verification_needed = True
            continue
        if is_manifest(path):
            verification_needed = True
    return production, verification_needed


def read_json(path: Path) -> Optional[dict[str, Any]]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def meaningful_script(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    lowered = value.lower()
    return "no test specified" not in lowered and "no tests specified" not in lowered


def package_manager(root: Path, package: dict[str, Any]) -> str | None:
    lockfiles = (
        ("pnpm-lock.yaml", "pnpm"),
        ("yarn.lock", "yarn"),
        ("bun.lock", "bun"),
        ("bun.lockb", "bun"),
        ("package-lock.json", "npm"),
    )
    for filename, manager in lockfiles:
        if (root / filename).exists():
            return manager

    declared = package.get("packageManager")
    if isinstance(declared, str) and "@" in declared:
        manager = declared.split("@", 1)[0].strip()
        if manager in {"npm", "pnpm", "yarn", "bun"}:
            return manager
    return "npm"


def javascript_runner(root: Path) -> tuple[Optional[Runner], Optional[str]]:
    package_path = root / "package.json"
    package = read_json(package_path)
    if package is None:
        return None, "package.json no se pudo leer como JSON"
    scripts = package.get("scripts")
    scripts = scripts if isinstance(scripts, dict) else {}
    script_name = next(
        (
            name
            for name in ("test", "test:ci", "test:unit", "test:all")
            if meaningful_script(scripts.get(name))
        ),
        None,
    )
    if script_name is None:
        return None, "package.json no define un script de test ejecutable"

    manager = package_manager(root, package)
    if manager is None or shutil.which(manager) is None:
        return None, f"el package manager requerido ({manager}) no está instalado"
    argv = (manager, "test") if script_name == "test" else (manager, "run", script_name)
    label = f"{manager} test" if script_name == "test" else f"{manager} run {script_name}"
    return Runner(argv, label), None


def python_runner(root: Path) -> tuple[Optional[Runner], Optional[str]]:
    project_markers = (
        root / "pyproject.toml",
        root / "pytest.ini",
        root / "setup.cfg",
        root / "tox.ini",
    )
    has_tests_dir = any(
        (root / directory).is_dir() for directory in ("test", "tests")
    )
    if not any(marker.exists() for marker in project_markers) and not has_tests_dir:
        return None, None

    for candidate in (root / ".venv/bin/python", root / "venv/bin/python"):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return Runner((str(candidate), "-m", "pytest", "-q"), f"{candidate} -m pytest -q"), None
    pytest = shutil.which("pytest")
    if pytest:
        return Runner((pytest, "-q"), f"{pytest} -q"), None
    return None, "se detectó un proyecto Python, pero pytest no está disponible"


def standard_runner(root: Path) -> tuple[Optional[Runner], Optional[str]]:
    if (root / "go.mod").exists() or (root / "go.work").exists():
        return (
            Runner(("go", "test", "./..."), "go test ./..."),
            None if shutil.which("go") else "go no está instalado",
        )
    if (root / "Cargo.toml").exists():
        return (
            Runner(("cargo", "test"), "cargo test"),
            None if shutil.which("cargo") else "cargo no está instalado",
        )
    if (root / "Package.swift").exists():
        return (
            Runner(("swift", "test"), "swift test"),
            None if shutil.which("swift") else "swift no está instalado",
        )
    if (root / "pom.xml").exists():
        command = "./mvnw" if (root / "mvnw").is_file() else "mvn"
        if command == "mvn" and shutil.which(command) is None:
            return None, "maven no está instalado"
        return Runner((command, "test"), f"{command} test"), None
    if (root / "gradlew").is_file():
        return Runner(("./gradlew", "test"), "./gradlew test"), None
    if (root / "Gemfile").exists() and shutil.which("bundle"):
        if (root / "Rakefile").exists() or any((root / d).is_dir() for d in ("test", "spec")):
            return Runner(("bundle", "exec", "rake", "test"), "bundle exec rake test"), None
    if (root / "composer.json").exists() and shutil.which("composer"):
        composer = read_json(root / "composer.json") or {}
        scripts = composer.get("scripts")
        if isinstance(scripts, dict) and meaningful_script(scripts.get("test")):
            return Runner(("composer", "run-script", "test"), "composer run-script test"), None
    if any(root.glob("*.sln")) or any(root.glob("*.csproj")):
        return (
            Runner(("dotnet", "test", "--nologo"), "dotnet test --nologo"),
            None if shutil.which("dotnet") else "dotnet no está instalado",
        )
    return None, None


def detect_runner(root: Path) -> tuple[Optional[Runner], Optional[str]]:
    if (root / "package.json").exists():
        runner, reason = javascript_runner(root)
        if runner or reason:
            return runner, reason
    runner, reason = python_runner(root)
    if runner or reason:
        return runner, reason
    return standard_runner(root)


def timeout_seconds() -> int:
    try:
        value = int(os.environ.get("CODEX_QA_TIMEOUT", "180"))
    except ValueError:
        value = 180
    return max(30, min(value, 600))


def tail_output(result: Optional[subprocess.CompletedProcess], limit: int = 24) -> str:
    if result is None:
        return ""
    output = "\n".join(part for part in (result.stdout, result.stderr) if part).strip()
    if not output:
        return "(sin salida)"
    return "\n".join(output.splitlines()[-limit:])


def failure_payload(reason: str, *, stop_hook_active: bool) -> dict[str, str]:
    if stop_hook_active:
        return {
            "systemMessage": (
                "Codex QA sigue sin pasar después de una continuación automática. "
                "No afirmes que el cambio está verificado; deja el bloqueo explícito "
                "o continúa corrigiendo en un nuevo turno.\n\n"
                + reason
            )
        }
    return {"decision": "block", "reason": reason}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, TypeError):
        # A malformed hook payload is not a reason to execute an arbitrary
        # command. Return valid JSON and let Codex report the malformed input.
        emit({"systemMessage": "Codex QA: input del hook no válido; no se ejecutó ningún test."})
        return 0

    if not isinstance(payload, dict):
        emit({"systemMessage": "Codex QA: input del hook no válido; no se ejecutó ningún test."})
        return 0

    cwd_value = payload.get("cwd")
    cwd = Path(cwd_value if isinstance(cwd_value, str) and cwd_value else os.getcwd()).resolve()
    root = git_root(cwd)
    if root is None:
        emit({})
        return 0

    files = changed_files(root)
    if not files:
        emit({})
        return 0

    production, verification_needed = application_changes(files)
    if not verification_needed:
        emit({})
        return 0

    # Explicitly opt out only for a repository that documents why a real test
    # runner cannot exist. This is intentionally not inherited from another
    # agent's configuration and is not enabled by this dotfiles repository.
    if os.environ.get("CODEX_QA_RELAXED") == "1" or (root / ".codex-qa-relaxed").exists():
        emit({
            "systemMessage": (
                "Codex QA relajado explícitamente para este repositorio; "
                "no se bloqueó el cierre. Revisa la razón y la evidencia manual."
            )
        })
        return 0

    diff_checks = (
        run_command(["git", "-C", str(root), "diff", "--check"], cwd=root, timeout=10),
        run_command(["git", "-C", str(root), "diff", "--cached", "--check"], cwd=root, timeout=10),
    )
    diff_check = next((check for check in diff_checks if check.returncode != 0), None)
    if diff_check is not None:
        reason = (
            "Codex QA bloqueó el cierre: `git diff --check` encontró whitespace "
            "problemático. Corrígelo y vuelve a ejecutar la verificación.\n\n"
            + tail_output(diff_check)
        )
        emit(failure_payload(reason, stop_hook_active=bool(payload.get("stop_hook_active"))))
        return 0

    runner, runner_reason = detect_runner(root)
    if runner is None:
        changed = ", ".join(production[:8]) if production else "tests/manifests"
        reason = (
            "Codex QA bloqueó el cierre: hay cambios verificables "
            f"({changed}), pero no se encontró un test runner ejecutable. "
            "Usa el runner nativo del proyecto o configura su script de test; "
            "no declares el cambio terminado sin evidencia."
        )
        if runner_reason:
            reason += f"\n\nDetalle: {runner_reason}."
        emit(failure_payload(reason, stop_hook_active=bool(payload.get("stop_hook_active"))))
        return 0

    try:
        result = run_command(runner.argv, cwd=root, timeout=timeout_seconds())
    except subprocess.TimeoutExpired as exc:
        output = "\n".join(
            part for part in (exc.stdout, exc.stderr) if isinstance(part, str) and part
        ).strip()
        reason = (
            f"Codex QA bloqueó el cierre: `{runner.label}` superó el límite de "
            f"{timeout_seconds()} segundos. Corrige el bloqueo o ejecuta una "
            "verificación focalizada con evidencia antes de terminar."
        )
        if output:
            reason += "\n\n" + "\n".join(output.splitlines()[-24:])
        emit(failure_payload(reason, stop_hook_active=bool(payload.get("stop_hook_active"))))
        return 0
    except OSError as exc:
        reason = f"Codex QA no pudo ejecutar `{runner.label}`: {exc}."
        emit(failure_payload(reason, stop_hook_active=bool(payload.get("stop_hook_active"))))
        return 0

    if result.returncode != 0:
        reason = (
            f"Codex QA bloqueó el cierre: `{runner.label}` terminó con código "
            f"{result.returncode}. Corrige la causa y vuelve a ejecutar el test; "
            "no uses el hook como algo que haya que esquivar.\n\n"
            + tail_output(result)
        )
        emit(failure_payload(reason, stop_hook_active=bool(payload.get("stop_hook_active"))))
        return 0

    emit({
        "systemMessage": (
            f"Codex QA verificado: `{runner.label}` pasó con código 0. "
            "La evidencia corresponde al estado actual del workspace."
        )
    })
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
