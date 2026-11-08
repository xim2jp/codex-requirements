#!/bin/bash
# setup.sh - RFP Requirements Framework 初期セットアップ（構想 → RFP → 要件定義＋Office 納品物）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# バージョンは .framework-version（正本: templates/project-init/.framework-version）から動的に読む。
# - new-project.sh 経由（FRAMEWORK_BOOTSTRAP=1）: カレントに配置済みの .framework-version を読む
# - standalone 実行: setup.sh と同じ場所（テンプレートディレクトリ）の .framework-version を読む
if [ -f ".framework-version" ]; then
  FRAMEWORK_VERSION=$(head -n 1 .framework-version | tr -d ' ')
elif [ -f "$SCRIPT_DIR/.framework-version" ]; then
  FRAMEWORK_VERSION=$(head -n 1 "$SCRIPT_DIR/.framework-version" | tr -d ' ')
else
  FRAMEWORK_VERSION="unknown"
fi

echo "🚀 RFP Requirements Framework セットアップ"
echo "   バージョン: $FRAMEWORK_VERSION"
echo ""

# FRAMEWORK_BOOTSTRAP=1 が設定されているときは new-project.sh から呼ばれており、ファイル配置は完了している。
if [ -z "$FRAMEWORK_BOOTSTRAP" ]; then
  if [ -d ".agents/skills" ] || [ -d ".codex/agents" ]; then
    echo "⚠️  既存の .agents/ または .codex/ が見つかりました"
    read -p "バックアップして上書きしますか？ (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
      b=".framework.backup.$(date +%Y%m%d_%H%M%S)"; mkdir -p "$b"
      for d in .agents .codex; do [ -d "$d" ] && mv "$d" "$b"/; done
      echo "✅ バックアップ完了（$b）"
    else
      echo "❌ セットアップを中止しました"
      exit 1
    fi
  fi

  # .agents/ と .codex/ の場所を探す（standalone で setup.sh を置いた場合の親探索）
  SRC=""
  for c in "$SCRIPT_DIR/../.." "$SCRIPT_DIR/.."; do
    # $HOME 直下はユーザーのグローバル ~/.agents・~/.codex を誤コピーしてしまうため除外
    [ "$(cd "$c" && pwd)" = "$HOME" ] && continue
    if [ -d "$c/.agents/skills" ] && [ -d "$c/.codex/agents" ]; then SRC="$c"; break; fi
  done
  if [ -z "$SRC" ]; then
    echo "❌ .agents/ と .codex/ が見つかりません（FRAMEWORK_BOOTSTRAP=1 を付けて new-project.sh から実行してください）"
    exit 1
  fi
  cp -r "$SRC/.agents" "$SRC/.codex" ./
  echo "✅ .agents/ と .codex/ を配置"

  cp "$SCRIPT_DIR/AGENTS.md" ./
  cp "$SCRIPT_DIR/PROJECT_LEARNINGS.md" ./
  cp "$SCRIPT_DIR/.framework-version" ./
  mkdir -p scripts
  cp "$SCRIPT_DIR/scripts/gen-manifest.sh" scripts/ 2>/dev/null || true
  chmod +x scripts/gen-manifest.sh 2>/dev/null || true
  echo "✅ テンプレートファイル配置"
else
  echo "✅ ファイル配置はスキップ（new-project.sh から呼び出されたため）"
fi

# .codex-manifest（配布時ハッシュ台帳）— bootstrap/standalone 両モードで生成
if [ -d ".agents" ] && [ -d ".codex" ] && [ ! -f ".codex-manifest" ]; then
  if [ -f "scripts/gen-manifest.sh" ]; then
    bash scripts/gen-manifest.sh
  else
    {
      echo "# .codex-manifest — フレームワーク配布ファイルのハッシュ台帳（compatibility-contract.md 準拠）"
      echo "# update-project.sh がカスタマイズ検出（3分類）に使用する。手動編集しない"
      echo "version: $FRAMEWORK_VERSION"
      find .agents .codex -type f | LC_ALL=C sort | xargs -d '\n' sha256sum
    } > .codex-manifest
    echo "✅ .codex-manifest を生成"
  fi
fi

# docs/ 構造
echo ""
echo "📁 docs/ 構造を初期化..."
mkdir -p docs/{00-inputs/materials,01-rfp/extracted,01-rfp/reviews,03-requirements/reviews,04-deliverables/reviews,99-pm} deliverables tmp
for dir in docs/00-inputs/materials docs/01-rfp docs/03-requirements docs/04-deliverables docs/99-pm deliverables; do
  touch "$dir/.gitkeep"
