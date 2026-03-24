import { execSync } from "child_process";
import { test } from "node:test";
import assert from "node:assert";

// Test that hook scripts exist and are executable
test("post-edit-format.sh exists and is executable", () => {
  const result = execSync(
    "test -x .claude/hooks/post-edit-format.sh && echo ok",
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "ok");
});

test("quality-gate.sh exists and is executable", () => {
  const result = execSync("test -x .claude/hooks/quality-gate.sh && echo ok", {
    encoding: "utf8",
  });
  assert.strictEqual(result.trim(), "ok");
});

test("check-console-log.sh exists and is executable", () => {
  const result = execSync(
    "test -x .claude/hooks/check-console-log.sh && echo ok",
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "ok");
});

test("test-enforcement.sh exists and is executable", () => {
  const result = execSync(
    "test -x .claude/hooks/test-enforcement.sh && echo ok",
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "ok");
});

// Test that hooks handle empty input gracefully
test("post-edit-format.sh exits 0 on empty JSON", () => {
  const result = execSync(
    'echo "{}" | bash .claude/hooks/post-edit-format.sh; echo $?',
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "0");
});

test("check-console-log.sh exits 0 with no modified files", () => {
  const result = execSync(
    'echo "{}" | bash .claude/hooks/check-console-log.sh; echo $?',
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "0");
});

// whirlwind-3py: PostToolUse hook for moon check on .mbt files
test("whirlwind-3py: post-edit-moonbit-check.sh exists and is executable", () => {
  const result = execSync(
    "test -x .claude/hooks/post-edit-moonbit-check.sh && echo ok",
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "ok");
});

test("whirlwind-3py: post-edit-moonbit-check.sh exits 0 on empty JSON", () => {
  const result = execSync(
    'echo "{}" | bash .claude/hooks/post-edit-moonbit-check.sh; echo $?',
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "0");
});

test("whirlwind-3py: post-edit-moonbit-check.sh exits 0 on non-.mbt file", () => {
  const result = execSync(
    'echo \'{"tool_input":{"file_path":"foo.ts"}}\' | bash .claude/hooks/post-edit-moonbit-check.sh; echo $?',
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "0");
});

test("whirlwind-3py: post-edit-moonbit-check.sh exits 0 for nonexistent .mbt file", () => {
  const result = execSync(
    'echo \'{"tool_input":{"file_path":"/nonexistent/path/foo.mbt"}}\' | bash .claude/hooks/post-edit-moonbit-check.sh; echo $?',
    { encoding: "utf8" },
  );
  assert.strictEqual(result.trim(), "0");
});

test("whirlwind-3py: post-edit-moonbit-check.sh runs moon check on valid .mbt file", () => {
  // Use an actual .mbt file in the project; moon check should pass on clean code
  const result = execSync(
    'echo \'{"tool_input":{"file_path":"src/agent/agent.mbt"}}\' | bash .claude/hooks/post-edit-moonbit-check.sh; echo $?',
    { encoding: "utf8" },
  );
  // Should exit 0 (no type errors in the current codebase)
  assert.strictEqual(result.trim(), "0");
});
