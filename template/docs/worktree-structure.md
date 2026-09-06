# Worktree構成

## 基本方針

対象リポジトリは**すべてのエージェントに横並びで展開する**。
BE / FE / インフラなどリポジトリが分かれていても、各エージェントが
`repos/` 配下を横断的に読めるようにするため。

```
<agent>/repos/
├── <repo-a>/
├── <repo-b>/
└── <repo-c>/
```

リポジトリ名・階層は `repos.conf` の定義に従う。
カテゴリで分けたい場合は `repos.conf` の name に `be/api` のようにスラッシュを含める。

## ディレクトリ一覧

| ディレクトリ | 用途 | 制約 |
|---|---|---|
| `dev/slot-N/repos/` | 開発・PR作成（スロットN） | Write / commit / push 可 |
| `investigate/repos/` | 調査・壁打ち専用 | 読み取りのみ（Write / Edit / commit 不可） |
| `review/repos/` | PRレビュー専用 | 読み取りのみ（Write / Edit / commit 不可） |
| `knowledge/` | ドメイン・運用知識管理エージェント（worktreeではない）。問い合わせ応答・提案受け取り・定期振り返りを担う | `domain/` `operations/` への書き込み可 |
| `ops/` | 環境運用・エージェント間改善管理（worktreeではない） | cross-cutting改修可・agent-internalは提案のみ |
| `.bare/` | 各リポジトリの bare clone。worktree の供給元 | 直接触らない |

## worktree の運用

- すべて **detached HEAD** で作成される
  - 同一ブランチを複数 worktree で同時 checkout できない git の制約を回避するため
- dev で作業する際は、対象リポジトリの `repos/<name>/` で作業ブランチを切ること
- リポジトリを追加する場合は `repos.conf` に追記して `./setup.sh` を再実行する（冪等）
