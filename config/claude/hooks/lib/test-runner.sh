#!/usr/bin/env bash
# test-runner.sh — detecta COMO corre sus tests este repo.
#
# POR QUE EXISTE: quality-gate.sh y gauntlet-stop.sh tenian cada uno su propia
# deteccion, con la misma limitacion — asumian que el manifiesto vive en la raiz
# del repo git y que el runner esta en el PATH. En un monorepo real eso falla en
# silencio y el hook reporta verde sin haber corrido nada, que es peor que no
# tener hook.
#
# Caso que lo motivo: un repo con `backend/pyproject.toml`, `landing/package.json`
# y un Makefile cuyo target es `cd backend && uv run pytest`. No hay pyproject en
# la raiz y `pytest` no esta en el PATH (vive en el venv que maneja uv), asi que
# la deteccion vieja no encontraba runner y salia 0.
#
# ORDEN DE PRECEDENCIA — un runner explicito del repo gana porque expresa la
# validacion que sus autores definieron sin imponer una herramienta de build.
# Luego vienen Make/Just y los manifiestos detectables por convencion.
#
# Setea TEST_CMD (vacio si no se pudo determinar) y TEST_CMD_SOURCE con el nivel
# de precedencia que lo eligio:
#
#   declared  el repo escribio el comando (test.sh, target de make/just)
#   inferred  lo dedujimos de un manifiesto por convencion
#
# La distincion importa para quien consuma esto: un comando `declared` es la
# definicion que dieron los autores del repo y no se reemplaza por una variante
# nuestra "equivalente pero con flag de cobertura". Uno `inferred` si, porque ya
# es una suposicion propia.

# Utilidad compartida de PID walk — deduplicada con github-request.sh
# Ver lib/process-utils.sh. Los tokenizers de quality-gate (split_shell_segments),
# validate-safe-ops (resolve_command_prefix) y privacy-review (shlex) son
# intencionalmente distintos: cada uno parsea un dominio diferente (segmentos
# de shell vs prefijo de comando vs argv de gh) y no son duplicacion.
# shellcheck source=process-utils.sh
_TEST_RUNNER_UTILS_LIB="$(dirname -- "${BASH_SOURCE[0]:-${0}}")/process-utils.sh"
[ -f "$_TEST_RUNNER_UTILS_LIB" ] && . "$_TEST_RUNNER_UTILS_LIB"

# Repository-owned runners are executable code, even when their path is safely
# quoted. Stop hooks therefore require an explicit user-owned trust decision
# before they call detect_test_cmd or execute TEST_CMD. The trust file lives
# outside the repository and contains one exact git-root path per line. Tests
# use CLAUDE_REPOSITORY_TRUST_FILE to point at an isolated fixture.
repository_trust_file() {
  printf '%s' "${CLAUDE_REPOSITORY_TRUST_FILE:-$HOME/.claude/trusted-repositories}"
}

canonical_directory() {
  local directory="$1"
  (cd -- "$directory" 2>/dev/null && pwd -P)
}

repository_is_trusted() {
  local root="$1" trust_file trusted canonical_root canonical_trusted

  canonical_root=$(canonical_directory "$root") || return 1

  if [ -n "${CLAUDE_TRUSTED_REPOSITORY:-}" ] &&
    canonical_trusted=$(canonical_directory "$CLAUDE_TRUSTED_REPOSITORY") &&
    [ "$canonical_trusted" = "$canonical_root" ]; then
    return 0
  fi

  trust_file=$(repository_trust_file)
  [ -f "$trust_file" ] || return 1
  while IFS= read -r trusted || [ -n "$trusted" ]; do
    case "$trusted" in
      '' | \#*) continue ;;
    esac
    canonical_trusted=$(canonical_directory "$trusted") || continue
    [ "$canonical_trusted" = "$canonical_root" ] && return 0
  done <"$trust_file"
  return 1
}

