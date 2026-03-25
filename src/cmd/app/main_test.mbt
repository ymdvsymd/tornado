///|
fn make_plan_test_config() -> @config.ProjectConfig {
  {
    agents: [
      { id: "planner", kind: Mock, role: Planner, model: None },
      { id: "builder", kind: Mock, role: Builder, model: None },
      { id: "verifier", kind: Mock, role: Verifier, model: None },
    ],
    parse_warnings: [],
    milestones_path: None,
    max_rework_attempts: 3,
  }
}

///|
fn with_log_capture(path : String, f : () -> Unit) -> String {
  mkdir_p_sync(".tmp/cmd-app-tests")
  write_file_sync(path, "")
  set_log_file(path)
  f()
  set_log_file("")
  read_file_sync(path)
}

///|
test "load_milestones_from_plan without planner backend warns and defaults uncertain sections to milestones" {
  let log_path = ".tmp/cmd-app-tests/uncertain-no-planner.log"
  let plan_content = "# Sample Plan\n## なぜこの変更が必要か\n背景を整理する\n"

  let config : @config.ProjectConfig = {
    agents: [
      { id: "builder", kind: Mock, role: Builder, model: None },
      { id: "verifier", kind: Mock, role: Verifier, model: None },
    ],
    parse_warnings: [],
    milestones_path: None,
    max_rework_attempts: 3,
  }
  let backends : Map[String, @agent.BoxedBackend] = {}
  backends["builder"] = @agent.MockBackend::new().boxed()
  backends["verifier"] = @agent.MockBackend::new().boxed()

  let mut mgr = @ralph.MilestoneManager::new()
  let logs = with_log_capture(log_path, fn() {
    let loaded = @app.classify_plan_document_for_test(
      plan_content, config, backends,
    )
    mgr = loaded
  })

  assert_true(
    logs.contains(
      "1 sections classified with low confidence (defaulting to milestone)",
    ),
  )
  inspect(mgr.brief, content="")
  inspect(mgr.milestones.length(), content="1")
  inspect(
    mgr.milestones[0].goal,
    content="なぜこの変更が必要か\n\n背景を整理する",
  )
}

///|
test "load_milestones_from_plan with explicit planner classification resolves uncertain sections via llm result" {
  let log_path = ".tmp/cmd-app-tests/uncertain-with-planner.log"
  let plan_content = "# Sample Plan\n## なぜこの変更が必要か\n背景を整理する\n## 変更一覧\nCLI を更新する\n"

  let config = make_plan_test_config()
  let planner_mock = @agent.MockBackend::new(
    default_response="1: info\n2: milestone",
  )
  let backends : Map[String, @agent.BoxedBackend] = {}
  backends["planner"] = planner_mock.boxed()
  backends["builder"] = @agent.MockBackend::new().boxed()
  backends["verifier"] = @agent.MockBackend::new().boxed()

  let mut mgr = @ralph.MilestoneManager::new()
  ignore(
    with_log_capture(log_path, fn() {
      let loaded = @app.classify_plan_document_for_test(
        plan_content, config, backends,
      )
      mgr = loaded
    }),
  )

  let history = planner_mock.get_history()
  inspect(history.length(), content="1")
  let (prompt, _) = history[0]
  assert_true(prompt.contains("Classify each section as \"info\""))
  assert_true(
    prompt.contains(
      "1. \"なぜこの変更が必要か\" -- 背景を整理する",
    ),
  )
  assert_true(prompt.contains("2. \"変更一覧\" -- CLI を更新する"))
  inspect(
    mgr.brief,
    content="## なぜこの変更が必要か\n背景を整理する",
  )
  inspect(mgr.milestones.length(), content="1")
  inspect(mgr.milestones[0].goal, content="変更一覧\n\nCLI を更新する")
}

///|
test "whirlwind-532: planner in config triggers LLM classification without explicit allow_llm_classification flag" {
  let log_path = ".tmp/cmd-app-tests/uncertain-config-planner.log"
  let plan_content = "# Sample Plan\n## なぜこの変更が必要か\n背景を整理する\n## 変更一覧\nCLI を更新する\n"

  let config = make_plan_test_config()
  let planner_mock = @agent.MockBackend::new(
    default_response="1: info\n2: milestone",
  )
  let backends : Map[String, @agent.BoxedBackend] = {}
  backends["planner"] = planner_mock.boxed()
  backends["builder"] = @agent.MockBackend::new().boxed()
  backends["verifier"] = @agent.MockBackend::new().boxed()

  let mut mgr = @ralph.MilestoneManager::new()
  ignore(
    with_log_capture(log_path, fn() {
      // Do NOT pass allow_llm_classification — simulates --planner= not given on CLI
      let loaded = @app.classify_plan_document_for_test(
        plan_content, config, backends,
      )
      mgr = loaded
    }),
  )

  // The planner backend should have been invoked even without the explicit flag
  let history = planner_mock.get_history()
  inspect(history.length(), content="1")
  // info section should be in brief, milestone section should be a milestone
  inspect(
    mgr.brief,
    content="## なぜこの変更が必要か\n背景を整理する",
  )
  inspect(mgr.milestones.length(), content="1")
  inspect(mgr.milestones[0].goal, content="変更一覧\n\nCLI を更新する")
}
