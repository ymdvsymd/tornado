# Ralph モード強化ロードマップ

**作成日**: 2026-03-20
**調査背景**: 7つの専門エージェント + 3つの追加調査エージェントによるコードベース徹底調査

---

## 優先度: HIGH

### 1. Verifier サイレント承認バグ修正

**問題**: `verifier.mbt:107` — Verifier バックエンドが障害を起こした場合（レートリミット、ネットワークエラー、クラッシュ等）、黙って `Approved` を返す。Review モジュールでは同一パターンが修正済み（障害時は `Rejected` を返す）。

**スコープ**: コード1行修正 + テスト1件追加

**対象ファイル**:
- `src/ralph/verifier.mbt:107` — `_ => Approved` を `_ => MilestoneFailed("Verifier backend failed: {err}")` に変更
- `src/ralph/verifier_test.mbt` — Review モジュールの `review_perspective propagates backend failure instead of silent approval` に相当するテストを追加

**HIGH の理由**: 検証なしで Wave が承認される = サイレントな品質低下。実質的にバグ。

---

### 2. Verifier 3観点検証の強化

**問題**: VerifierAgent は曖昧な単一プロンプト（"Check code quality, correctness, and alignment"）を使用。一方、通常モードの ReviewAgent は構造化された3観点評価（CodeQuality / Performance / Security）を実施している。

**調査結果**:

| 項目 | ReviewAgent (通常モード) | VerifierAgent (Ralph モード) |
|------|------------------------|----------------------------|
| LLM 呼び出し | 3回/タスク | 1回/Wave |
| 観点分離 | 明示的（各観点に専用プロンプト） | なし（汎用プロンプト） |
| フィードバックタグ | `[CodeQuality]`, `[Performance]`, `[Security]` | なし |
| スコープ | 単一タスク | Wave 全体（マイルストーン認識あり） |

**3つの選択肢**:

| アプローチ | LLM 回数 | コスト | 観点カバレッジ |
|-----------|---------|--------|--------------|
| 現状（曖昧な単一プロンプト） | 1回/Wave | 1x | 暗黙的 |
| **Option 1: プロンプト強化（推奨）** | **1回/Wave** | **1x** | **明示的** |
| Option 2: フル3観点（3回呼び出し） | 3回/Wave | 3x | 最大 |

**推奨: Option 1** — 1回の LLM 呼び出しの中で3観点を明示指示。

**実装**:
- `src/ralph/verifier.mbt` — `build_verify_prompt()` を更新:
  - CodeQuality（可読性、命名、エラーハンドリング、テストカバレッジ）
  - Performance（計算量、不要なアロケーション、N+1クエリ、キャッシング）
  - Security（入力バリデーション、インジェクション、認証/認可、機密データ露出）
  - フィードバック形式: `task_id: [Security] SQL injection check missing`
- `src/ralph/verifier_test.mbt` — 観点タグ付きフィードバックのパーステスト追加
- `rework_tasks()` は変更不要 — 観点タグはフィードバック文中に埋め込まれ、`strip_task_feedback_prefix()` はそのまま動作

**効果測定**: 導入後、フィードバックの観点タグ出現率が30%未満なら Option 2 へエスカレーション。

---

## 優先度: MEDIUM

### 3. Ralph resume 機能（current_wave の活用）

**問題**: `Milestone` 構造体の `current_wave` フィールドは JSON にシリアライズ/デシリアライズされるが、**ランタイムで一度も読み書きされていない**（dead code）。Ralph モードには通常モードのようなインタラクティブ resume がなく、実行中にクラッシュすると Wave 全体が最初からやり直しになる。

**調査結果**:
- `current_wave` は `run_wave()` で更新されず、`run_milestone()` でも読まれない
- Wave 追跡は `next_wave_number()` でタスク状態から動的に算出（current_wave 不要）
- 通常モードの resume: `.tornado/session.json` + インタラクティブプロンプト + エージェントセッション復元
- Ralph の resume: マイルストーンレベルのみ（pending/in_progress ステータス）

