# Testing, Quality & Build System

## エグゼクティブサマリー

- **テストカバレッジ**: 3,420行 (テスト) vs 5,745行 (実装) = **59.5%**
- **テストファイル数**: 16 (MoonBit 14 + TypeScript 2)
- **テストケース総数**: 約165テストケース
- **品質スコア**: 8.2/10

---

## 1. テストファイル一覧

### MoonBit テスト (14ファイル, ~3,350行)

| ファイル | 行数 | ケース数 | テスト対象 |
|---------|------|---------|----------|
| src/agent/agent_test.mbt | 516 | 32 | MockBackend, イベント解析, OutputLineBuffer |
| src/cli/cli_test.mbt | 402 | 25 | CLI引数パース, フラグ解析 |
| src/review/review_test.mbt | 345 | 27 | 3観点レビュー, 評決パース, 多言語 |
| src/orchestrator/orchestrator_test.mbt | 365 | 13 | フェーズ遷移, イテレーション |
| src/ralph/ralph_loop_test.mbt | 310 | 8 | 自律ループ全体フロー |
| src/ralph/milestone_test.mbt | 205 | 15 | マイルストーン管理, JSON永続化 |
| src/config/config_test.mbt | 279 | 22 | 設定パース, バリデーション |
| src/display/display_test.mbt | 167 | 15 | ツール表示, テキスト整形 |
| src/types/types_test.mbt | 155 | 17 | 型定義, enum to_string |
| src/tui/tui_test.mbt | 143 | 10 | TUI状態, コールバック |
| src/spawn/line_buffer_test.mbt | 103 | 10 | 行バッファ, CRLF |
| src/ralph/verifier_test.mbt | 95 | 8 | 検証結果パース |
| src/task/task_test.mbt | 89 | 9 | タスク管理, テキストパース |
| src/ralph/planner_test.mbt | 64 | 4 | 計画生成, WAVEパース |

### TypeScript テスト (2ファイル, ~140行)

| ファイル | 行数 | ケース数 | テスト対象 |
|---------|------|---------|----------|
| sdk/agent-runner.test.mjs | 70 | 2 | アダプター実行フロー |
| sdk/codex-normalizer.test.mjs | 70 | 3+ | Codex->Claude正規化 |

---

## 2. テスト手法

### 2.1 モック戦略

**MockBackend** (`src/agent/mock.mbt`):
- `default_response`: デフォルト固定応答
- `add_response(keyword, response)`: キーワードベースの条件付き応答
- `get_history()`: 呼び出し履歴の追跡
- `boxed()`: BoxedBackend への変換

**FailingMockBackend**:
- 常に StatusChange(Failed(msg)) を発火
- バックエンド障害のテストに使用

### 2.2 テストパターン

**Arrange-Act-Assert (AAA)**:
```moonbit
let mock = MockBackend::new(default_response="...")
let backend = mock.boxed()
let result = backend.run("task", "prompt", fn(_) { })
inspect(result.content, content="expected")
```

**Collector Pattern** (複合イベント検証):
```moonbit
struct EventCollector {
  infos: Array[String]
  tool_calls: Array[(String, String)]
  tool_results: Array[(String, String)]
  sub_starts: Array[(String, String)]
  sub_ends: Array[String]
}
```

**Helper Functions**:
- `make_ralph_config()`: Ralph設定プリセット
- `make_test_config()`: Orchestrator設定プリセット
- `make_backends()`: mock backend map構築

### 2.3 属性ベーステスト

| 属性 | 適用例 |
|------|-------|
| 境界値 | token=0, duration=0, review_interval=0 (invalid) |
| 等価分割 | lang: "ja"/"en"/"auto"/(invalid) |
| エッジケース | empty string, malformed JSON, missing fields |
| 状態遷移 | Task: Pending -> InProgress -> Done |
| 複合条件 | ralph_enabled && no planner (invalid) |

---

## 3. モジュール別カバレッジ分析

