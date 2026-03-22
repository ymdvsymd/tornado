# whirlwind.json テンプレート

## テンプレート

```jsonc
{
  "milestones_path": "<絶対パス>/.runs/{datetime}_{name}/milestones.json",
  "max_rework_attempts": 3,
  "agents": [
    { "id": "planner",  "kind": "<PLANNER_KIND>",  "role": "planner" },
    { "id": "builder",  "kind": "<BUILDER_KIND>",  "role": "builder" },
    { "id": "verifier", "kind": "<VERIFIER_KIND>", "role": "verifier" }
  ]
}
```

## 重要事項

- `milestones_path` は**絶対パス**で指定すること（whirlwind は process.cwd() で動作するため）

## 有効な agent kind 値

`claude-code`, `claude`, `claudecode`, `codex`, `mock`
