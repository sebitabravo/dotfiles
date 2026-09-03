#!/usr/bin/env bash
# doctor.sh — auditoría read-only de la configuración efectiva.
#
# No sincroniza, reinicia, instala ni modifica archivos. Comprueba la fuente
# MCP contra los archivos que Claude lee, el estado de Claude/Herdr/Engram,
# permisos sensibles, paridad del runtime y binarios requeridos.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DEFAULT_REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd -P)
REPO_ROOT=${DOCTOR_REPO_ROOT:-$DEFAULT_REPO_ROOT}
ENGRAM_PROJECT=${DOCTOR_ENGRAM_PROJECT:-$(basename "$REPO_ROOT")}
CLAUDE_SOURCE_ROOT=${DOCTOR_CLAUDE_SOURCE_ROOT:-$REPO_ROOT/config/claude}
CLAUDE_RUNTIME_ROOT=${DOCTOR_CLAUDE_RUNTIME_ROOT:-$HOME/.claude}
CLAUDE_USER_CONFIG=${DOCTOR_CLAUDE_USER_CONFIG:-$HOME/.claude.json}
CLAUDE_SETTINGS="$CLAUDE_RUNTIME_ROOT/settings.json"
CLAUDE_MANAGED_MCP=${DOCTOR_CLAUDE_MANAGED_MCP:-$CLAUDE_RUNTIME_ROOT/mcp-servers.json}
HERDR_SOURCE=${DOCTOR_HERDR_SOURCE:-$REPO_ROOT/config/herdr/config.toml}
HERDR_RUNTIME_CONFIG=${DOCTOR_HERDR_RUNTIME_CONFIG:-$HOME/.config/herdr/config.toml}

if [ -z "${DOCTOR_MCP_SOURCE:-}" ]; then
  if [ -f "$REPO_ROOT/config/claude/mcp-servers.json" ]; then
    MCP_SOURCE="$REPO_ROOT/config/claude/mcp-servers.json"
  else
    MCP_SOURCE="$CLAUDE_SOURCE_ROOT/mcp-servers.json"
  fi
else
  MCP_SOURCE=$DOCTOR_MCP_SOURCE
fi

FAILURES=0
MCP_HEALTH_OUTPUT=''

usage() {
  cat <<EOF
Uso: doctor.sh

Audita sin modificar:
  - MCP versionado contra ~/.claude.json y ~/.claude/mcp-servers.json
  - estado de Claude, Herdr y Engram
  - permisos de archivos sensibles
  - paridad del runtime Claude y de los overlays
  - binarios requeridos y salud de servidores MCP

Variables opcionales para fixtures:
  DOCTOR_CLAUDE_SOURCE_ROOT, DOCTOR_REPO_ROOT, DOCTOR_ENGRAM_PROJECT
  DOCTOR_CLAUDE_RUNTIME_ROOT
  DOCTOR_CLAUDE_USER_CONFIG, DOCTOR_CLAUDE_MANAGED_MCP, DOCTOR_MCP_SOURCE
  DOCTOR_HERDR_SOURCE, DOCTOR_HERDR_RUNTIME_CONFIG
EOF
}

case "${1:-}" in
  '') ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf '[doctor] argumento desconocido: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

pass() {
  if [ "$#" -gt 1 ]; then
    printf 'PASS  %s — %s\n' "$1" "$2"
  else
    printf 'PASS  %s\n' "$1"
  fi
}

info() {
  if [ "$#" -gt 1 ]; then
    printf 'INFO  %s — %s\n' "$1" "$2"
  else
    printf 'INFO  %s\n' "$1"
  fi
}

fail() {
  FAILURES=$((FAILURES + 1))
  if [ "$#" -gt 1 ]; then
    printf 'FAIL  %s — %s\n' "$1" "$2" >&2
  else
    printf 'FAIL  %s\n' "$1" >&2
  fi
}

last_line() {
  printf '%s\n' "$1" | tail -n 1
}

