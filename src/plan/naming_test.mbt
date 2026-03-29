///|
test "generate_run_dir_name handles a simple ascii title" {
  let actual = @plan.generate_run_dir_name("My Cool Plan", "2026-03-24_1430")

  inspect(actual, content=".runs/2026-03-24_1430_my-cool-plan")
}

///|
test "generate_run_dir_name converts underscores to hyphens" {
  let actual = @plan.generate_run_dir_name("step_one_plan", "2026-03-24_1430")

  inspect(actual, content=".runs/2026-03-24_1430_step-one-plan")
}

///|
test "generate_run_dir_name removes special characters and collapses separators" {
  let actual = @plan.generate_run_dir_name(
    "Plan: v2.0 (final!)", "2026-03-24_1430",
  )

  inspect(actual, content=".runs/2026-03-24_1430_plan-v20-final")
}

///|
test "generate_run_dir_name collapses consecutive spaces and hyphens" {
  let actual = @plan.generate_run_dir_name(
    "too   many   spaces", "2026-03-24_1430",
  )

  inspect(actual, content=".runs/2026-03-24_1430_too-many-spaces")
}

///|
test "generate_run_dir_name strips leading and trailing hyphens" {
  let actual = @plan.generate_run_dir_name(" --hello-- ", "2026-03-24_1430")

  inspect(actual, content=".runs/2026-03-24_1430_hello")
}

///|
test "generate_run_dir_name truncates slug to 50 chars without trailing hyphen" {
  let actual = @plan.generate_run_dir_name(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-beyond", "2026-03-24_1430",
  )

  inspect(
    actual,
    content=".runs/2026-03-24_1430_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
}

///|
test "generate_run_dir_name falls back to plan when sanitization removes everything" {
  let actual = @plan.generate_run_dir_name("!!!___---   ???", "2026-03-24_1430")

  inspect(actual, content=".runs/2026-03-24_1430_plan")
}

///|
test "generate_run_dir_name preserves japanese characters alongside ascii" {
  let actual = @plan.generate_run_dir_name(
    "Step 1: 型定義の追加", "2026-03-24_1430",
  )

  inspect(actual, content=".runs/2026-03-24_1430_step-1-型定義の追加")
}

///|
test "generate_run_dir_name lowercases ascii case-insensitively" {
  let actual = @plan.generate_run_dir_name("UPPERCASE TITLE", "2026-03-24_1430")

  inspect(actual, content=".runs/2026-03-24_1430_uppercase-title")
}

///|
test "generate_run_dir_name lowercases boundary char A correctly" {
  let actual = @plan.generate_run_dir_name("A", "ts")

  inspect(actual, content=".runs/ts_a")
}

///|
test "generate_run_dir_name lowercases boundary char Z correctly" {
  let actual = @plan.generate_run_dir_name("Z", "ts")

  inspect(actual, content=".runs/ts_z")
}

///|
test "generate_run_dir_name lowercases full A-Z range" {
  let actual = @plan.generate_run_dir_name("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "ts")

  inspect(actual, content=".runs/ts_abcdefghijklmnopqrstuvwxyz")
}

///|
test "generate_run_dir_name preserves chars just outside A-Z range" {
  // '@' is 0x40 (just before 'A'), '[' is 0x5B (just after 'Z')
  // These should not be lowercased; non-alnum ASCII is stripped by sanitize_title
  let actual = @plan.generate_run_dir_name("a@b[c", "ts")

  inspect(actual, content=".runs/ts_abc")
}