**Option A: フィールド削除（最小対応）**
- resume が優先でなければ `current_wave` を Milestone 構造体・JSON スキーマから削除
- dead code の除去

**Option B: 本格 resume 実装（推奨）**
1. `src/ralph/ralph_loop.mbt` — `run_wave()` で `milestone.current_wave = wave` を更新
2. `src/ralph/ralph_loop.mbt` — resume 時に Done タスクをスキップ:
   ```moonbit
   for task in tasks {
     match task.status { Done => continue; _ => run_task(task) }
   }
   ```
3. `src/cmd/app/main.mbt` — Ralph 用 resume プロンプト追加:
   ```
   // milestones.json に in_progress マイルストーンがあれば
   // "Milestone M1, Wave W2 から再開しますか？ [Y/n]"
   ```
4. `src/ralph/milestone.mbt` — Wave 完了ごとにマイルストーン状態を保存（ループ終了時だけでなく）

---

### 4. バージョン整合（moon.mod.json）

**問題**: `moon.mod.json` v0.5.0（モジュール名 `mizchi/tornado`）と `package.json` v0.6.0（`@ymdvsymd/tornado`）でバージョンが乖離。moon.mod.json のリポジトリ URL も旧組織（`github.com/mizchi/tornado`）のまま。

**調査結果**:
- MoonBit (mooncakes.io) と npm は独立したエコシステム — バージョン連動の仕組みなし
- `.mooncakes/` ディレクトリ + `.moon-lock` が存在 — mooncakes.io に公開済み
- コード内でバージョン番号を参照する箇所なし — 機能的な影響ゼロ
- `mizchi/tornado` は MoonBit 内部のモジュール名、npm 配布名とは別

**実装**:
- `moon.mod.json` — バージョンを 0.6.0 に更新、リポジトリ URL を `github.com/ymdvsymd/tornado` に修正
- 検討: モジュール名を `ymdvsymd/tornado` に変更（mooncakes.io の再公開が必要になる可能性）
- 公開手順のドキュメント化（どのバージョンファイルをいつ更新するか）

---

## 優先度: LOW（実装不要 / 将来検討）

### 5. review_interval の Ralph モード対応 — 実装しない

**調査結論**: アーキテクチャの不一致。実装すべきでない。

**根拠**:
- 通常モード: `review_interval=N` = 「N回 dev してから1回 review」= バッチングパラダイム
- Ralph モード: 毎 Wave を検証 = 品質ゲートパラダイム
- Wave 検証のスキップは Ralph の存在意義（検証済みマイルストーン）を否定する
- コスト節約は微小（~$0.007/マイルストーン）
- 実装の複雑さ・リスクが利益を大幅に上回る

**対応**:
- `ralph_loop.mbt` に `review_interval` を意図的に使用していない理由のコードコメントを追加
- オプション: `preset_ralph()` から `review_interval` を削除して混乱を回避
- **Ralph を速く/安くしたいユーザーへの代替案**:
  - `max_rework_attempts` を 1-2 に減らす
  - Verifier に安価なモデルを使う（エージェント設定で変更可能）
  - 検証頻度を下げたいなら通常モード + `--review-interval=5` を使用

### 6. マイルストーンの動的追加/削除 — 将来検討

現在は実行前に JSON で事前定義が必要。長期実行プロジェクトでは有用だが、複雑さが大きい。
明確なユーザー需要が出るまで保留。

---

## 参考: Dead Code / クリーンアップ候補

| 対象 | 場所 | 状態 |
|------|------|------|
| `plan_doc` フィールド (RalphTask) | `types.mbt` | どこからも読まれていない — 削除 or 実装 |
| `MockBackend::failing()` | `agent/mock.mbt:72` | 未使用 — `FailingMockBackend` が代替 |
| `Orchestrator::run()` | `orchestrator/orchestrator.mbt` | ランタイムから呼ばれていない — ライブラリ API として文書化 or 削除 |
| `spawn/` モジュール | `src/spawn/` | 他モジュールからインポートなし — 将来の非同期基盤 |