check_binary() {
  local binary="$1" path
  path=$(command -v "$binary" 2>/dev/null || true)
  if [ -n "$path" ]; then
    pass "binario $binary" "$path"
  else
    fail "binario $binary" "no está en PATH"
  fi
}

check_command() {
  local label="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    pass "$label" "$(last_line "$output")"
  else
    fail "$label" "exit no cero: $(last_line "$output")"
  fi
}

check_json() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    fail "$label" "falta $path"
  elif jq empty "$path" >/dev/null 2>&1; then
    pass "$label" "$path"
  else
    fail "$label" "JSON inválido: $path"
  fi
}

file_mode() {
  local path="$1" mode
  mode=$(stat -f '%Lp' "$path" 2>/dev/null || true)
  case "$mode" in
    '' | *[!0-9]*) mode='' ;;
  esac
  if [ -z "$mode" ]; then
    mode=$(stat -c '%a' "$path" 2>/dev/null || true)
  fi
  case "$mode" in
    '' | *[!0-9]*) return 1 ;;
    *) printf '%s\n' "$mode" ;;
  esac
}

normalize_mode() {
  local mode
  mode=$(printf '%s' "$1" | sed 's/^0*//')
  [ -n "$mode" ] || mode=0
  while [ "${#mode}" -lt 3 ]; do
    mode="0$mode"
  done
  printf '%s\n' "$mode"
}

check_private_mode() {
  local label="$1" path="$2" expected="$3" mode normalized group other
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    fail "$label" "falta $path"
    return
  fi
  if ! mode=$(file_mode "$path"); then
    fail "$label" "no se pudo leer el modo de $path"
    return
  fi
  normalized=$(normalize_mode "$mode")
  if [ -n "$expected" ] && [ "$normalized" = "$expected" ]; then
    pass "$label" "$path modo $normalized"
    return
  fi
  if [ -n "$expected" ]; then
    fail "$label" "$path tiene modo $normalized; se esperaba $expected"
    return
  fi
  group=${normalized:1:1}
  other=${normalized:2:1}
  case "$group$other" in
    *[2367]*) fail "$label" "$path es escribible por grupo/otros (modo $normalized)" ;;
    *) pass "$label" "$path modo $normalized" ;;
  esac
}

managed_shape() {
  jq -c --arg name "$1" '
    def managed:
      {type: .type, command: .command, args: .args, url: .url}
      | with_entries(select(.value != null));
    .mcpServers[$name] | managed
  ' "$2"
}

compare_mcp_target() {
  local label="$1" target="$2" names name source_shape runtime_shape
  if [ ! -f "$target" ]; then
    fail "$label" "falta $target"
    return
  fi
  if ! jq -e '(.mcpServers | type == "object")' "$target" >/dev/null 2>&1; then
    fail "$label" "$target no tiene un objeto mcpServers válido"
    return
  fi

  names=$(jq -r '.mcpServers | keys[]' "$MCP_SOURCE")
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if ! jq -e --arg name "$name" '.mcpServers[$name] != null' "$target" >/dev/null 2>&1; then
      fail "$label/$name" "servidor ausente en $target"
      continue
    fi
    if ! source_shape=$(managed_shape "$name" "$MCP_SOURCE"); then
      fail "$label/$name" "no se pudo leer la definición versionada"
      continue
    fi
    if ! runtime_shape=$(managed_shape "$name" "$target"); then
      fail "$label/$name" "no se pudo leer la definición runtime"
      continue
    fi
    if [ "$source_shape" = "$runtime_shape" ]; then
      pass "$label/$name" "definición administrada coincide"
    else
      fail "$label/$name" "definición administrada difiere"
    fi
  done <<EOF
$names
EOF
}

