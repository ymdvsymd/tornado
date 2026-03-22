///|
fn file_exists_mock(path : String) -> Bool {
  path == "plan.md" || path == "tasks.txt"
}

///|
test "parse_cli_args flags only" {
  let args = ["tornado", "--dev=codex", "--review=claude"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(
      config_path=config,
      log_path=_,
      dev_kind=dev,
      review_kind=review,
      lang~,
      warnings~
    ) => {
      inspect(config, content="None")
      inspect(dev, content="Some(Codex)")
      inspect(review, content="Some(ClaudeCode)")
      inspect(lang, content="None")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args supports --config=value" {
  let args = ["tornado", "--config=config.json", "--review=codex"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(
      config_path=config,
      log_path=_,
      dev_kind=dev,
      review_kind=review,
      lang=_,
      warnings~
    ) => {
      inspect(config, content="Some(\"config.json\")")
      inspect(dev, content="None")
      inspect(review, content="Some(Codex)")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args supports --config <value>" {
  let args = ["tornado", "--config", "config.json", "--review=codex"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(
      config_path=config,
      log_path=_,
      dev_kind=dev,
      review_kind=review,
      lang=_,
      warnings~
    ) => {
      inspect(config, content="Some(\"config.json\")")
      inspect(dev, content="None")
      inspect(review, content="Some(Codex)")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args validate command" {
  let args = ["tornado", "validate", "config.json"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Validate(path) => inspect(path, content="Some(\"config.json\")")
    _ => panic()
  }
}

///|
test "parse_cli_args version command" {
  let args = ["tornado", "version"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Version => ()
    _ => panic()
  }
}

///|
test "parse_cli_args --version flag" {
  let args = ["tornado", "--version"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Version => ()
    _ => panic()
  }
}

///|
test "parse_cli_args -v flag" {
  let args = ["tornado", "-v"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Version => ()
    _ => panic()
  }
}

///|
test "parse_cli_args --log=path" {
  let args = ["tornado", "--log=/tmp/tornado.log"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(log_path~, ..) =>
      inspect(log_path, content="Some(\"/tmp/tornado.log\")")
    _ => panic()
  }
}

///|
test "parse_cli_args --log path" {
  let args = ["tornado", "--log", "/tmp/tornado.log"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(log_path~, ..) =>
      inspect(log_path, content="Some(\"/tmp/tornado.log\")")
    _ => panic()
  }
}

///|
test "parse_cli_args --log missing value warns" {
  let args = ["tornado", "--log"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(log_path~, warnings~, ..) => {
      inspect(log_path, content="None")
      assert_true(warnings.length() == 1)
      assert_true(warnings[0].contains("Missing value for --log"))
    }
    _ => panic()
  }
}

///|
test "parse_cli_args positional argument warns" {
  let args = ["tornado", "config.json"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(config_path=config, warnings~, ..) => {
      inspect(config, content="None")
      assert_true(warnings.length() == 1)
      assert_true(warnings[0].contains("Unexpected argument"))
    }
    _ => panic()
  }
}

///|
test "parse_cli_args legacy flags silently ignored" {
  let args = [
    "tornado", "--ralph", "--rlm", "--review-interval=3", "--dev=codex",
  ]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(dev_kind=dev, warnings~, ..) => {
      inspect(dev, content="Some(Codex)")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args --lang=ja" {
  let args = ["tornado", "--lang=ja", "--dev=codex"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(dev_kind=dev, lang~, warnings~, ..) => {
      inspect(dev, content="Some(Codex)")
      inspect(lang, content="Some(\"ja\")")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args --lang=en" {
  let args = ["tornado", "--lang=en"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(lang~, warnings~, ..) => {
      inspect(lang, content="Some(\"en\")")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args --lang=auto" {
  let args = ["tornado", "--lang=auto"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(lang~, warnings~, ..) => {
      inspect(lang, content="Some(\"auto\")")
      assert_true(warnings.is_empty())
    }
    _ => panic()
  }
}

///|
test "parse_cli_args --lang=invalid warns" {
  let args = ["tornado", "--lang=fr"]
  let parsed = @cli.parse_cli_args(args, file_exists_mock)
  match parsed {
    Run(lang~, warnings~, ..) => {
      inspect(lang, content="None")
      assert_true(warnings.length() == 1)
      assert_true(warnings[0].contains("Unknown --lang"))
    }
    _ => panic()
  }
}

///|
test "apply_overrides rewrites role kinds" {
  let base = @config.ProjectConfig::preset_default()
  let updated = @cli.apply_overrides(
    base,
    dev_kind=Some(@types.AgentKind::Codex),
    review_kind=Some(@types.AgentKind::ClaudeCode),
  )

  assert_true(updated.agents.length() == 2)
  inspect(updated.agents[0].role, content="Builder")
  inspect(updated.agents[0].kind, content="Codex")
  inspect(updated.agents[1].role, content="Review")
  inspect(updated.agents[1].kind, content="ClaudeCode")
}

///|
test "apply_overrides overrides review_interval" {
  let base = @config.ProjectConfig::preset_default()
  inspect(base.review_interval, content="1")
  let updated = @cli.apply_overrides(base, review_interval=Some(3))
  inspect(updated.review_interval, content="3")
}

///|
test "apply_overrides keeps review_interval when not overridden" {
  let base = @config.ProjectConfig::preset_default()
  let updated = @cli.apply_overrides(base)
  inspect(updated.review_interval, content="1")
}
