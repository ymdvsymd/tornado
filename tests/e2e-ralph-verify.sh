#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
if command -v just >/dev/null 2>&1; then
  just pack >/dev/null
else
  npm run -s build:sdk >/dev/null
  moon build --target js src/cmd/app >/dev/null
  mkdir -p bin
  {
    echo '#!/usr/bin/env node'
    cat _build/js/debug/build/cmd/app/app.js
  } >bin/tornado.js
  chmod +x bin/tornado.js
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="$TMP_DIR/tornado.log"

cat >"$TMP_DIR/tornado.json" <<'EOF'
{
  "project_dir": ".",
  "review_dir": "docs/reviews",
  "max_review_cycles": 3,
  "review_interval": 1,
  "ralph_enabled": true,
  "milestones_path": "milestones.json",
  "max_rework_attempts": 3,
  "agents": [
    {
      "id": "planner",
      "kind": "mock",
      "role": "planner",
      "working_dir": ".",
      "max_iterations": 10
    },
    {
      "id": "builder",
      "kind": "mock",
      "role": "builder",
      "working_dir": ".",
      "max_iterations": 10
    },
    {
      "id": "verifier",
      "kind": "mock",
      "role": "verifier",
      "working_dir": ".",
      "max_iterations": 10
    }
  ]
}
EOF

cat >"$TMP_DIR/milestones.json" <<'EOF'
{
  "milestones": [
    {
      "id": "m1",
      "goal": "Build auth",
      "status": "pending",
      "tasks": [
        {
          "id": "m1-t1",
          "description": "Implement login flow",
          "wave": 0,
          "status": "pending"
        }
      ]
    }
  ]
}
EOF

cd "$TMP_DIR"
OUTPUT="$(node "$ROOT_DIR/bin/tornado.js" --ralph --config=tornado.json --log="$LOG_FILE" 2>&1)"

printf '%s\n' "$OUTPUT"

assert_contains() {
  local needle="$1"
  if ! printf '%s\n' "$OUTPUT" | grep -Fq "$needle"; then
    echo "FAIL: expected output to contain: $needle" >&2
    exit 1
  fi
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "FAIL: expected $file to contain: $needle" >&2
    exit 1
  fi
}

assert_contains "Verifying perspective: CodeQuality"
assert_contains "Verifying perspective: Performance"
assert_contains "Verifying perspective: Security"
assert_contains "Verifying perspective: GoalAlignment"
assert_contains "Wave 0 approved"
assert_contains "Milestone m1 complete"
assert_contains "Milestones saved to milestones.json"

assert_file_contains "$TMP_DIR/milestones.json" '"status":"done"'
assert_file_contains "$TMP_DIR/milestones.json" '"result":"mock response"'

# Log file assertions
if [ ! -f "$LOG_FILE" ]; then
  echo "FAIL: expected log file to exist: $LOG_FILE" >&2
  exit 1
fi

if grep -P '\x1b\[' "$LOG_FILE" 2>/dev/null; then
  echo "FAIL: log file contains ANSI escape codes" >&2
  exit 1
fi

assert_file_contains "$LOG_FILE" "Milestone m1 complete"
assert_file_contains "$LOG_FILE" "Milestones saved to milestones.json"

echo "PASS: All e2e assertions passed"
