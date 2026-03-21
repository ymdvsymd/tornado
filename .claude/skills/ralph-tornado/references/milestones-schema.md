# milestones.json 形式

このスキルは skeleton ではなく、`milestones.json` を直接生成する。

## JSON 例

```json
{
  "brief": "plan から skill が抽出した goals と constraints",
  "milestones": [
    {
      "id": "m1",
      "goal": "## 見出しから抽出した goal の英語文",
      "status": "pending",
      "summary": "",
      "tasks": []
    }
  ]
}
```

## フィールド定義

| フィールド    | 型     | 説明 |
| ------------- | ------ | ---- |
| `brief`       | string | plan の goals と constraints を skill が抽出した要約 |
| `milestones`  | array  | milestone 配列 |

### milestone

| フィールド | 型     | 説明 |
| ---------- | ------ | ---- |
| `id`       | string | `m{連番}` 形式（例: `m1`, `m2`） |
| `goal`     | string | `## 見出し` テキストを英訳した milestone goal |
| `status`   | string | 初期値は `"pending"` |
| `summary`  | string | milestone 完了時に runtime が生成する要約。初期値は `""` |
| `tasks`    | array  | 初期値は `[]` |

## 注記

- skill は `milestones.json` を直接生成する。skeleton ファイルや後段の注入ステップは使わない
- `brief` は Builder / Planner に渡す背景情報であり、実装詳細の全文コピーではなく短い要約にする
- `summary` は各 milestone 完了後に runtime が書き戻し、次の Planner 実行時の背景情報として使われる
- タスクはランタイムの Planner エージェントが自動生成します。
