#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# AI開発環境テンプレート ジェネレーター
#
# テンプレートから新しいプロジェクトディレクトリを生成する。
#
# このスクリプトは「骨格」だけを作る。
# 案件固有の内容（言語・ビルドコマンド・ブランチ構成・ドメイン知識）は、
# 生成後に repos.conf を埋めて ./setup.sh を実行し、
# Claude Code で /bootstrap を走らせて AI に書かせる。
# ==================================================

# ── Colors ────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}── $* ──${NC}\n"; }

# ── Template dir auto-detection ───────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  error "テンプレートディレクトリが見つかりません: $TEMPLATE_DIR"
  exit 1
fi

# ==================================================
# Interactive questions
# ==================================================

header "AI開発環境テンプレート ジェネレーター"
echo "プロジェクトの情報を入力してください。"
echo ""

# 1. PROJECT_NAME
read -rp "$(echo -e "${BOLD}1.${NC} プロジェクト名 (例: acme-shop): ")" PROJECT_NAME
if [[ -z "$PROJECT_NAME" ]]; then
  error "プロジェクト名は必須です"
  exit 1
fi

# 2. OUTPUT_DIR
read -rp "$(echo -e "${BOLD}2.${NC} 生成先パス (例: ~/workspace/client/acme/${PROJECT_NAME}): ")" OUTPUT_DIR
if [[ -z "$OUTPUT_DIR" ]]; then
  error "生成先パスは必須です"
  exit 1
fi

# Expand ~ if used
OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

# Convert to absolute path.
# NOTE: 親ディレクトリが存在しない場合、以前は cd の失敗を握りつぶして
#       ルート直下（/name）になる不具合があったため、明示的に停止する。
if [[ "$OUTPUT_DIR" != /* ]]; then
  _parent="$(dirname "$OUTPUT_DIR")"
  if ! _abs_parent="$(cd "$_parent" 2>/dev/null && pwd)"; then
    error "生成先の親ディレクトリが存在しません: $_parent"
    error "絶対パスで指定するか、先に親ディレクトリを作成してください"
    exit 1
  fi
  OUTPUT_DIR="$_abs_parent/$(basename "$OUTPUT_DIR")"
fi

# Check if output dir already exists (and is not empty)
if [[ -d "$OUTPUT_DIR" ]] && [[ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]]; then
  warn "生成先ディレクトリは既に存在し、空ではありません: $OUTPUT_DIR"
  warn "既存ファイルは削除されません。同名ファイルのみ上書きされます。"
  read -rp "続行しますか？ (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    info "中止しました"
    exit 0
  fi
fi

# 3. NUM_SLOTS
read -rp "$(echo -e "${BOLD}3.${NC} 開発スロット数 [2]: ")" NUM_SLOTS
if [[ -z "$NUM_SLOTS" ]]; then
  NUM_SLOTS=2
fi
if ! [[ "$NUM_SLOTS" =~ ^[0-9]+$ ]] || [[ "$NUM_SLOTS" -lt 1 ]]; then
  error "スロット数は1以上の整数で指定してください"
  exit 1
fi

# ==================================================
# Generate project
# ==================================================

header "プロジェクト生成中..."

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# ── Helper: escape a string for use as a sed replacement ──
# sed の置換文字列では \ と & 、区切り文字の | が特殊なのでエスケープする
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

E_PROJECT_NAME="$(sed_escape "$PROJECT_NAME")"
E_PROJECT_ROOT="$(sed_escape "$OUTPUT_DIR")"
E_NUM_SLOTS="$(sed_escape "$NUM_SLOTS")"

# ── Helper: replace template variables in a file ──
# 置換対象は単一行のスカラー値のみ。
# 複数行の埋め込み（サービス表・環境変数など）は行わない。
# それらは案件ごとに異なるため /bootstrap で AI に書かせる。
replace_vars() {
  local file="$1"
  local slot_num="${2:-}"
  local tmp="$TMPDIR_WORK/sed_tmp"

  sed \
    -e "s|{{PROJECT_NAME}}|${E_PROJECT_NAME}|g" \
    -e "s|{{PROJECT_ROOT}}|${E_PROJECT_ROOT}|g" \
    -e "s|{{NUM_SLOTS}}|${E_NUM_SLOTS}|g" \
    -e "s|{{SLOT_NUM}}|${slot_num}|g" \
    "$file" > "$tmp"
  mv "$tmp" "$file"
}

# ── Create output directory ───────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Copy and process template files ───────────────
cd "$TEMPLATE_DIR"

# slot-N/ はスロット数ぶん複製するので、ここでは対象外にする
while IFS= read -r src; do
  if [[ "$src" == *"/slot-N/"* ]]; then
    continue
  fi

  dest="$OUTPUT_DIR/$src"
  if [[ "$src" == *.tmpl ]]; then
    dest="${dest%.tmpl}"
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"

  rel="${dest#"$OUTPUT_DIR/"}"
  if [[ "$src" == *.tmpl ]]; then
    replace_vars "$dest"
    success "$rel (テンプレート展開)"
  else
    info "$rel (コピー)"
  fi
done < <(find . -type f)

# ── Make setup.sh executable ─────────────────────
if [[ -f "$OUTPUT_DIR/setup.sh" ]]; then
  chmod +x "$OUTPUT_DIR/setup.sh"
  success "setup.sh (実行権限付与)"
fi

# ── Create slot directories from the slot-N template ──
for i in $(seq 1 "$NUM_SLOTS"); do
  slot_dir="$OUTPUT_DIR/dev/slot-${i}"
  mkdir -p "$slot_dir/repos"

  while IFS= read -r src; do
    dest="$slot_dir/${src#./dev/slot-N/}"
    if [[ "$src" == *.tmpl ]]; then
      dest="${dest%.tmpl}"
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    if [[ "$src" == *.tmpl ]]; then
      replace_vars "$dest" "$i"
    fi
    success "dev/slot-${i}/${dest##*/}"
  done < <(find ./dev/slot-N -type f)
done

# ==================================================
# Summary
# ==================================================

header "生成完了!"

echo -e "${BOLD}プロジェクト:${NC} $PROJECT_NAME"
echo -e "${BOLD}生成先:${NC}     $OUTPUT_DIR"
echo ""

file_count=$(find "$OUTPUT_DIR" -type f | wc -l | tr -d ' ')
dir_count=$(find "$OUTPUT_DIR" -type d | wc -l | tr -d ' ')

if command -v tree &>/dev/null; then
  tree -a -L 3 --dirsfirst "$OUTPUT_DIR" | head -40
else
  find "$OUTPUT_DIR" -maxdepth 3 -print | sed "s|$OUTPUT_DIR|.|" | sort | head -40
fi

echo ""
echo -e "${GREEN}${BOLD}ファイル: ${file_count}個 / ディレクトリ: ${dir_count}個${NC}"
echo ""
echo -e "${BOLD}次のステップ:${NC}"
echo -e "  1. ${BOLD}cd $OUTPUT_DIR${NC}"
echo -e "  2. ${BOLD}repos.conf${NC} に対象リポジトリを記入"
echo -e "  3. ${BOLD}./setup.sh${NC}                ← bare clone + worktree 展開"
echo -e "  4. Claude Code を起動して ${BOLD}/bootstrap${NC}  ← AI が案件仕様を各 CLAUDE.md に反映"
echo ""
