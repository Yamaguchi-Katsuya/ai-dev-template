# Planning規約

planningドキュメントは `investigate/planning/` に保存する。

## 命名規則

- チケットあり: `NONE-12345.md`
- チケットなし: 内容を表す名前（例: `investigate-opensearch-mapping.md`）

## ドキュメントに含める内容

- タスク概要・背景
- 影響範囲（ドメイン・ファイル）
- 設計方針・採用した理由
- 注意点・懸念事項
- 実装ステップ

## 参照タイミング

`dev/slot-1/repos/` / `dev/slot-2/repos/` 等で作業開始前に `investigate/planning/` を確認する。
planningなしで直接作業を始める場合はドキュメント不要。
