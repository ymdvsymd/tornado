#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-mock}"   # "mock", "live", "mock-flags", "live-flags"
shift || true
EXTRA_ARGS=("$@")

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$MODE" in
  mock|mock-flags)
    PLANNER_KIND="mock"
    BUILDER_KIND="mock"
    VERIFIER_KIND="mock"
    BRIEF='Fix bugs and add tests'
    ;;
  live|live-flags)
    PLANNER_KIND="claude-code"
    BUILDER_KIND="codex"
    VERIFIER_KIND="claude-code"
    ;;
  *)
    echo "Usage: $0 [mock|live|mock-flags|live-flags]" >&2
    exit 1
    ;;
esac

has_arg_prefix() {
  local prefix="$1"
  local arg
  for arg in "${EXTRA_ARGS[@]}"; do
    if [[ "$arg" == "$prefix"* ]]; then
      return 0
    fi
  done
  return 1
}

has_arg_exact() {
  local expected="$1"
  local arg
  for arg in "${EXTRA_ARGS[@]}"; do
    if [[ "$arg" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

build_live_brief() {
  local plan_file="$1"
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const text = fs.readFileSync(path, "utf8");
    const lines = text.split(/\r?\n/);
    let section = "";
    const parts = [];
    for (const line of lines) {
      if (/^##\s+/.test(line)) {
        section = line.replace(/^##\s+/, "").trim().toLowerCase();
        continue;
      }
      if (!line.trim()) continue;
      if (section === "goals" || section === "constraints") {
        parts.push(line.replace(/^[-*]\s*/, "").trim());
      }
    }
    process.stdout.write(parts.join("\n"));
  ' "$plan_file"
}

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
  } >bin/whirlwind.js
  chmod +x bin/whirlwind.js
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
LOG_FILE="$TMP_DIR/whirlwind.log"
OUTPUT_FILE="$TMP_DIR/whirlwind.stdout.log"

# Initialize git repo in temp dir (required by Codex SDK for file operations)
git init -q "$TMP_DIR"

if [ "$MODE" = "live" ] || [ "$MODE" = "live-flags" ]; then
  cat >"$TMP_DIR/plan.md" <<'EOF'
# Ralph e2e plan

## Goals
- Create a minimal Node.js hello-world project with one source file and one test file

## Constraints
- Do not install any npm packages
EOF
  BRIEF="$(build_live_brief "$TMP_DIR/plan.md")"
fi

# Config file is only needed for config-based modes (mock, live)
if [ "$MODE" = "mock" ] || [ "$MODE" = "live" ]; then
  cat >"$TMP_DIR/whirlwind.json" <<EOF
{
  "max_review_cycles": 3,
  "review_interval": 1,
  "milestones_path": "milestones.json",
  "max_rework_attempts": 2,
  "agents": [
    {
      "id": "planner",
      "kind": "$PLANNER_KIND",
      "role": "planner"
    },
    {
      "id": "builder",
      "kind": "$BUILDER_KIND",
      "role": "builder"
    },
    {
      "id": "verifier",
      "kind": "$VERIFIER_KIND",
      "role": "verifier"
    }
  ]
}
EOF
fi

if [ "$MODE" = "mock" ]; then
  cat >"$TMP_DIR/plan.md" <<'EOF'
# Dry Run Plan

## Context
This is brief context for the dry-run e2e test.

## Step 1
Implement the CLI flow for --plan and verify milestone generation.
EOF
else
  if ! has_arg_prefix "--plan="; then
    cat >"$TMP_DIR/milestones.json" <<EOF
{
  "brief": $(node -p 'JSON.stringify(process.argv[1])' "$BRIEF"),
  "milestones": [
    {
      "id": "m1",
      "goal": "Create src/hello.js exporting greet(name) that returns 'Hello, <name>!' and create tests/hello.test.js using Node assert to verify greet('World') === 'Hello, World!'",
      "status": "pending",
      "summary": "",
      "tasks": []
    },
    {
      "id": "m2",
      "goal": "Run 'node tests/hello.test.js' and verify it exits with code 0 with no assertion errors",
      "status": "pending",
      "summary": "",
      "tasks": []
    }
  ]
}
EOF
  fi
fi

cd "$TMP_DIR"
# Unset CLAUDECODE to allow Claude Agent SDK to spawn Claude Code subprocesses
# (prevents "nested session" error when running inside a Claude Code session)
unset CLAUDECODE
set +e
case "$MODE" in
  mock)
    node "$ROOT_DIR/bin/whirlwind.js" --plan="$TMP_DIR/plan.md" --dry-run --planner="$PLANNER_KIND" --builder="$BUILDER_KIND" --verifier="$VERIFIER_KIND" --log="$LOG_FILE" 2>&1 | tee "$OUTPUT_FILE"
    CMD_STATUS=${PIPESTATUS[0]}
    ;;
  live)
    if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
      node "$ROOT_DIR/bin/whirlwind.js" --planner="$PLANNER_KIND" --builder="$BUILDER_KIND" --verifier="$VERIFIER_KIND" --log="$LOG_FILE" "${EXTRA_ARGS[@]}" 2>&1 | tee "$OUTPUT_FILE"
    else
      node "$ROOT_DIR/bin/whirlwind.js" --config=whirlwind.json --log="$LOG_FILE" 2>&1 | tee "$OUTPUT_FILE"
    fi
    CMD_STATUS=${PIPESTATUS[0]}
    ;;
  mock-flags|live-flags)
    node "$ROOT_DIR/bin/whirlwind.js" --planner="$PLANNER_KIND" --builder="$BUILDER_KIND" --verifier="$VERIFIER_KIND" --milestones=milestones.json --log="$LOG_FILE" 2>&1 | tee "$OUTPUT_FILE"
    CMD_STATUS=${PIPESTATUS[0]}
    ;;
