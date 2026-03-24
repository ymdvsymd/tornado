///|
test "build_classification_prompt with a single section includes prompt structure and numbered section" {
  let prompt = @plan.build_classification_prompt([
    { heading: "Context", body: "Background details" },
  ])

  inspect(
    prompt,
    content="Classify each section as \"info\" (background context) or \"milestone\" (implementation step).\n\nSections:\n1. \"Context\" -- Background details\n\nOutput (one per line):\n1: info\n",
  )
}

///|
test "build_classification_prompt with multiple sections numbers every section" {
  let prompt = @plan.build_classification_prompt([
    { heading: "Context", body: "Background details" },
    { heading: "Implementation", body: "Add parser support" },
    { heading: "Verification", body: "Run the plan flow" },
  ])

  inspect(
    prompt,
    content="Classify each section as \"info\" (background context) or \"milestone\" (implementation step).\n\nSections:\n1. \"Context\" -- Background details\n2. \"Implementation\" -- Add parser support\n3. \"Verification\" -- Run the plan flow\n\nOutput (one per line):\n1: info\n2: milestone\n3: info\n",
  )
}

///|
test "build_classification_prompt truncates section body to 100 chars" {
  let long_body = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzXYZ   "
  let prompt = @plan.build_classification_prompt([
    { heading: "Implementation", body: long_body },
  ])

  inspect(
    prompt,
    content="Classify each section as \"info\" (background context) or \"milestone\" (implementation step).\n\nSections:\n1. \"Implementation\" -- abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuv\n\nOutput (one per line):\n1: info\n",
  )
}

///|
test "build_classification_prompt handles an empty body gracefully" {
  let prompt = @plan.build_classification_prompt([
    { heading: "Context", body: "" },
  ])

  inspect(
    prompt,
    content="Classify each section as \"info\" (background context) or \"milestone\" (implementation step).\n\nSections:\n1. \"Context\" -- \n\nOutput (one per line):\n1: info\n",
  )
}

///|
test "parse_classification_response parses well formed output" {
  let classes = @plan.parse_classification_response("1: info\n2: milestone", 2)

  inspect(classes, content="[Info, Milestone]")
}

///|
test "parse_classification_response defaults missing lines to milestone" {
  let classes = @plan.parse_classification_response("1: info", 2)

  inspect(classes, content="[Info, Milestone]")
}

///|
test "parse_classification_response defaults malformed lines to milestone" {
  let classes = @plan.parse_classification_response("1: unknown", 1)

  inspect(classes, content="[Milestone]")
}

///|
test "parse_classification_response defaults empty output to milestone" {
  let classes = @plan.parse_classification_response("", 2)

  inspect(classes, content="[Milestone, Milestone]")
}

///|
test "parse_classification_response tolerates extra whitespace and trailing newlines" {
  let classes = @plan.parse_classification_response(
    "1: info\n2: milestone\n\n", 2,
  )

  inspect(classes, content="[Info, Milestone]")
}
