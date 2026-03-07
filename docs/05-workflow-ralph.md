# Ralph Loop & Workflow

## 1. 2つの実行モード

### 通常モード (Heartbeat Loop) - `while true` 無限ループ

通常モードは `run_repl()` 内の **無限ループ** で動作する。
`Orchestrator::run()` は呼ばれず、`run_dev()` と `run_review()` を直接呼ぶ。
終了は **Ctrl+C のみ**。Approved でも自動的に次タスクを生成して回り続ける。

```
CLI (tornado plan.md --dev=codex --review=claude)
  -> run_repl()
    while true {                          // Ctrl+C まで永久に回る
      1. check_interrupt()                // ユーザー入力チェック
      2. run_dev(task)                    // Devエージェント実行
      3. if dev_since_review < review_interval:
           build_next_task() -> continue  // レビューせず次のdev
      4. run_review(3 perspectives)       // 3観点レビュー
      5. match result:
           Approved  -> build_next_task() // 自動で次タスク生成 -> continue
           Rejected  -> ユーザー入力待ち  // interrupt polling -> continue
    }
```

**重要な特性:**
- `review_interval` で N 回 dev してから 1 回 review（デフォルト: 1）
- Approved 後は `build_next_task()` / `build_continuation_task()` で自動継続
- Rejected 時は `check_interrupt()` でユーザー入力をポーリング待ち
- セッション状態を `.tornado/session.json` に毎イテレーション保存（resume 可能）
- `--rlm` フラグで improvement loop mode（measure -> improve -> verify -> commit/revert）
- トークン使用量・コストを per-iteration / cumulative で追跡

> **Note:** `src/orchestrator/orchestrator.mbt` には `Orchestrator::run()` メソッドが
> 定義されている（Decompose -> Assign -> Execute -> Review -> Iterate -> Finalize の
> 6フェーズ制御）が、**現在の `run_repl()` からは使われていない**。
> 将来的な利用または別エントリーポイント用と推測される。

### Ralph モード (`--ralph`) - マイルストーン駆動

```
CLI (tornado --ralph --config=tornado.json)
  -> RalphLoop::run()
    Milestone ループ:
      1. Planning    - Planner が Milestone -> Wave + Task に分解
      2. Executing   - Builder が Wave ごとに実行
      3. Verifying   - Verifier が Wave 結果を検証
      4. Reworking   - 必要に応じて修正 (max_rework_attempts)
    AllComplete (全マイルストーン完了で終了)
```

---

## 2. Ralph 自律開発ループ詳細

### 2.1 3層構造

```
Milestone (目標単位)
  Wave (依存関係グループ)
    RalphTask (個別実行タスク)
```

- 同一 Wave のタスク: 並列実行可能（依存関係なし）
- 異なる Wave のタスク: 順序実行（WAVE 0 -> WAVE 1 -> ...）

### 2.2 3大エージェント

| エージェント | 役割 | 入力 | 出力 |
|------------|------|------|------|
| PlannerAgent | Milestone -> Tasks分解 | milestone.goal | WAVE N: task list |
| Builder (Dev) | タスク実行 | task.description | result.content |
| VerifierAgent | Wave品質検証 | milestone + wave_results | Approved / NeedsRework / Failed |

### 2.3 状態マシン

```
LoadingMilestones
  -> next_pending_milestone() ループ
    -> Planning(m_id)
      -> ExecutingWave(m_id, wave)
        -> Verifying(m_id, wave)
          -> [Approved] 次Wave or MilestoneComplete
          -> [NeedsRework] Reworking(m_id, wave)
            -> Verifying (attempt++)
          -> [MilestoneFailed] milestone.status = Failed
  -> AllComplete
```

---

## 3. エージェント間データ受け渡し

### 3.1 Planner -> Builder

WAVEテキスト形式:
```
WAVE 0:
1. Create database schema
2. Write migration scripts

WAVE 1:
1. Build API handlers
2. Add authentication
```

パース: `MilestoneManager::parse_planner_output()` が
WAVE ヘッダーと番号付き/箇条書きリストを解析

### 3.2 Builder -> Verifier

タスク結果の配列:
```
[(task_id: "m1-t1", result: "Schema creation output..."),
 (task_id: "m1-t2", result: "Migration output...")]
```

### 3.3 Verifier -> RalphLoop

XMLタグベース判定:
- `<wave_approved>` -> Approved
- `<needs_rework>m1-t1: fix error\nm1-t2: add validation</needs_rework>` -> NeedsRework
- `<milestone_failed>Architecture fundamentally flawed</milestone_failed>` -> Failed

---

## 4. 終了条件

### 4.1 Ralph ループ

| レベル | 終了条件 | 動作 |
|-------|---------|------|
| Milestone | next_pending_milestone() == None | AllComplete |
| Wave | has_undone_tasks() == false | MilestoneComplete |
| Rework | attempt >= max_rework_attempts | 強制承認 |
| Milestone失敗 | `<milestone_failed>` 検出 | milestone.status = Failed, 次へ |

