///|
test "parse_tool_calls with empty content array" {
  let ec = EventCollector::new()
  let s =
    #|{"message": {"content": []}}
  let map = json_map(s)
  @agent.parse_tool_calls(map, ec.handler())
  assert_true(ec.tool_calls.is_empty())
}

///|
test "parse_tool_calls ignores non-object content blocks" {
  let ec = EventCollector::new()
  let s =
    #|{"message": {"content": ["not-an-object", 42]}}
  let map = json_map(s)
  @agent.parse_tool_calls(map, ec.handler())
  assert_true(ec.tool_calls.is_empty())
}

///|
test "parse_tool_result falls back to name when tool_name missing" {
  let ec = EventCollector::new()
  let s =
    #|{"name": "Write", "content": "ok"}
  let map = json_map(s)
  @agent.parse_tool_result(map, ec.handler())
  assert_eq(ec.tool_results.length(), 1)
  inspect(ec.tool_results[0].0, content="Write")
}

///|
test "parse_system_event includes tool count in message" {
  let ec = EventCollector::new()
  let s =
    #|{"subtype": "init", "model": "test-model", "tools": [{"name": "a"}, {"name": "b"}, {"name": "c"}]}
  let map = json_map(s)
  @agent.parse_system_event(map, ec.handler())
  assert_true(ec.infos[0].contains("tools=3"))
}

///|
test "parse_content_block_start ignores unknown block type" {
  let ec = EventCollector::new()
  let s =
    #|{"content_block": {"type": "unknown_type"}}
  let map = json_map(s)
  @agent.parse_content_block_start(map, ec.handler())
  assert_true(ec.infos.is_empty())
}

///|
test "parse_content_block_start ignores non-object content_block" {
  let ec = EventCollector::new()
  let s =
    #|{"content_block": "not-an-object"}
  let map = json_map(s)
  @agent.parse_content_block_start(map, ec.handler())
  assert_true(ec.infos.is_empty())
}
