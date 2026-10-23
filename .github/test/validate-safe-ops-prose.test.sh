#!/usr/bin/env bash
# Regresion: validate-safe-ops no debe bloquear texto inocuo (prosa en español
# con "su", "env" dentro de un string) y debe seguir bloqueando lo peligroso.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
HOOK="$ROOT/config/claude/hooks/validate-safe-ops.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

hook_output() {
  jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c},cwd:"/tmp",permission_mode:"default"}' |
    bash "$HOOK" 2>/dev/null
}

# El hook calla (exit 0 sin stdout) cuando no tiene objeciones.
decision() {
  local out
  out=$(hook_output "$1")
  [ -n "$out" ] || { printf 'allow'; return 0; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
}

expect_allow() {
  [ "$(decision "$2")" = allow ] || fail "$1 was blocked"
}

expect_deny() {
  [ "$(decision "$2")" = deny ] || fail "$1 was not blocked"
}

printf '%s\n' '== prose and quoted text are not commands =='
expect_allow 'spanish prose starting with su after a semicolon' \
  'echo ok; su persona (verificar antes de dar la razon) quedo integrada'
expect_allow 'heredoc body with su prose' "python3 - <<'PYEOF'
print('runtimes; su persona quedo integrada')
PYEOF"
expect_allow 'env inside a printf string' \
  "printf '#!/usr/bin/env bash\nexit 0\n' > /tmp/stub-brew"

printf '%s\n' '== privileged execution stays blocked =='
expect_deny 'plain sudo' 'sudo rm -rf /tmp/x'
expect_deny 'su with a dash' 'su - root'
expect_deny 'bare su' 'echo hi; su'
expect_deny 'su with user and flag' 'echo hi; su root -c id'
expect_deny 'su inside bash -c' "bash -c 'su - root'"
expect_deny 'sudo inside bash -c' "bash -c 'sudo id'"
expect_deny 'env wrapper with quoted whitespace hiding sudo' "env 'A=1 2' sudo id"
expect_deny 'xargs wrapper with quoted whitespace hiding sudo' "ls | xargs -I 'a b' sudo id"
expect_deny 'mkfs in a nested payload' "bash -c 'mkfs.ext4 /dev/sda'"

printf '%s\n' '== deny messages tell what to do next =='
reason=$(hook_output "env 'A=1 2' sudo id" | jq -r '.hookSpecificOutput.permissionDecisionReason')
case "$reason" in
  *Ambiguous*"Si env/time/xargs"*) ;;
  *) fail "ambiguous-wrapper message has no guidance: $reason" ;;
esac

printf '%s\n' 'PASS: validate-safe-ops allows prose, blocks privileged execution, and explains denials'