done
echo "✅ docs/ 構造作成完了"

# docs/00-inputs/README.md（RFP の置き方）
if [ ! -f "docs/00-inputs/README.md" ]; then
  cat > docs/00-inputs/README.md << 'EOF2'
# docs/00-inputs/ — 資料の置き場（なくても始められます）

**何も用意しなくて大丈夫です。** このフォルダで Codex（codex コマンド）を起動して、作りたいシステムのことを思いつくままに話しかけてください（例：「美容室の予約をスマホで受けられるようにしたい。今は電話と紙の台帳で…」）。質問に答えていくと、こちらで「依頼内容のまとめ（RFP）」を作り、そこから要件定義書などの書類を作ります。

ここ（`docs/00-inputs/`）は、**手元に資料があれば置く場所**です。置いた資料は読むだけで、書き換えません。

| 置けるもの | 例 | 必須か |
|-----------|----|--------|
| 構想のメモ | 作りたいもののメモ、手書きのスケッチの写真、参考にしたいサービスの URL | 任意 |
| 今の業務の資料 | 使っている Excel・紙の帳票の写真・業務の手順書 | 任意。あると話が早くなります |
| すでに RFP（提案依頼書）がある場合 | `rfp.docx` / `rfp.pdf` など | 任意。あれば、それをもとに進めます |

- Word・Excel・PowerPoint・PDF・画像のまま置けます
- 置いたら Codex に「資料を置きました」と一言伝えてください

できあがる書類（`deliverables/` フォルダ）：要件定義要求書（RFP）・要件定義書・付録文書（Word）、要件一覧（Excel）、要件定義サマリー（PowerPoint）
EOF2
  echo "✅ docs/00-inputs/README.md 配置"
fi

# 成果物プロファイルの雛形（文書情報は Phase 1 完了時に PM が確認して埋める）
if [ ! -f "docs/04-deliverables/deliverable-profile.yaml" ] && [ -f ".agents/skills/office-deliverables/templates/deliverable-profile.yaml" ]; then
  cp .agents/skills/office-deliverables/templates/deliverable-profile.yaml docs/04-deliverables/deliverable-profile.yaml
  echo "✅ docs/04-deliverables/deliverable-profile.yaml（雛形）配置"
fi

# .gitignore
if [ -f ".gitignore" ]; then
  if ! grep -q "tmp/" .gitignore; then
    cat >> .gitignore << 'EOF'

# Codex framework
tmp/
.venv/
.framework.backup.*/
EOF
    echo "✅ .gitignore 更新"
  fi
else
  cat > .gitignore << 'EOF'
.venv/
__pycache__/
tmp/
.env
.DS_Store
Thumbs.db
~$*
.vscode/
.idea/
.framework.backup.*/
EOF
  echo "✅ .gitignore 作成"
fi

# Python 環境（Office 納品物の生成・RFP 原本のテキスト化）
REQS=".agents/skills/office-deliverables/scripts/requirements.txt"
if [ -f "$REQS" ] && [ -z "$SKIP_VENV" ]; then   # SKIP_VENV=1：配布キット作成時（初回の build.sh が作る）
  echo ""
  echo "🐍 Office 生成用の Python 環境（.venv）を準備..."
  if [ ! -x ".venv/bin/python" ]; then
    if command -v uv >/dev/null 2>&1; then uv venv -q .venv; else python3 -m venv .venv; fi
  fi
  if command -v uv >/dev/null 2>&1; then
    uv pip install -q --python .venv/bin/python -r "$REQS" && echo "✅ .venv に依存ライブラリを導入（uv）" || echo "⚠️  依存の導入に失敗。後で build.sh が再試行します"
  else
    .venv/bin/python -m pip install -q -r "$REQS" && echo "✅ .venv に依存ライブラリを導入（pip）" || echo "⚠️  依存の導入に失敗。後で build.sh が再試行します"
  fi
  command -v mmdc >/dev/null 2>&1 || echo "ℹ️  図（Mermaid）を Word に画像で載せるには: npm i -g @mermaid-js/mermaid-cli（任意）"
fi

# status.md
TODAY=$(date +%Y-%m-%d)
if [ ! -f "docs/99-pm/status.md" ]; then
  cat > docs/99-pm/status.md << EOF
# プロジェクト進捗