| モジュール | カバレッジ | 評価 | 備考 |
|-----------|----------|------|------|
| agent (event parse) | 高 | A | JSONL全イベント型カバー |
| cli | 高 | A | 全フラグ・コマンドカバー |
| config | 高 | A | バリデーション全ルールカバー |
| display | 高 | A | 全ツール表示カバー |
| task | 高 | A | ID生成・状態遷移完全 |
| spawn (line_buffer) | 高 | A | エッジケース豊富 |
| review | 中-高 | A- | 3観点 + マージ + 多言語 |
| orchestrator | 中-高 | A- | フェーズ遷移 + 失敗回復 |
| ralph | 中-高 | B+ | 状態マシン + rework cycle |
| types | 中 | B | enum show のみ |
| tui | 中 | B | 状態 + コールバック (render詳細不足) |
| sdk | 低-中 | C+ | アダプター基本フローのみ |

### テストされていない領域

1. **FFI境界**: ffi_js.mbt のJavaScript関数
2. **実際のSDK実行**: SubprocessBackend の実動作
3. **ファイルI/O**: review markdown生成、milestone JSON永続化
4. **大規模シナリオ**: 100+ タスク、並列エージェント
5. **TUIレンダリング詳細**: VNode描画の実際の出力

---

## 4. ビルドシステム

### justfile ターゲット

| Target | 依存 | コマンド | 説明 |
|--------|------|---------|------|
| default | check, test | - | 型チェック + テスト |
| setup | - | npm install | 依存インストール |
| check | - | npm run build:sdk && moon check --target js | 型チェック |
| test | - | npm run build:sdk && node --test && moon test | テスト実行 |
| build | - | npm run build:sdk && moon build --target js | アプリビルド |
| pack | build | bin/tornado.js 生成 | shebang付き実行可能ファイル |
| publish | pack | npm publish --access public | npm公開 |
| run | build | node app.js | ローカル実行 |
| clean | - | moon clean | キャッシュクリア |
| fmt | - | moon fmt | コードフォーマット |

### ビルドパイプライン

```
1. npm run build:sdk
   TypeScript (.mts) -> JavaScript (.mjs)
   tsconfig.sdk.json: ES2022, strict, NodeNext

2. moon check --target js
   MoonBit 型チェック (JS ターゲット)

3. moon build --target js src/cmd/app
   MoonBit -> JavaScript コンパイル
   出力: _build/js/debug/build/cmd/app/app.js

4. pack
   shebang (#!/usr/bin/env node) + app.js -> bin/tornado.js

5. npm publish
   files: [bin/, sdk/] を npm に公開
```

### バージョン不一致

- `moon.mod.json`: 0.5.0
- `package.json`: 0.4.0
- 注: MoonBitパッケージとnpmパッケージのバージョンが異なる

---

## 5. テスト実行方法

```bash
# 全テスト実行
just test

# 個別実行
moon test --target js           # MoonBit テストのみ
node --test sdk/*.test.mjs      # TypeScript テストのみ

# 型チェックのみ
just check

# フォーマット
just fmt
```

---

## 6. .gitignore

```
_build/           # MoonBit build artifacts
bin/              # Compiled executables
.mooncakes/       # MoonBit package cache
.tornado/         # Runtime state/cache
target/           # Build output
node_modules/     # NPM dependencies
```

---

## 7. 品質改善の推奨事項

### 優先度: 高

1. **SDK統合テスト追加**: Claude/Codex adapter の実動作テスト
2. **バージョン同期**: moon.mod.json と package.json の一致

### 優先度: 中

3. **MockBackend拡張**: regex/glob パターンマッチング
4. **TUIレンダリングテスト**: render_app の出力検証
5. **エラー伝播テスト**: Backend失敗 -> Review拒否の一貫性

### 優先度: 低

6. **大規模シナリオテスト**: 100+ タスク
7. **パフォーマンステスト**: ストリーミング処理のスループット
8. **テスト構造ドキュメント**: Mock戦略ガイド
