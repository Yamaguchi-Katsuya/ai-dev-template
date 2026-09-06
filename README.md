# AI開発環境テンプレート

Claude Code を複数の専門エージェントとして並列運用するための開発環境を、
対話形式で自動生成するツール。

## 設計方針

このテンプレートが持つのは **エージェントの役割分担とディレクトリの骨格だけ**。

言語・フレームワーク・ビルドコマンド・ブランチ運用・ドメイン構造といった
案件固有の情報は一切含まない。案件ごとの差異をテンプレートで吸収するのは不可能なため、
それらは生成後に **AI が実リポジトリを読み取って自分で埋める**（`/bootstrap`）。

そのため BE が PHP・FE が React、リポジトリが複数に分かれている、といった構成でもそのまま使える。

## Quick Start

```bash
git clone <this-repo>
cd ai-dev-template
./init.sh
```

対話で聞かれるのは3つだけ。

1. プロジェクト名
2. 生成先パス
3. 開発スロット数

生成後の流れ:

```bash
cd /path/to/generated-project

vi repos.conf      # 対象リポジトリを記入（name / clone-url / base-branch）
./setup.sh         # bare clone + 全エージェントへ worktree 展開（冪等）

claude             # プロジェクトルートで起動
> /bootstrap       # AI が repos/ を読んで各 CLAUDE.md を案件仕様で埋める
```

## リポジトリの扱い

対象リポジトリは `.bare/<name>.git` に bare clone され、そこから各エージェント配下の
`repos/<name>/` に worktree として展開される。

```
<project>/
├── .bare/be-api.git          # bare clone（worktreeの供給元）
├── dev/slot-1/repos/be-api/  # worktree
├── dev/slot-2/repos/be-api/  # worktree
├── investigate/repos/be-api/ # worktree
└── review/repos/be-api/      # worktree
```

**全エージェントに全リポジトリを横並びで展開する。**
BE / FE / インフラが分かれていても、AI が横断的に参照できるようにするため。

worktree はすべて detached HEAD で作成される（同一ブランチの重複 checkout を避けるため）。
dev で作業する際は `repos/<name>/` で作業ブランチを切ること。

リポジトリを後から追加する場合は `repos.conf` に追記して `./setup.sh` を再実行するだけでよい。

`repos/` 配下をカテゴリで分けたい場合は、`repos.conf` の name にスラッシュを含める:

```
be/api    git@github.com:acme/be-api.git    develop
fe/web    git@github.com:acme/fe-web.git    main
infra     git@github.com:acme/infra.git     master
```

## 生成されるディレクトリ構成

```
<project>/
├── CLAUDE.md                          # 共通設定（全エージェントに適用）
├── repos.conf                         # 対象リポジトリ定義
├── setup.sh                           # bare clone + worktree 展開
├── .gitignore
├── .bare/                             # bare clone 置き場（git管理外）
├── .claude/
│   ├── commands/bootstrap.md          # 案件仕様をAIに書かせるコマンド
│   └── settings.local.json.example    # 環境変数テンプレート
├── docs/
│   ├── environment-overview.md        # エージェント構成・開発フロー
│   ├── worktree-structure.md          # Worktree構成詳細
│   ├── branch-structure.md            # ブランチ構成（bootstrapで生成）
│   └── planning.md                    # Planning規約
├── dev/
│   ├── CLAUDE.md
│   ├── slot-setup-guide.md
│   ├── slot-1/{CLAUDE.md, repos/}     # 開発スロット1
│   └── slot-2/{CLAUDE.md, repos/}     # 開発スロット2
├── investigate/
│   ├── CLAUDE.md
│   ├── investigation-guide.md
│   ├── repos/                         # 調査用worktree（読み取り専用）
│   ├── investigations/                # 調査結果
│   ├── planning/                      # 計画ドキュメント
│   └── tips/                          # Tips蓄積
├── review/
│   ├── CLAUDE.md
│   ├── review-guidelines.md
│   ├── repos/                         # レビュー用worktree（読み取り専用）
│   └── handoffs/                      # レビュー引き継ぎ
├── knowledge/
│   ├── CLAUDE.md
│   ├── domain/                        # ドメイン知識
│   │   └── _temp/
│   └── operations/                    # 運用知識
└── ops/
    ├── CLAUDE.md
    └── proposals/                     # 改善提案
```

## エージェント構成

| エージェント | 役割 | 書き込み権限 |
|---|---|---|
| dev/slot-N | 実装・PR作成（並行タスク対応） | `repos/` への Write / commit / push 可 |
| investigate | コード調査・壁打ち | 読み取りのみ（`planning/` `investigations/` `tips/` は書き込み可） |
| review | PRレビュー | 読み取りのみ |
| knowledge | ドメイン・運用知識の管理 | `domain/` `operations/` への書き込み可 |
| ops | 環境運用・改善管理 | cross-cutting な設定変更可 |

## テンプレート変数一覧

案件固有の値は AI に埋めさせる方針のため、置換されるのはスカラー値の3つだけ。

| 変数 | 説明 | 例 |
|---|---|---|
| `{{PROJECT_NAME}}` | プロジェクト名 | `acme-shop` |
| `{{PROJECT_ROOT}}` | 生成先の絶対パス | `/Users/foo/workspace/client/acme/acme-shop` |
| `{{SLOT_NUM}}` | スロット番号（`dev/slot-N/` 内でのみ有効） | `1` |

## テンプレートのカスタマイズ

`template/` ディレクトリ内のファイルを編集する。

- `.tmpl` 拡張子のファイル: 変数置換が行われ、拡張子を除いた名前で出力される
- それ以外のファイル: そのままコピーされる
- `template/dev/slot-N/` 配下: スロット数ぶん複製され、`{{SLOT_NUM}}` が置換される

新しいテンプレートファイルを追加すれば、自動的に生成対象に含まれる。
空ディレクトリを生成させたい場合は `.gitkeep` を置くこと。
