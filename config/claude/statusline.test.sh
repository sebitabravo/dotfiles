#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STATUSLINE="$ROOT/config/claude/statusline.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/bin" "$TMP_ROOT/config"
cat >"$TMP_ROOT/bin/date" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-u +%H') printf '07\n' ;;
  '+%-H') printf '6\n' ;;
  '+%u') printf '2\n' ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TMP_ROOT/bin/date"

render() {
  local model=$1
  jq -nc --arg model "$model" --arg dir "$TMP_ROOT" '
    {
      model: {display_name: $model},
      workspace: {current_dir: $dir},
      cost: {total_lines_added: 1, total_lines_removed: 2},
      context_window: {context_window_size: 200000, used_percentage: 25}
    }
  ' | PATH="$TMP_ROOT/bin:$PATH" CLAUDE_CONFIG_DIR="$TMP_ROOT/config" bash "$STATUSLINE"
}

assert_icon() {
  local expected=$1 model=$2 output
  output=$(render "$model")
  [[ "$output" == *"$expected $model"* ]] || {
    printf 'expected icon %s for %s, got: %s\n' "$expected" "$model" "$output" >&2
    return 1
  }
}

assert_icon '🎭' 'deepseek-v4-pro[1m]'
assert_icon '🎭' 'glm-5.3[1m]'
assert_icon '🎭' 'kimi-k3[1m]'
assert_icon '🎭' 'minimax-m3:cloud'
assert_icon '🎭' 'qwen3.8-max[1m]'
assert_icon '🎭' 'openai/gpt-5.6-luna-pro'

assert_icon '📝' 'deepseek-v4-flash[1m]'
assert_icon '📝' 'glm-5.2[1m]'
assert_icon '📝' 'kimi-k2.6'
assert_icon '📝' 'gemma4:31b-cloud'
assert_icon '📝' 'openai/gpt-5.6-luna'
assert_icon '📝' 'qwen3.7-max[1m]'

assert_icon '🍃' 'deepseek-v4-flash'
assert_icon '🍃' 'glm-4.7'
assert_icon '🍃' 'kimi-k2.5'
assert_icon '🍃' 'MiniMax-M3'
assert_icon '🍃' 'gpt-oss:120b-cloud'
assert_icon '🍃' 'qwen3.6-flash'
assert_icon '🍃' 'openrouter/free'
assert_icon '🤖' 'MiniMax-M3[1m]'

# A peak warning belongs to the active provider, not merely to the current hour.
glm_output=$(render 'glm-5.3[1m]')
[[ "$glm_output" == *'🔥 3x'* ]]
anthropic_output=$(render 'Claude Sonnet 5')
[[ "$anthropic_output" != *'🔥 3x'* ]]
[[ "$anthropic_output" != *'💸 2x'* ]]
[[ "$anthropic_output" != *'⚠️ 1.2x'* ]]
deepseek_output=$(render 'deepseek-v4-pro[1m]')
[[ "$deepseek_output" == *'💸 2x'* ]]
other_output=$(render 'gemma4:31b-cloud')
[[ "$other_output" != *'🔥 3x'* ]]
[[ "$other_output" != *'💸 2x'* ]]
[[ "$other_output" != *'⚠️ 1.2x'* ]]

printf 'statusline tests: PASS\n'
