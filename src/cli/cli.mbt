///|
pub(all) enum CliCommand {
  Run(
    config_path~ : String?,
    planner_kind~ : @types.AgentKind?,
    builder_kind~ : @types.AgentKind?,
    verifier_kind~ : @types.AgentKind?,
    planner_model~ : String?,
    builder_model~ : String?,
    verifier_model~ : String?,
    milestones_path~ : String?,
    plan_path~ : String?,
    dry_run~ : Bool,
    lang~ : String?,
    log_path~ : String?,
    max_in_flight~ : Int?,
    warnings~ : Array[String]
  )
  Validate(String?)
  Help
  Version
}

///| Parse top-level CLI args.

///|
/// file_exists is injected for testability.
pub fn parse_cli_args(
  args : Array[String],
  file_exists : (String) -> Bool,
) -> CliCommand {
  if args.length() < 2 {
    return Run(
      config_path=None,
      planner_kind=None,
      builder_kind=None,
      verifier_kind=None,
      planner_model=None,
      builder_model=None,
      verifier_model=None,
      milestones_path=None,
      plan_path=None,
      dry_run=false,
      lang=None,
      log_path=None,
      max_in_flight=None,
      warnings=[],
    )
  }

  let first = args[1]
  match first {
    "help" | "--help" | "-h" => Help
    "version" | "--version" | "-v" => Version
    "validate" =>
      if args.length() >= 3 {
        Validate(Some(args[2]))
      } else {
        Validate(None)
      }
    _ => parse_run_args(drop_prefix(args, 1), file_exists)
  }
}

///|
/// Apply role-specific kind overrides to config.
pub fn apply_overrides(
  config : @config.ProjectConfig,
  planner_kind? : @types.AgentKind? = None,
  builder_kind? : @types.AgentKind? = None,
  verifier_kind? : @types.AgentKind? = None,
  planner_model? : String? = None,
  builder_model? : String? = None,
  verifier_model? : String? = None,
) -> @config.ProjectConfig {
  let agents : Array[@types.AgentConfig] = []
  for agent in config.agents {
    let kind = match agent.role {
      Planner =>
        match planner_kind {
          Some(k) => k
          None => agent.kind
        }
      Builder =>
        match builder_kind {
          Some(k) => k
          None => agent.kind
        }
      Verifier =>
        match verifier_kind {
          Some(k) => k
          None => agent.kind
        }
      _ => agent.kind
    }
    let model = match agent.role {
      Planner =>
        match planner_model {
          Some(_) => planner_model
          None => agent.model
        }
      Builder =>
        match builder_model {
          Some(_) => builder_model
          None => agent.model
        }
      Verifier =>
        match verifier_model {
          Some(_) => verifier_model
          None => agent.model
        }
      _ => agent.model
    }
    agents.push({ id: agent.id, kind, role: agent.role, model })
  }
  { ..config, agents, }
}

///|
/// Human-readable kind label for logs/usage.
pub fn kind_name(kind : @types.AgentKind) -> String {
  match kind {
    ClaudeCode => "claude-code"
    Codex => "codex"
    Mock => "mock"
  }
}

