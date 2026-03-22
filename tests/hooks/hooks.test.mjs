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