esac
set -e

OUTPUT="$(cat "$OUTPUT_FILE")"
LIVE_PLAN_DRY_RUN=false
if [ "$MODE" = "live" ] && has_arg_prefix "--plan=" && has_arg_exact "--dry-run"; then
  LIVE_PLAN_DRY_RUN=true
fi

if [ "$CMD_STATUS" -ne 0 ]; then
  echo "FAIL: whirlwind exited with code $CMD_STATUS" >&2
  exit "$CMD_STATUS"
fi

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

assert_milestone_summary_non_empty() {
  local file="$1"
  local milestone_id="$2"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const milestoneId = process.argv[2];
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    const milestone = (data.milestones || []).find((m) => m.id === milestoneId);
    if (!milestone) {
      console.error(`FAIL: milestone not found: ${milestoneId}`);
      process.exit(1);
    }
    if (typeof milestone.summary !== "string" || milestone.summary.trim() === "") {
      console.error(`FAIL: expected non-empty summary for ${milestoneId}`);
      process.exit(1);
    }
  ' "$file" "$milestone_id"
}

assert_pending_milestone_exists() {
  local file="$1"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    if (typeof data.brief !== "string" || data.brief.trim() === "") {
      console.error("FAIL: expected non-empty brief");
      process.exit(1);
    }
    if (!Array.isArray(data.milestones) || data.milestones.length === 0) {
      console.error("FAIL: expected at least one milestone");
      process.exit(1);
    }
    if (!data.milestones.some((m) => m && m.status === "pending")) {
      console.error("FAIL: expected at least one pending milestone");
      process.exit(1);
    }
  ' "$file"
}

if [ "$MODE" = "mock" ] || [ "$LIVE_PLAN_DRY_RUN" = true ]; then
  RUN_MILESTONES="$(find "$TMP_DIR/.runs" -name milestones.json -print -quit 2>/dev/null || true)"
  if [ -z "$RUN_MILESTONES" ]; then
    echo "FAIL: expected generated milestones.json under $TMP_DIR/.runs" >&2
    exit 1
  fi
  assert_pending_milestone_exists "$RUN_MILESTONES"
else
  assert_contains "Milestone m1 complete"
  assert_contains "Milestone m2 complete"
  assert_contains "Milestones saved to milestones.json"
  assert_milestone_summary_non_empty "$TMP_DIR/milestones.json" "m1"
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "FAIL: expected log file to exist: $LOG_FILE" >&2
  exit 1
fi

if grep -P '\x1b\[' "$LOG_FILE" 2>/dev/null; then
  echo "FAIL: log file contains ANSI escape codes" >&2
  exit 1
fi

if [ "$MODE" = "mock" ] || [ "$LIVE_PLAN_DRY_RUN" = true ]; then
  assert_file_contains "$LOG_FILE" "Generated milestones at .runs/"
  assert_contains "Dry-run complete"
else
  assert_file_contains "$LOG_FILE" "Milestone m1 complete"
  assert_file_contains "$LOG_FILE" "Milestone m2 complete"
fi

if { [ "$MODE" = "live" ] || [ "$MODE" = "live-flags" ]; } && [ "$LIVE_PLAN_DRY_RUN" != true ]; then
  assert_contains "SCOPE:"
  assert_file_contains "$LOG_FILE" "SCOPE:"
fi

echo "PASS: All e2e assertions passed ($MODE)"
