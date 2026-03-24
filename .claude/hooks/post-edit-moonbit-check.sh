#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook: type-check .mbt files after Edit/Write
# Reads tool invocation JSON from stdin, runs moon check --target js for type checking.
# Mirrors quality-gate.sh pattern but for MoonBit instead of TypeScript.

# Read the full stdin JSON
input="$(cat)"

# Extract file path from tool_input.file_path or tool_input.path
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

# If no file path found, exit silently
if [[ -z "${file_path:-}" ]]; then
  exit 0
fi

# Only act on .mbt files
case "$file_path" in
  *.mbt)
    ;;
  *)
    exit 0
    ;;
esac

# Check if the file actually exists
if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Check if moon is available
if ! command -v moon &>/dev/null; then
  exit 0
fi

# Find the project root (where moon.mod.json lives)
project_root="$(cd "$(dirname "$file_path")" && git rev-parse --show-toplevel 2>/dev/null || echo "")"

if [[ -z "$project_root" ]] || [[ ! -f "$project_root/moon.mod.json" ]]; then
  exit 0
fi

# Run moon check --target js for type checking
check_output=""
if ! check_output="$(cd "$project_root" && moon check --target js 2>&1)"; then
  jq -n --arg msg "moon check errors:\n$check_output" \
    '{"hookSpecificOutput": {"additionalContext": $msg}}'
fi

exit 0