check_mcp_health() {
  local output line name
  if ! output=$(claude mcp list 2>&1); then
    fail 'Claude MCP health' "claude mcp list falló: $(last_line "$output")"
    return
  fi
  MCP_HEALTH_OUTPUT=$output
  pass 'Claude MCP health' "claude mcp list respondió"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    line=$(printf '%s\n' "$output" | grep -F "$name:" | head -n 1 || true)
    if [ -n "$line" ] && printf '%s\n' "$line" | grep -F 'Connected' >/dev/null 2>&1; then
      pass "MCP server $name" 'Connected'
    elif [ -n "$line" ]; then
      fail "MCP server $name" "$line"
    else
      fail "MCP server $name" 'no aparece en claude mcp list'
    fi
  done <<EOF
$(jq -r '.mcpServers | keys[]' "$MCP_SOURCE")
EOF
}

check_engram() {
  local health_output health_status health_detail
  if jq -e '.enabledPlugins["engram@engram"] == true' "$CLAUDE_SETTINGS" >/dev/null 2>&1 &&
    printf '%s\n' "$MCP_HEALTH_OUTPUT" | grep -E 'engram.*Connected' >/dev/null 2>&1; then
    pass 'Engram' 'plugin habilitado y conectado'
  elif printf '%s\n' "$MCP_HEALTH_OUTPUT" | grep -E 'engram.*Connected' >/dev/null 2>&1; then
    pass 'Engram' 'ruta MCP conectada'
  else
    fail 'Engram' 'no aparece conectado en Claude'
    return
  fi

  # MCP connectivity does not prove local/cloud-sync health. Engram can return
  # exit 0 while its structured doctor reports a blocked legacy mutation, so
  # inspect JSON status instead of trusting the process code alone.
  if ! health_output=$(engram doctor --json --project "$ENGRAM_PROJECT" 2>&1); then
    fail 'Engram cloud health' "doctor falló: $(last_line "$health_output")"
    return
  fi
  if ! health_status=$(printf '%s' "$health_output" | jq -er '.status | strings' 2>/dev/null); then
    fail 'Engram cloud health' 'doctor no devolvió un JSON con status string'
    return
  fi
  health_detail=$(printf '%s' "$health_output" | jq -r '
    [
      (.checks[]? | select(.result == "blocked" or .severity == "blocking") | .message),
      (.checks[]?.findings[]? | select(.severity == "blocking") | .message)
    ] | map(select(type == "string" and length > 0)) | unique | join("; ")
  ' 2>/dev/null || true)
  case "$health_status" in
    ready | ok | healthy | complete)
      pass 'Engram cloud health' "status: $health_status"
      ;;
    disabled | unconfigured | not_enrolled | opted_out)
      info 'Engram cloud health' "status: $health_status (cloud opt-in not active)"
      ;;
    blocked | degraded | error)
      if [ -n "$health_detail" ]; then
        fail 'Engram cloud health' "status: $health_status — $health_detail"
      else
        fail 'Engram cloud health' "status: $health_status"
      fi
      ;;
    *)
      fail 'Engram cloud health' "status desconocido: ${health_status:-missing}"
      ;;
  esac
}

run_parity() {
  local label="$1" script_name="$2" script output
  if [ -f "$CLAUDE_SOURCE_ROOT/scripts/$script_name" ]; then
    script="$CLAUDE_SOURCE_ROOT/scripts/$script_name"
  elif [ -f "$REPO_ROOT/.github/test/$script_name" ]; then
    # Durante la migración de suites, estos helpers pueden vivir fuera de
    # config/claude/scripts. El doctor los usa sólo como auditores read-only.
    script="$REPO_ROOT/.github/test/$script_name"
  elif [ -f "$CLAUDE_RUNTIME_ROOT/scripts/$script_name" ]; then
    script="$CLAUDE_RUNTIME_ROOT/scripts/$script_name"
  else
    fail "$label" "no se encontró $script_name"
    return
  fi

  if output=$(CLAUDE_SOURCE_DIR="$CLAUDE_SOURCE_ROOT" \
    CLAUDE_RUNTIME_DIR="$CLAUDE_RUNTIME_ROOT" bash "$script" --strict 2>&1); then
    pass "$label" "$(last_line "$output")"
  else
    fail "$label" "$(last_line "$output")"
  fi
}

