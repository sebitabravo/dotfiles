#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
STATUSLINE="$ROOT/config/claude/statusline.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/config"

render() {
  local model=$1
  jq -nc --arg model "$model" --arg dir "$TMP_ROOT" '
    {
      model: {display_name: $model},
      workspace: {current_dir: $dir},
      cost: {total_lines_added: 1, total_lines_removed: 2},
      context_window: {context_window_size: 200000, used_percentage: 25}
    }
  ' | CLAUDE_CONFIG_DIR="$TMP_ROOT/config" bash "$STATUSLINE"
}

assert_icon() {
  local expected=$1 model=$2 output
  output=$(render "$model")
  [[ "$output" == *"$expected $model"* ]] || {
    printf 'expected icon %s for %s, got: %s\n' "$expected" "$model" "$output" >&2
    return 1
  }
}

assert_icon '🎭' 'Claude Opus 5'
assert_icon '📝' 'Claude Sonnet 5'
assert_icon '🍃' 'Claude Haiku 5'

printf 'statusline tests: PASS\n'