///|
fn parse_run_args(
  args : Array[String],
  _file_exists : (String) -> Bool,
) -> CliCommand {
  let mut config_path : String? = None
  let mut planner_kind : @types.AgentKind? = None
  let mut builder_kind : @types.AgentKind? = None
  let mut verifier_kind : @types.AgentKind? = None
  let mut planner_model : String? = None
  let mut builder_model : String? = None
  let mut verifier_model : String? = None
  let mut milestones_path : String? = None
  let mut plan_path : String? = None
  let mut dry_run : Bool = false
  let mut lang : String? = None
  let mut log_path : String? = None
  let mut max_in_flight : Int? = None
  let warnings : Array[String] = []

  let mut i = 0
  let len = args.length()
  while i < len {
    let token = args[i]
    if token.has_prefix("--planner=") {
      let raw = token.view(start_offset="--planner=".length()).to_string()
      match parse_kind_alias(raw) {
        Some(kind) => planner_kind = Some(kind)
        None => warnings.push("Unknown --planner kind: \{raw}")
      }
      i += 1
      continue
    }

    if token.has_prefix("--builder=") {
      let raw = token.view(start_offset="--builder=".length()).to_string()
      match parse_kind_alias(raw) {
        Some(kind) => builder_kind = Some(kind)
        None => warnings.push("Unknown --builder kind: \{raw}")
      }
      i += 1
      continue
    }

    if token.has_prefix("--verifier=") {
      let raw = token.view(start_offset="--verifier=".length()).to_string()
      match parse_kind_alias(raw) {
        Some(kind) => verifier_kind = Some(kind)
        None => warnings.push("Unknown --verifier kind: \{raw}")
      }
      i += 1
      continue
    }

    if token.has_prefix("--planner-model=") {
      let val = token.view(start_offset="--planner-model=".length()).to_string()
      if val.is_empty() {
        warnings.push("Missing value for --planner-model")
      } else {
        planner_model = Some(val)
      }
      i += 1
      continue
    }

    if token.has_prefix("--builder-model=") {
      let val = token.view(start_offset="--builder-model=".length()).to_string()
      if val.is_empty() {
        warnings.push("Missing value for --builder-model")
      } else {
        builder_model = Some(val)
      }
      i += 1
      continue
    }

    if token.has_prefix("--verifier-model=") {
      let val = token
        .view(start_offset="--verifier-model=".length())
        .to_string()
      if val.is_empty() {
        warnings.push("Missing value for --verifier-model")
      } else {
        verifier_model = Some(val)
      }
      i += 1
      continue
    }

    if token.has_prefix("--milestones=") {
      let path = token.view(start_offset="--milestones=".length()).to_string()
      if path.is_empty() {
        warnings.push("Missing value for --milestones")
      } else {
        milestones_path = Some(path)
      }
      i += 1
      continue
    }

    if token.has_prefix("--plan=") {
      let path = token.view(start_offset="--plan=".length()).to_string()
      if path.is_empty() {
        warnings.push("Missing value for --plan")
      } else {
        plan_path = Some(path)
      }
      i += 1
      continue
    }

    // --ralph is the default mode; flag accepted for explicitness
    if token == "--ralph" {
      i += 1
      continue
    }

    if token == "--dry-run" {
      dry_run = true
      i += 1
      continue
    }

    if token.has_prefix("--lang=") {
      let raw = token.view(start_offset="--lang=".length()).to_string()
      match raw {
        "auto" | "ja" | "en" => lang = Some(raw)
        _ => warnings.push("Unknown --lang value: \{raw} (expected auto|ja|en)")
      }
      i += 1
      continue
    }

    if token.has_prefix("--config=") {
      let path = token.view(start_offset="--config=".length()).to_string()
      if path.is_empty() {
        warnings.push("Missing value for --config")
      } else {
        config_path = Some(path)
      }
      i += 1
      continue
    }

    if token == "--config" {
      if i + 1 < len {
        let path = args[i + 1]
        if path.has_prefix("--") {
          warnings.push("Missing value for --config")
          i += 1
        } else {
          config_path = Some(path)
          i += 2
        }
      } else {
        warnings.push("Missing value for --config")
        i += 1
      }
      continue
    }

    if token.has_prefix("--max-in-flight=") {
      let raw = token.view(start_offset="--max-in-flight=".length()).to_string()
      let n = parse_positive_int(raw)
      if n > 0 {
        max_in_flight = Some(n)
      } else {
        warnings.push("--max-in-flight must be a positive integer, got: \{raw}")
      }
      i += 1
      continue
    }

    if token == "--max-in-flight" {
      if i + 1 < len {
        let raw = args[i + 1]
        if raw.has_prefix("--") {
          warnings.push("Missing value for --max-in-flight")
          i += 1
        } else {
          let n = parse_positive_int(raw)
          if n > 0 {
            max_in_flight = Some(n)
          } else {
            warnings.push(
              "--max-in-flight must be a positive integer, got: \{raw}",
            )
          }
          i += 2
        }
      } else {
        warnings.push("Missing value for --max-in-flight")
        i += 1
      }
      continue
    }

    if token.has_prefix("--log=") {
      let path = token.view(start_offset="--log=".length()).to_string()
      if path.is_empty() {
        warnings.push("Missing value for --log")
      } else {
        log_path = Some(path)
      }
      i += 1
      continue
    }

    if token == "--log" {
      if i + 1 < len {
        let path = args[i + 1]
        if path.has_prefix("--") {
          warnings.push("Missing value for --log")
          i += 1
        } else {
          log_path = Some(path)
          i += 2
        }
      } else {
        warnings.push("Missing value for --log")
        i += 1
      }
      continue
    }

    if token.has_prefix("--") {
      warnings.push("Unknown option: \{token}")
      i += 1
      continue
    }

    warnings.push("Unexpected argument: \{token}")
    i += 1
  }

  Run(
    config_path~,
    planner_kind~,
    builder_kind~,
    verifier_kind~,
    planner_model~,
    builder_model~,
    verifier_model~,
    milestones_path~,
    plan_path~,
    dry_run~,
    lang~,
    log_path~,
    max_in_flight~,
    warnings~,
  )
}

///|
fn parse_kind_alias(raw : String) -> @types.AgentKind? {
  match raw {
    "claude" | "claude-code" | "claudecode" => Some(ClaudeCode)
    "codex" => Some(Codex)
    "mock" => Some(Mock)
    _ => None
  }
}

///|
fn parse_positive_int(s : String) -> Int {
  let chars = s.to_array()
  let mut num = 0
  let mut found = false
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      num = num * 10 + (ch.to_int() - '0'.to_int())
      found = true
    } else {
      return 0
    }
  }
  if found {
    num
  } else {
    0
  }
}

///|
fn drop_prefix(args : Array[String], start : Int) -> Array[String] {
  let result : Array[String] = []
  let len = args.length()
  let mut i = start
  while i < len {
    result.push(args[i])
    i += 1
  }
  result
}
