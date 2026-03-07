---
description: '計画ファイル(Markdown)からtornado Ralph モードの入力ファイルを生成し起動する'
---

# ralph-start: 計画ファイル -> tornado Ralph モード起動

計画ファイル（Markdown）を tornado の Ralph モードに必要な `tornado.json` + `milestones.json` に変換し、tornado を起動するコマンド。

## 引数

```
/ralph-start <plan-file.md> [--dev=<kind>] [--verifier=<kind>]
```

`$ARGUMENTS` の内容: `$ARGUMENTS`

## 実行手順

以下の Phase 1〜4 を**必ず順番に**実行すること。

---

### Phase 1: 入力検証

1. `$ARGUMENTS` を解析する:
   - 最初の `--` で始まらないトークンを `PLAN_FILE` とする
   - `--dev=<value>` があれば `DEV_KIND` に格納（デフォルト: `codex`）
   - `--verifier=<value>` があれば `VERIFIER_KIND` に格納（デフォルト: `claude-code`）
   - 引数が空、または `PLAN_FILE` が見つからない場合はエラーメッセージを出して終了

2. `PLAN_FILE` の存在を確認する（相対パスの場合は CWD からの解決）

3. リポジトリルートを取得:
   ```bash
   git rev-parse --show-toplevel
   ```

4. `PLAN_FILE` を読み込む

---

### Phase 2: 計画ファイル -> マイルストーン + タスク変換

計画ファイルの Markdown を以下の規則でパースする:

#### パース規則

| Markdown 要素 | 変換先 |
|--------------|--------|
| `# 見出し` (最初のH1) | プロジェクト名（ディレクトリ名に使用） |
| `## 見出し` | マイルストーンの `goal` |
| `## ` がない場合 | ファイル全体を1マイルストーンとして扱う |
| `- ` / `* ` / `N. ` リスト項目 | タスクの `description` |
| `### ` サブ見出し | 同一マイルストーン内の Wave 区切り（wave を +1） |

#### ディレクトリ名の生成

- 最初の `# 見出し` からタイトルを取得（なければファイル名のベースネーム）
- 小文字化、スペース/アンダースコアをハイフンに変換、英数字とハイフン以外を除去、50文字以内に切り詰め
- 出力ディレクトリ: `{repo_root}/.history/{yyyy-mm-dd}_{kebab-case-name}/`

#### タスク ID 命名規則

- マイルストーン `m1` のタスク: `m1-t1`, `m1-t2`, ...
- マイルストーン `m2` のタスク: `m2-t1`, `m2-t2`, ...

#### description の拡張（最重要）

`description` は Builder (Codex/Claude Code) に渡される**唯一の入力**である。system_prompt は空、milestone の goal も渡されない。

したがって、各タスクの `description` は以下を満たすように**拡張**すること:
- 曖昧な項目は具体的な実装指示に書き換える
- ファイルパス、期待する動作、実装の詳細を含める
- Claude Code に直接指示するのと同じ粒度で書く

さらに、各タスクの `description` 末尾に計画ファイルの全内容をコンテキストとして埋め込む:

```
<具体的なタスク指示（拡張済み）>

---
## Plan Context
<元の計画ファイルの全内容>
```

---

### Phase 3: 出力ファイル生成

出力ディレクトリを作成し、2つのファイルを書き出す。

#### 3-1. milestones.json

```json
{
  "milestones": [
    {
      "id": "m1",
      "goal": "## 見出しから取得した目標テキスト",
      "status": "pending",
      "current_wave": 0,
      "tasks": [
        {
          "id": "m1-t1",
          "description": "具体的で自己完結した実行指示。...\n\n---\n## Plan Context\n...",
          "wave": 0,
          "status": "pending",
          "result": null,
          "plan_doc": null
        }
      ]
    }
  ]
}
```

#### 3-2. tornado.json

`milestones_path` は**絶対パス**で指定すること（tornado は process.cwd() で動作するため）。

```json
{
  "ralph_enabled": true,
  "milestones_path": "<絶対パス>/.history/{date}_{name}/milestones.json",
  "review_dir": ".history/{date}_{name}",
  "max_rework_attempts": 3,
  "agents": [
    {
      "id": "planner",
      "kind": "mock",
      "role": "planner",
      "max_iterations": 1
    },
    {
      "id": "builder",
      "kind": "<DEV_KIND>",
      "role": "dev",
      "max_iterations": 10
    },
    {
      "id": "verifier",
      "kind": "<VERIFIER_KIND>",
      "role": "verifier",
      "max_iterations": 5
    }
  ]
}
```

注意:
- Planner は `"kind": "mock"` 固定（バリデーション通過用。tasks が事前定義済みなので実行されない）
- Builder の kind は `DEV_KIND`（デフォルト: `codex`）
- Verifier の kind は `VERIFIER_KIND`（デフォルト: `claude-code`）

---

### Phase 4: 検証・起動

1. **JSON バリデーション**: 生成した両ファイルを `jq .` で検証

2. **サマリー表示**: 以下の情報を表示する
   ```
   === Ralph Start ===
   Plan file:    <plan-file.md>
   Output dir:   .history/{date}_{name}/
   Milestones:   N 個
   Total tasks:  N 個
   Builder:      <DEV_KIND>
   Verifier:     <VERIFIER_KIND>

   Milestones:
     m1: <goal> (N tasks, M waves)
     m2: <goal> (N tasks, M waves)
     ...
   ```

3. **tornado 起動**:
   ```bash
   npx -y @mizchi/tornado --ralph --config=<tornado.json の絶対パス>
   ```

---

## エラーハンドリング

- 計画ファイルが見つからない場合 -> エラーメッセージを出して終了
- 計画ファイルにリスト項目が1つもない場合 -> エラーメッセージを出して終了
- `--dev` / `--verifier` に無効な値が指定された場合 -> エラーメッセージを出して終了
  - 有効な値: `claude-code`, `claude`, `claudecode`, `codex`, `api`, `mock`
- JSON バリデーション失敗 -> エラーメッセージを出して終了（ファイルは残す）