### 4.2 通常モード (Heartbeat Loop)

| 状態 | 終了条件 | 動作 |
|------|---------|------|
| 外側ループ | **Ctrl+C のみ** | `while true` で永久に回る |
| Dev実行 | run_dev() 完了 | 出力が空なら review skip |
| Review skip | dev_since_review < review_interval | build_next_task() で次 dev |
| Review内rework | cycle >= max_review_cycles | rework 打ち切り |
| Approved | 自動 | build_next_task() で次イテレーション |
| Rejected | ユーザー入力受領 | check_interrupt() polling |

### 4.3 制御パラメータ

```
通常モード (Heartbeat Loop):
  max_review_cycles: 3       run_review() 内の rework 上限
  review_interval: 1         N回 dev したら 1回 review

Ralph:
  max_rework_attempts: 3     Wave単位の rework 上限

Agent:
  max_iterations: 10         エージェント内部の反復上限
```

> **Note:** 通常モードの外側ループ自体には終了条件がない。
> `max_review_cycles` は `run_review()` 内の rework サイクル上限であり、
> 外側ループの終了には影響しない。

---

## 5. レビューサイクル (通常モード)

### run_review() 内の rework ループ

```
run_review(dev_id, reviewer_id, backends, task, dev_output, max_cycles, ...)
  -> ReviewAgent::review(task, backend)  // 3観点レビュー
     -> CodeQuality, Performance, Security -> merge verdict
  -> match verdict:
       Approved -> ReviewOutcome::Approved
       NeedsChanges(items) ->
         while cycle < max_cycles {       // rework ループ (max_review_cycles)
           feedback = items -> "- item1\n- item2\n"
           rework_task = task + feedback
           current_output = run_dev(rework_task)  // Dev に feedback 付きで再実行
           re-review(current_output)
           if Approved -> return Approved
           if Rejected -> return Rejected
           // NeedsChanges -> continue loop
         }
         -> NeedsChanges exhausted -> ReviewOutcome::Approved(latest_summary)
       Rejected -> ReviewOutcome::Rejected
```

**通常モードでは review feedback が Dev に渡される** (Ralph と異なる点):
- `run_review()` 内で `NeedsChanges(items)` を feedback 文字列に変換
- `run_dev()` に `task + "\n\nFeedback from review:\n" + feedback` を渡す

### 3観点レビュー

```
ReviewAgent::review(task, backend)
  -> CodeQuality: 可読性、命名、関心の分離、エラーハンドリング
  -> Performance: 時間/空間計算量、N+1クエリ、キャッシング
  -> Security: 入力バリデーション、インジェクション、認証
  -> merge: 最初のRejected = 全体Rejected, else NeedsChanges統合
```

### プロンプト構造

```
## Task
[task description]

## Agent Output
[agent output]

## Review Focus: [Perspective]
- [aspect 1]
- [aspect 2]

## Important
Your job is to identify issues as TODO list -- do NOT fix them.

## Instructions
Respond with EXACTLY ONE:
- <approved>
- <needs_changes>item1, item2</needs_changes>
- <rejected>reason</rejected>
```

---

## 6. CLI -> ワークフロー起動パス

### 6.1 起動フロー

```
1. parse_cli_args(args)
   -> CliCommand::Run { ralph, config_path, dev_kind, ... }

2. if ralph:
     run_ralph(config_path, lang, dev_kind, review_kind)
       - Load config (tornado.json or preset_ralph)
       - apply_overrides()
       - Load milestones (.tornado/milestones.json)
       - Create backends (Planner, Builder, Verifier)
       - RalphLoop::new(...).run()
   else:
     run_repl(config_path, plan_path, rlm, initial_task, ...)
       - Load config (tornado.json or preset_default)
       - apply_overrides()
       - Create backends (Dev, Reviewer)
       - Resume session? (.tornado/session.json)
       - Get initial task (plan file / prompt / TODO files)
       - start_stdin_watcher()
       - while true { run_dev() -> run_review() -> build_next_task() }
```

### 6.2 設定ロード順序

1. `--config=PATH` or デフォルト `tornado.json`
2. JSON パース -> ProjectConfig
3. `apply_overrides()` で CLI フラグ反映
4. `validate()` でエージェント構成チェック

### 6.3 プリセット

**preset_default()**: 通常モード用
- Dev(ClaudeCode) + Reviewer(Codex)
- max_review_cycles: 3

**preset_ralph()**: Ralph モード用
- Planner(ClaudeCode) + Builder(ClaudeCode) + Verifier(Codex)
- max_rework_attempts: 3
- ralph_enabled: true

---

## 7. マイルストーン永続化

### JSON 形式 (.tornado/milestones.json)