# A cache key that only covers root+session+invocation+cmd never changes
# when a session fixes the repo mid-Stop-turn (same transcript path keeps
# firing the same Stop hook). Folding this fingerprint into the entry_key
# makes a content change produce a fresh cache entry instead of replaying a
# stale result -- a stale FAIL that masks a real fix, or a stale PASS that
# masks a real regression reintroduced later in the same session.
#
# Bounded with run_with_timeout, the same guarantee the rest of this file
# gives the actual test command: a slow or hanging git (huge diff, stuck NFS
# mount, submodule recursion) must not stall the Stop hook past its budget
# with nothing watching this tramo. A timed-out or failed fingerprint returns
# a one-off unique value instead: that forces a cache MISS (a fresh, correct
# run) rather than risk reusing a stale result under an unknown repo state.
repository_content_fingerprint() {
  local root="$1" quoted_root cmd raw_output rc
  quoted_root=$(shell_quote "$root")
  cmd="if git -C $quoted_root rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C $quoted_root rev-parse HEAD 2>/dev/null
    git -C $quoted_root diff HEAD 2>/dev/null
    git -C $quoted_root status --porcelain=v1 --untracked-files=all 2>/dev/null
  else
    printf no-git
  fi"
  raw_output=$(run_with_timeout 10 "$cmd") && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s' "$raw_output" | shasum -a 256 | awk '{print $1}'
  else
    printf 'fingerprint-unavailable-%s-%s' "$$" "$(date +%s%N 2>/dev/null || date +%s)"
  fi
}

repository_trust_block() {
  local root="$1"
  printf '[test-runner] BLOCKED: repository runner is not trusted: %s\n' "$root"
  printf '[test-runner] Add that exact path to %s (outside the repository) or set CLAUDE_TRUSTED_REPOSITORY for this invocation.\n' "$(repository_trust_file)"
  printf '[test-runner] No repository-declared test command was executed.\n'
}

# TEST_CMD y TEST_CMD_SOURCE los consume quien sourcea este archivo
# (gauntlet-stop.sh, quality-gate.sh), no se usan aca adentro. shellcheck no
# cruza archivos y los reporta como variables muertas.
# shellcheck disable=SC2034

# TEST_CMD is intentionally a shell command string because some project-owned
# runners need operators such as `cd ... && ...`. Every filesystem path placed
# in that string must therefore be quoted for the second shell evaluation
# performed by run_with_timeout. Without this seam, a repository path with
# spaces fails and a path containing `;`, `$()` or backticks becomes command
# injection when the hook evaluates the runner.
shell_quote() {
  printf '%q' "$1"
}

