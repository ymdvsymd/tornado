# whirlwind

Multi-agent development orchestrator — milestone-driven autonomous development with Planner, Builder, and Verifier agents.

## Usage

### Pattern 1: Run with `npx`

```bash
# run with default preset (Planner=claude-code, Builder=claude-code, Verifier=codex)
npx -y @ymdvsymd/whirlwind

# run with config file
npx -y @ymdvsymd/whirlwind --config=./whirlwind.json

# override agent kinds
npx -y @ymdvsymd/whirlwind --builder=codex --verifier=claude-code

# validate config
npx -y @ymdvsymd/whirlwind validate ./whirlwind.json
```

### Pattern 2: Install globally with `npm i -g`

```bash
npm i -g @ymdvsymd/whirlwind

# run with default preset
whirlwind

# run with config file
whirlwind --config=./whirlwind.json

# override agent kinds
whirlwind --builder=codex --lang=ja

# validate config
whirlwind validate ./whirlwind.json
```

## CLI flags

| Flag | Description |
|------|-------------|
| `--config=PATH` | Config file path |
| `--planner=KIND` | Override planner agent kind |
| `--builder=KIND` | Override builder agent kind |
| `--verifier=KIND` | Override verifier agent kind |
| `--milestones=PATH` | Milestones JSON file path |
| `--lang=LANG` | Review language (`auto`/`ja`/`en`) |
| `--log=PATH` | Log file path |

## Agent kind options

- `claude` / `claude-code`
- `codex`
- `mock`