```json
{
  "milestones": [
    {
      "id": "m1",
      "goal": "Build authentication system",
      "status": "pending",
      "current_wave": 0,
      "tasks": [
        {
          "id": "m1-t1",
          "description": "Create database schema",
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

- `MilestoneManager::load_from_json()` でロード
- `MilestoneManager::to_json()` でシリアライズ
- ロード時に `max(task_id)` から `next_task_id` を復元

---

## 8. 機能進化 (コミット履歴)

| Phase | コミット | 機能 |
|-------|---------|------|
| 1 | 54cab0c | 基盤: Orchestrator (Decompose -> Assign -> Execute -> Review) |
| 2 | 2da99c4-4a0af97 | 自律化: Iteration, 3-perspective review |
| 3 | b82f97d-cbea064 | 改善: RLM mode, --lang |
| 4 | f66a8cd | Ralph: Milestone-driven autonomous development |

---

## 9. 未実装・改善余地

### 9.1 Feedback 未活用 (Ralph モードのみ)

Ralph モードの問題:
- `NeedsRework(items)` が VerifierAgent から返される
- しかし `rework_tasks()` では feedback パラメータが `_` (未使用)
- 再実行プロンプトは一律 `"Rework: " + task.description`
- Verifier の指摘が Builder に伝わらない

> **対照的に通常モードでは** `run_review()` 内で NeedsChanges の feedback を
> Dev に正しく渡している: `task + "\n\nFeedback from review:\n" + feedback`

改善案:
```
rework_prompt = "Rework: " + task.description + "\n\nFeedback: " + feedback_item
```

### 9.2 Orchestrator モジュールの未使用

- `src/orchestrator/orchestrator.mbt` に 6 フェーズ制御の `Orchestrator::run()` が定義されている
- しかし `run_repl()` からは呼ばれず、代わりに独自の `while true` ループが使われている
- `OrchestratorCallbacks` 型は Ralph ループのみで利用
- Orchestrator モジュール自体のテスト (`orchestrator_test.mbt`) は存在するが、
  実際のランタイムパスではデッドコードになっている可能性がある

### 9.2 Wave 並列実行未実装

- 設計上は同一 Wave のタスクは並列実行可能
- 実装は `for task in wave_tasks` で順序実行
- 改善: async 実行 or 複数プロセス起動

### 9.3 その他

- `review_interval` が Config で定義されるが Ralph では未使用
- `current_wave` フィールドが resume 機能の準備か不明
- プログレッシブなマイルストーン追加/削除は未対応

---

## 10. 全体アーキテクチャ図

### 10.1 通常モード (Heartbeat Loop)

```
CLI (tornado plan.md --dev=codex --review=claude)
  |
  parse_cli_args()
  |
  run_repl()
    |-- Load config (tornado.json or preset_default)
    |-- apply_overrides() [--dev, --review, --lang]
    |-- Create backends (Dev, Reviewer)
    |-- Resume session? (.tornado/session.json)
    |-- Get initial task (plan file / prompt / TODO files)
    |-- start_stdin_watcher()
    `-- while true {                          // INFINITE LOOP (Ctrl+C to stop)
          |-- iteration++
          |-- check_interrupt()               // user input from .tornado/interrupt.txt
          |-- save_session(phase: "dev")
          |-- run_dev(dev_id, task)            // Dev agent execution
          |     `-- backend.run(task, on_event) -> dev_result
          |-- if dev_result empty -> continue
          |-- if dev_since_review < review_interval
          |     `-- build_next_task() -> continue  // skip review
          |-- save_session(phase: "review")
          |-- run_review(task, dev_output)     // 3-perspective review
          |     |-- ReviewAgent::review()
          |     |-- if NeedsChanges:
          |     |     `-- while cycle < max_cycles:
          |     |           run_dev(feedback) -> re-review()  // rework loop
          |     `-- -> Approved(summary) or Rejected(reason)
          |-- save_session(phase: "idle")
          `-- match result:
                Approved  -> build_next_task() -> continue
                Rejected  -> poll check_interrupt() until user input -> continue
        }
```

### 10.2 Ralph モード

```
CLI (--ralph)
  |
  parse_cli_args()
  |
  run_ralph()
    |-- Load config (tornado.json or preset_ralph)
    |-- apply_overrides() [--dev, --review, --lang]
    |-- Load milestones (.tornado/milestones.json)
    `-- RalphLoop::new()
          |-- backends[Planner, Builder, Verifier]
          |-- MilestoneManager
          `-- run()
                |-- LoadingMilestones
                |     `-- next_pending_milestone() loop
                |           `-- run_milestone(m)
                |                 |-- Planning (Planner agent)
                |                 |     `-- parse_planner_output() -> WAVE
                |                 `-- while has_undone_tasks()
                |                       `-- run_wave(wave_num)
                |                             |-- Executing (Builder agent)
                |                             |     `-- collect_wave_results()
                |                             `-- verify_wave() [recursive]
                |                                   |-- Verifying (Verifier agent)
                |                                   |-- Approved -> next wave
                |                                   |-- NeedsRework -> Reworking
                |                                   |     `-- rework_tasks()
                |                                   |     `-- verify_wave(attempt+1)
                |                                   `-- MilestoneFailed -> stop
                `-- AllComplete
```
