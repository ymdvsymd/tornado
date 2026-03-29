///|
test "create_backend Mock/Builder returns default MockBackend" {
  let config : @types.AgentConfig = {
    id: "builder-1",
    kind: Mock,
    role: Builder,
    model: None,
  }
  let backend = @agent.create_backend(config)
  inspect(backend.name(), content="mock")
  let result = backend.run("some task", "", fn(_) {  })
  inspect(result.content, content="mock response")
}

///|
test "create_backend Mock/Review returns default MockBackend" {
  let config : @types.AgentConfig = {
    id: "review-1",
    kind: Mock,
    role: Review,
    model: None,
  }
  let backend = @agent.create_backend(config)
  inspect(backend.name(), content="mock")
  let result = backend.run("some task", "", fn(_) {  })
  inspect(result.content, content="mock response")
}

///|
test "create_backend Mock/Planner returns SequenceMockBackend" {
  let config : @types.AgentConfig = {
    id: "planner-1",
    kind: Mock,
    role: Planner,
    model: None,
  }
  let backend = @agent.create_backend(config)
  inspect(backend.name(), content="sequence-mock")
}

///|
test "create_backend Mock/Verifier returns approved MockBackend" {
  let config : @types.AgentConfig = {
    id: "verifier-1",
    kind: Mock,
    role: Verifier,
    model: None,
  }
  let backend = @agent.create_backend(config)
  inspect(backend.name(), content="mock")
  let result = backend.run("verify", "", fn(_) {  })
  inspect(result.content, content="<approved>")
}

///|
test "create_backends returns map with all agent ids" {
  let agents : Array[@types.AgentConfig] = [
    { id: "b1", kind: Mock, role: Builder, model: None },
    { id: "p1", kind: Mock, role: Planner, model: None },
  ]
  let backends = @agent.create_backends(agents)
  assert_true(backends.contains("b1"), msg="should contain b1")
  assert_true(backends.contains("p1"), msg="should contain p1")
  inspect(backends["b1"].name(), content="mock")
  inspect(backends["p1"].name(), content="sequence-mock")
}