- **プロジェクト名**: （未設定）
- **発注者**: （未設定）
- **開始日**: $TODAY
- **最終更新**: $TODAY
- **フレームワーク版**: $FRAMEWORK_VERSION
- **現在フェーズ**: Phase 0 / 5（構想の聞き取り待ち）
- **納品版数**: -
- **次のアクション**: Codex に作りたいシステムのことを話しかける（RFP があれば docs/00-inputs/ に置いて「RFP を置いたので始めて」）

## フェーズ別ステータス

| Phase | 名称 | ステータス | 担当 | 成果物 | Verdict | ループ | 完了日 |
|-------|------|----------|------|--------|---------|-------|--------|
| 0 | RFP 準備（構想 → RFP） | ⏳ | rfp-writer | docs/01-rfp/concept.md, docs/01-rfp/rfp.md | - | - | - |
| 1 | RFP 分析 | ⏳ | requirements-architect | docs/01-rfp/rfp-analysis.md, docs/00-inputs/INDEX.md | - | - | - |
| 2 | 要件定義 | ⏳ | requirements-architect | docs/03-requirements/ | - | - | - |
| 3 | 要件レビュー | ⏳ | requirements-reviewer | docs/03-requirements/reviews/ | - | - | - |
| 4 | Office 成果物作成 | ⏳ | office-document-producer | deliverables/（要件定義要求書・要件定義書・付録文書・要件一覧・要件定義サマリー）, docs/04-deliverables/ | - | - | - |
| 5 | 成果物レビュー | ⏳ | deliverable-reviewer | docs/04-deliverables/reviews/ | - | - | - |

## 凡例: ⏳ 待機 / 🚧 進行中 / 🔄 レビュー中 / 🔁 再レビュー / ⛔ Block / ✅ 完了 / ⚠️ エスカレーション / 📦 納品済
## 「ループ」列: レビュー実行回数/上限5回（rework-loop.md 準拠。Block は自動で修正ループ、5回超えで PM エスカレーション）

## 納品履歴

| 版数 | 納品日 | 内容 | 発注者の反応 |
|------|--------|------|-------------|

## 未決事項（OQ）の推移

| 日付 | open | answered | closed | 備考 |
|------|------|----------|--------|------|

## エスカレーション履歴
（なし）

## リスク・課題
| ID | 内容 | 発生Phase | 影響 | 対応状況 |
|----|------|----------|------|---------|

## 意思決定ログ
（PM判断を記録）

## 還流ループ記録
| 日付 | アクション | 詳細 |
|------|----------|------|
| $TODAY | フレームワーク導入 | $FRAMEWORK_VERSION からスタート |
EOF
  echo "✅ docs/99-pm/status.md 初期化"
fi

# プロジェクト名入力
echo ""
echo "📝 プロジェクト情報を入力してください（後で編集可）"
read -p "プロジェクト名: " project_name || true
if [ -n "$project_name" ]; then
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "s/<案件名をここに>/$project_name/" PROJECT_LEARNINGS.md
    sed -i "s/^- \*\*プロジェクト名\*\*: （未設定）/- **プロジェクト名**: $project_name/" docs/99-pm/status.md
  else
    sed -i "" "s/<案件名をここに>/$project_name/" PROJECT_LEARNINGS.md
    sed -i "" "s/^- \*\*プロジェクト名\*\*: （未設定）/- **プロジェクト名**: $project_name/" docs/99-pm/status.md
  fi
  echo "✅ PROJECT_LEARNINGS.md / status.md 更新"
fi

echo ""
echo "🎉 セットアップ完了！"
echo ""
echo "📂 配置されたファイル:"
echo "  - .agents/ .codex/          フレームワーク本体（4 Skill ＋ 6 サブエージェント・hooks）"
echo "  - .framework-version        $FRAMEWORK_VERSION"
echo "  - AGENTS.md                 Codex が常時読む指示（PM 役）"
echo "  - PROJECT_LEARNINGS.md      案件知見の記録"
echo "  - docs/00-inputs/           資料があれば置く場所（なくても始められます）"
echo "  - deliverables/             できあがる書類（Word・Excel・PowerPoint）"
echo ""
echo "🚀 次のステップ:"
echo "  1. このフォルダで codex を起動"
echo "  2. 作りたいシステムのことを話しかける（例：「予約をスマホで受けられるようにしたい」）"
echo "     RFP がすでにあれば docs/00-inputs/ に置いて「RFP を置いたので始めて」"
echo ""
echo "💡 気付きは PROJECT_LEARNINGS.md にその日のうちに記録し、月次で本体へ還流"