printf 'Sebita Dotfiles doctor (read-only)\n'
printf 'source: %s\nruntime: %s\n\n' "$CLAUDE_SOURCE_ROOT" "$CLAUDE_RUNTIME_ROOT"

for binary in bash jq rsync git claude herdr engram codegraph npx; do
  check_binary "$binary"
done

check_command 'Claude version' claude --version
check_command 'Herdr version' herdr --version
check_command 'Engram version' engram --version
check_command 'CodeGraph version' codegraph --version

if [ ! -d "$CLAUDE_RUNTIME_ROOT" ]; then
  fail 'Claude runtime' "falta $CLAUDE_RUNTIME_ROOT"
fi
check_json 'Claude user config' "$CLAUDE_USER_CONFIG"
check_json 'Claude settings' "$CLAUDE_SETTINGS"
check_json 'MCP fuente' "$MCP_SOURCE"
check_json 'MCP runtime administrado' "$CLAUDE_MANAGED_MCP"

if jq -e '(.mcpServers | type == "object" and length > 0)' "$MCP_SOURCE" >/dev/null 2>&1; then
  if jq -e '(.mcpServers | type == "object")' "$CLAUDE_USER_CONFIG" >/dev/null 2>&1; then
    compare_mcp_target 'MCP fuente vs ~/.claude.json' "$CLAUDE_USER_CONFIG"
  else
    fail 'MCP fuente vs ~/.claude.json' 'el runtime no tiene un objeto mcpServers válido'
  fi
  if jq -e '(.mcpServers | type == "object")' "$CLAUDE_MANAGED_MCP" >/dev/null 2>&1; then
    compare_mcp_target 'MCP fuente vs ~/.claude/mcp-servers.json' "$CLAUDE_MANAGED_MCP"
  fi
else
  fail 'MCP manifest' 'la fuente no declara servidores MCP'
fi

check_private_mode 'Permiso ~/.claude.json' "$CLAUDE_USER_CONFIG" 600
check_private_mode 'Permiso settings.json' "$CLAUDE_SETTINGS" ''
check_private_mode 'Permiso mcp-servers.json' "$CLAUDE_MANAGED_MCP" ''

if [ -f "$HERDR_SOURCE" ]; then
  if [ -f "$HERDR_RUNTIME_CONFIG" ] && cmp -s "$HERDR_SOURCE" "$HERDR_RUNTIME_CONFIG"; then
    pass 'Herdr config parity' 'runtime coincide exactamente con la fuente'
  elif [ -f "$HERDR_RUNTIME_CONFIG" ]; then
    fail 'Herdr config parity' 'runtime difiere de la fuente'
  else
    fail 'Herdr config parity' "falta $HERDR_RUNTIME_CONFIG"
  fi
else
  info 'Herdr config parity' 'fuente no disponible fuera del repositorio'
fi

if [ -f "$HERDR_RUNTIME_CONFIG" ]; then
  if output=$(HERDR_CONFIG_PATH="$HERDR_RUNTIME_CONFIG" herdr config check 2>&1); then
    pass 'Herdr config check' "$(last_line "$output")"
  else
    fail 'Herdr config check' "$(last_line "$output")"
  fi
else
  fail 'Herdr config check' "falta $HERDR_RUNTIME_CONFIG"
fi
check_command 'Herdr server status' herdr status

check_mcp_health
check_engram
run_parity 'Claude harness parity' check-runtime-parity.sh
run_parity 'Claude provider parity' check-provider-runtime-parity.sh

if [ "$FAILURES" -eq 0 ]; then
  printf '\nDOCTOR PASS: todas las comprobaciones read-only pasaron.\n'
  exit 0
fi

printf '\nDOCTOR FAIL: %s comprobación(es) fallaron; no se modificó ningún archivo.\n' "$FAILURES" >&2
exit 1