detect_test_cmd() {
  local root="${1:-$PWD}"
  # Shell glob expansion of child manifests must be byte-order deterministic
  # regardless of the host locale.
  local LC_ALL=C
  TEST_CMD=""
  TEST_CMD_SOURCE=""

  # 1. Runner explicito para repos que no necesitan una herramienta de build.
  # .github/test.sh cubre el repo que saca su runner de la raiz para no
  # ensuciarla pero lo sigue versionando (no vive en un directorio administrado
  # que install.sh copie a un HOME).
  if [ -x "$root/test.sh" ]; then
    TEST_CMD="$(shell_quote "$root/test.sh")"
    TEST_CMD_SOURCE="declared"
    return 0
  fi
  if [ -x "$root/.github/test.sh" ]; then
    TEST_CMD="$(shell_quote "$root/.github/test.sh")"
    TEST_CMD_SOURCE="declared"
    return 0
  fi

  # 2. Makefile / justfile con target de test.
  if [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile" 2>/dev/null; then
    command -v make >/dev/null 2>&1 && {
      TEST_CMD="make test"
      TEST_CMD_SOURCE="declared"
      return 0
    }
  fi
  if [ -f "$root/justfile" ] && grep -qE '^test:' "$root/justfile" 2>/dev/null; then
    command -v just >/dev/null 2>&1 && {
      TEST_CMD="just test"
      TEST_CMD_SOURCE="declared"
      return 0
    }
  fi

  # 3. Inferred root and child manifests are packages. In a monorepo, collect
  # every applicable package in lexical path order and run them under one
  # timeout instead of returning after the first match.
  local package_dir package_cmd
  local -a child_commands=()
  if [ -d "$root" ]; then
    package_cmd=""
    _detect_js "$root" "$root" && package_cmd="$TEST_CMD"
    if [ -z "$package_cmd" ]; then
      _detect_python "$root" "$root" && package_cmd="$TEST_CMD"
    fi
    if [ -z "$package_cmd" ]; then
      _detect_compiled "$root" "$root" && package_cmd="$TEST_CMD"
    fi
    if [ -z "$package_cmd" ]; then
      _detect_managed "$root" "$root" && package_cmd="$TEST_CMD"
    fi
    [ -n "$package_cmd" ] && child_commands+=("$package_cmd")
  fi

  for package_dir in "$root"/*/; do
    [ -d "$package_dir" ] || continue
    package_cmd=""

    _detect_js "$package_dir" "$root" && package_cmd="$TEST_CMD"
    if [ -z "$package_cmd" ]; then
      _detect_python "$package_dir" "$root" && package_cmd="$TEST_CMD"
    fi
    if [ -z "$package_cmd" ]; then
      _detect_compiled "$package_dir" "$root" && package_cmd="$TEST_CMD"
    fi
    if [ -z "$package_cmd" ]; then
      _detect_managed "$package_dir" "$root" && package_cmd="$TEST_CMD"
    fi
    [ -n "$package_cmd" ] && child_commands+=("$package_cmd")
  done

  [ "${#child_commands[@]}" -gt 0 ] || return 1

  if [ "${#child_commands[@]}" -eq 1 ]; then
    TEST_CMD="${child_commands[0]}"
    TEST_CMD_SOURCE="inferred"
    return 0
  fi

  # The command fragments above are produced only by this detector's static
  # allowlist. Each fragment runs in a subshell so one package's `cd` cannot
  # affect the next package. Continue after failures so every applicable
  # package is exercised, then return failure if any package failed.
  local composite='set +e; _test_failed=0' command_fragment
  for command_fragment in "${child_commands[@]}"; do
    composite="$composite; ( $command_fragment ); _test_rc=\$?; if [ \$_test_rc -ne 0 ]; then _test_failed=1; fi"
  done
  TEST_CMD="$composite; exit \$_test_failed"
  # TEST_CMD_SOURCE is a public output of this sourced helper; callers consume it.
  # shellcheck disable=SC2034
  TEST_CMD_SOURCE="inferred"
  return 0
}

# Arma TEST_CMD con el prefijo `cd` solo cuando el manifiesto no esta en la raiz.
_emit() {
  local dir="$1" root="$2" cmd="$3"
  if [ "$dir" = "$root" ]; then
    TEST_CMD="$cmd"
  else
    TEST_CMD="cd $(shell_quote "$dir") && $cmd"
  fi
  # TEST_CMD_SOURCE is a public output consumed by callers that source this helper.
  # shellcheck disable=SC2034
  TEST_CMD_SOURCE="inferred"
  return 0
}

# El lockfile decide el package manager, no la preferencia personal: cambiarlo
# re-resuelve el arbol entero de dependencias (rules/common/security.md).
_js_manager() {
  local dir="$1"
  if [ -f "$dir/bun.lock" ] || [ -f "$dir/bun.lockb" ]; then
    echo bun
  elif [ -f "$dir/pnpm-lock.yaml" ]; then
    echo pnpm
  elif [ -f "$dir/yarn.lock" ]; then
    echo yarn
  else
    echo npm
  fi
}

_detect_js() {
  local dir="$1" root="$2"
  [ -f "$dir/package.json" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  # Un `test` que solo imprime "no test specified" es el placeholder de `npm
  # init`: existe, sale 0, y no corre nada. Tratarlo como runner es falso verde.
  local script=""
  local candidate
  for candidate in test test:ci test:unit test:all; do
    local value
    value=$(jq -r --arg k "$candidate" '.scripts[$k] // empty' "$dir/package.json" 2>/dev/null)
    [ -n "$value" ] || continue
    case "$value" in
      *"no test specified"* | *"no tests specified"*) continue ;;
    esac
    script="$candidate"
    break
  done
  [ -n "$script" ] || return 1

  local manager
  manager=$(_js_manager "$dir")
  command -v "$manager" >/dev/null 2>&1 || return 1

  # `bun test` is not an alias for the "test" script -- Bun special-cases the
  # bare form to invoke its own built-in native test runner instead, unlike
  # npm/pnpm/yarn where `<manager> test` really is shorthand for `run test`.
  # A repo whose package.json declares "test": "vitest run" (or any other
  # non-Bun runner) would get silently run under the wrong tool, and Bun's
  # partial Jest/Vitest-compat shim (missing `vi.mocked`, different `vi.fn`
  # call-forwarding for tagged templates) turns passing tests red for no
  # real reason. `bun run test` always means "run the package.json script".
  if [ "$script" = test ] && [ "$manager" != bun ]; then
    _emit "$dir" "$root" "$manager test"
  else
    _emit "$dir" "$root" "$manager run $script"
  fi
}

_detect_python() {
  local dir="$1" root="$2"
  { [ -f "$dir/pyproject.toml" ] || [ -f "$dir/pytest.ini" ] || [ -f "$dir/tox.ini" ]; } || return 1

  # El runner vive en el entorno del proyecto, no en el PATH global del shell.
  local venv
  for venv in "$dir/.venv/bin/pytest" "$dir/venv/bin/pytest"; do
    [ -x "$venv" ] && _emit "$dir" "$root" "$(shell_quote "$venv")" && return 0
  done
  [ -f "$dir/pyproject.toml" ] && command -v uv >/dev/null 2>&1 &&
    _emit "$dir" "$root" "uv run pytest" && return 0
  [ -f "$dir/poetry.lock" ] && command -v poetry >/dev/null 2>&1 &&
    _emit "$dir" "$root" "poetry run pytest" && return 0
  command -v pytest >/dev/null 2>&1 && _emit "$dir" "$root" "pytest" && return 0
  return 1
}

_detect_compiled() {
  local dir="$1" root="$2"
  [ -f "$dir/go.mod" ] && command -v go >/dev/null 2>&1 &&
    _emit "$dir" "$root" "go test ./..." && return 0
  [ -f "$dir/Cargo.toml" ] && command -v cargo >/dev/null 2>&1 &&
    _emit "$dir" "$root" "cargo test" && return 0
  [ -f "$dir/Package.swift" ] && command -v swift >/dev/null 2>&1 &&
    _emit "$dir" "$root" "swift test" && return 0
  # El wrapper versionado del repo le gana al binario global: fija la version
  # de la herramienta y no depende de lo que este instalado en la maquina.
  [ -x "$dir/gradlew" ] && _emit "$dir" "$root" "./gradlew test" && return 0
  if [ -f "$dir/pom.xml" ]; then
    [ -x "$dir/mvnw" ] && _emit "$dir" "$root" "./mvnw test" && return 0
    command -v mvn >/dev/null 2>&1 && _emit "$dir" "$root" "mvn test" && return 0
  fi
  return 1
}

_detect_managed() {
  local dir="$1" root="$2"

  if [ -f "$dir/composer.json" ] && command -v composer >/dev/null 2>&1 &&
    command -v jq >/dev/null 2>&1 &&
    jq -e '.scripts.test' "$dir/composer.json" >/dev/null 2>&1; then
    _emit "$dir" "$root" "composer run-script test" && return 0
  fi

  if [ -f "$dir/Gemfile" ] && command -v bundle >/dev/null 2>&1; then
    [ -d "$dir/spec" ] && _emit "$dir" "$root" "bundle exec rspec" && return 0
    [ -d "$dir/test" ] && _emit "$dir" "$root" "bundle exec rake test" && return 0
  fi

  # Glob explicito, no `ls *.sln *.csproj`: ls falla entero si uno de los dos
  # patrones no matchea, aunque el otro si — y el proyecto quedaba sin detectar.
  if command -v dotnet >/dev/null 2>&1; then
    local project
    for project in "$dir"/*.sln "$dir"/*.csproj; do
      [ -f "$project" ] || continue
      _emit "$dir" "$root" "dotnet test --nologo"
      return 0
    done
  fi

  return 1
}

# run_with_timeout: bounds an arbitrary shell command string (may contain
# `&&`, `cd`, pipes) to N seconds, portably. Execute it through a nested Bash
# rather than `eval` in the status-writing shell: a command containing `exit`
# must not skip the status write that tells the parent it completed.
#
# WHY THIS EXISTS: a stock macOS host has neither `timeout` nor `gtimeout`
# (coreutils is not installed by default, and this repo's own Brewfile does
# not declare it either). Without an internal bound, the ONLY thing that
# could ever stop a hanging test suite was the outer Claude Code hook-harness
# timeout in settings.json -- and a hook killed by that external timeout is
# fail-open (per Claude Code's own docs: a timed-out command hook does not
# block the tool call). A gate with no real internal bound on a slow-or-
# hanging suite is a gate that silently stops gating.
#
# Consumed by gauntlet-stop.sh and quality-gate.sh, both of which run a
# repo's own test command and both hit exactly this gap independently.
#
# Sets stdout to the command's combined stdout+stderr and returns 124 on
# timeout, matching `timeout`(1)'s own convention, so callers branch on the
# same exit code regardless of which path (real timeout, or the manual
# ps-polling fallback) actually ran.
run_with_timeout() {
  local timeout_seconds="$1" cmd="$2" result_file status_file pid elapsed_tenths rc tree_pids tp process_group

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" /bin/bash -c "$cmd" 2>&1
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_seconds" /bin/bash -c "$cmd" 2>&1
    return $?
  fi

  result_file=$(mktemp "${TMPDIR:-/tmp}/run-with-timeout.XXXXXX") || return 125
  status_file=$(mktemp "${TMPDIR:-/tmp}/run-with-timeout-status.XXXXXX") || {
    rm -f "$result_file"
    return 125
  }
  process_group=0
  # Give the command its own process group when the host exposes a native
  # session tool or the system Perl shim. This lets the timeout kill all
  # descendants without relying on ps/pgrep permissions, which may be denied
  # in a sandbox or by a hardened macOS environment.
  if command -v setsid >/dev/null 2>&1; then
    process_group=1
    # The nested shell intentionally expands these variables at runtime.
    # shellcheck disable=SC2016
    setsid /bin/bash -c 'bash -c "$1"; rc=$?; printf "%s\\n" "$rc" >"$2"; exit "$rc"' \
      run-with-timeout "$cmd" "$status_file" >"$result_file" 2>&1 &
  elif command -v perl >/dev/null 2>&1; then
    process_group=1
    perl -e 'setpgrp(0, 0) or die "$!\\n"; exec @ARGV or die "$!\\n"' \
      /bin/bash -c 'bash -c "$1"; rc=$?; printf "%s\\n" "$rc" >"$2"; exit "$rc"' \
      run-with-timeout "$cmd" "$status_file" >"$result_file" 2>&1 &
  else
    (
      /bin/bash -c "$cmd"
      rc=$?
      printf '%s\n' "$rc" >"$status_file"
    ) >"$result_file" 2>&1 &
  fi
  pid=$!
  elapsed_tenths=0
  while [ ! -s "$status_file" ]; do
    if [ "$elapsed_tenths" -ge $((timeout_seconds * 10)) ]; then
      # ONE discovery pass, signaled twice: see _process_tree_pids for why
      # re-walking pgrep -P for the KILL pass would miss a descendant whose
      # own parent already died to TERM in between.
      if [ "$process_group" -eq 1 ]; then
        kill -TERM -- "-$pid" >/dev/null 2>&1 || true
      else
        tree_pids=$(_process_tree_pids "$pid")
        for tp in $tree_pids; do kill -TERM "$tp" >/dev/null 2>&1 || true; done
      fi
      sleep 0.2
      if [ "$process_group" -eq 1 ]; then
        kill -KILL -- "-$pid" >/dev/null 2>&1 || true
      else
        for tp in $tree_pids; do kill -KILL "$tp" >/dev/null 2>&1 || true; done
      fi
      wait "$pid" >/dev/null 2>&1 || true
      rm -f "$result_file"
      rm -f "$status_file"
      return 124
    fi
    sleep 0.1
    elapsed_tenths=$((elapsed_tenths + 1))
  done

  wait "$pid" >/dev/null 2>&1 || true
  rc=$(cat "$status_file" 2>/dev/null) || {
    rm -f "$result_file" "$status_file"
    return 125
  }
  cat "$result_file"
  rm -f "$result_file" "$status_file"
  return "$rc"
}

# Run one trusted repository suite at most once for a Stop invocation. Claude
# executes matching Stop hooks concurrently, so a directory claim is the
# atomic owner election and the result files are the shared evidence. A
# missing/incomplete result is BLOCKED rather than PASS. The invocation key is
# deliberately separate from session_id: without it, a later Stop turn could
# reuse an earlier suite result. Callers without an invocation key run without
# caching because deduplicating them would risk a false PASS.
run_shared_test_once() {
  local root="$1" session_id="$2" invocation_key="$3" timeout_seconds="$4" cmd="$5"
  local cache_root entry_key entry output_tmp status_tmp
  local output rc waited_tenths wait_limit_tenths

  if [ -z "$session_id" ] || [ -z "$invocation_key" ]; then
    run_with_timeout "$timeout_seconds" "$cmd"
    return $?
  fi

  cache_root="${CLAUDE_STOP_RESULT_DIR:-${CLAUDE_AUTOMATION_STATE_DIR:-$HOME/.claude/stop-test-results}}"
  # Keep the cache entry name below macOS's 255-byte component limit. Four
  # independently formatted SHA-256 values plus separators can exceed that
  # limit, making mkdir fail and incorrectly sending the first caller into the
  # waiter branch for a status file that can never exist.
  entry_key=$(printf '%s\0' "$root" "$session_id" "$invocation_key" "$cmd" "$(repository_content_fingerprint "$root")" |
    shasum -a 256 | awk '{print $1}') || return 125
  entry="$cache_root/$entry_key"

  mkdir -p "$cache_root" || return 125
  if mkdir "$entry" 2>/dev/null; then
    printf '%s\n' "$$" >"$entry/owner" || return 125
    output_tmp="$entry/output.tmp"
    status_tmp="$entry/status.tmp"
    output=$(run_with_timeout "$timeout_seconds" "$cmd" 2>&1)
    rc=$?
    printf '%s' "$output" >"$output_tmp" || return 125
    printf '%s\n' "$rc" >"$status_tmp" || return 125
    mv -f -- "$output_tmp" "$entry/output" || return 125
    mv -f -- "$status_tmp" "$entry/status" || return 125
    printf '%s' "$output"
    return "$rc"
  fi

  if [ ! -d "$entry" ]; then
    printf '[test-runner] BLOCKED: could not create or observe the shared Stop-runner entry; no result was awaited.\n' >&2
    return 125
  fi

  waited_tenths=0
  wait_limit_tenths=$(((timeout_seconds + 5) * 10))
  while [ ! -s "$entry/status" ] && [ "$waited_tenths" -lt "$wait_limit_tenths" ]; do
    sleep 0.1
    waited_tenths=$((waited_tenths + 1))
  done
  if [ -s "$entry/status" ] &&
    rc=$(cat "$entry/status" 2>/dev/null) &&
    printf '%s' "$rc" | grep -qE '^[0-9]+$' &&
    [ -f "$entry/output" ]; then
    cat "$entry/output"
    return "$rc"
  fi

  printf '[test-runner] BLOCKED: shared Stop-runner result was incomplete; no PASS was inferred.\n' >&2
  return 125
}

# Shared entry point for Stop hooks. This is the only function those hooks
# should use for native repository execution: trust first, detection second,
# and atomic result sharing third.
run_trusted_test_once() {
  local root="$1" session_id="$2" invocation_key="$3" timeout_seconds="$4"

  if ! repository_is_trusted "$root"; then
    repository_trust_block "$root"
    return 126
  fi

  TEST_CMD=""
  detect_test_cmd "$root" || true
  if [ -z "${TEST_CMD:-}" ]; then
    printf '[test-runner] BLOCKED: no native test runner was detected for %s; no PASS was inferred.\n' "$root"
    return 127
  fi

  run_shared_test_once "$root" "$session_id" "$invocation_key" "$timeout_seconds" "$TEST_CMD"
}
