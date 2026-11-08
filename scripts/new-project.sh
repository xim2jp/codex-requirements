#!/bin/bash
# new-project.sh - 新規の要件定義案件を作る補助スクリプト
# 使い方: bash scripts/new-project.sh ~/projects/my-rfp-project

set -e

if [ -z "$1" ]; then
  echo "使い方: bash scripts/new-project.sh <新規プロジェクトのパス>"
  echo "例: bash scripts/new-project.sh ~/projects/acme-order-system"
  exit 1
fi

TARGET_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 新規の要件定義案件を作成"
echo "  ターゲット: $TARGET_PATH"
echo ""

# 既存ディレクトリチェック
if [ -e "$TARGET_PATH" ]; then
  echo "⚠️  $TARGET_PATH は既に存在します"
  read -p "中断しますか？ (Y/n): " confirm
  if [[ ! $confirm == [nN] ]]; then
    exit 1
  fi
fi

# ディレクトリ作成
mkdir -p "$TARGET_PATH"
cd "$TARGET_PATH"

# フレームワークから .agents/（スキル）と .codex/（サブエージェント・フック）をコピー
cp -r "$FRAMEWORK_ROOT/.agents" "$FRAMEWORK_ROOT/.codex" ./
echo "✅ .agents/ と .codex/ を配置"

# テンプレートをコピー
cp "$FRAMEWORK_ROOT/templates/project-init/AGENTS.md" ./
cp "$FRAMEWORK_ROOT/templates/project-init/PROJECT_LEARNINGS.md" ./
cp "$FRAMEWORK_ROOT/templates/project-init/.framework-version" ./
cp "$FRAMEWORK_ROOT/templates/project-init/setup.sh" ./
cp "$FRAMEWORK_ROOT/templates/project-init/config.toml.example" ./   # MCP 登録の雛形（必要なものだけ .codex/config.toml にコピーして使う）
chmod +x setup.sh
echo "✅ テンプレートファイル配置"

# スクリプト（マニフェスト生成）
mkdir -p scripts
cp "$FRAMEWORK_ROOT/templates/project-init/scripts/gen-manifest.sh" scripts/
chmod +x scripts/gen-manifest.sh
echo "✅ scripts/gen-manifest.sh 配置"

# setup.sh は本体から独立して動かすため、フレームワーク本体のコピーを参照しないバージョンを書き出す
# （setup.sh内で .agents/・.codex/ の場所を探す処理は既に対応済み）

# セットアップスクリプト実行
# FRAMEWORK_BOOTSTRAP=1 を付けることで setup.sh 内のファイル再配置（同一ファイルcpエラーや
# ~/.agents・~/.codex 誤コピーの危険）をスキップし、docs/ 構造や status.md などの初期化のみを行う。
FRAMEWORK_BOOTSTRAP=1 bash setup.sh

echo ""
echo "🎉 新規案件 '$TARGET_PATH' の準備完了"
echo ""
echo "次のステップ:"
echo "  cd $TARGET_PATH"
echo "  git init"
echo "  git add ."
echo "  git commit -m 'Initial: framework $(cat $TARGET_PATH/.framework-version)'"
echo "  # リモートを設定して push"
echo ""
echo "  docs/00-inputs/ に RFP を置き、このフォルダで codex を起動して「RFP を置いたので始めて」"
echo ""

# フレームワーク本体の案件レジストリにエントリ追加候補を表示
PROJECT_NAME="$(basename $TARGET_PATH)"
echo "📋 フレームワーク本体の案件レジストリに以下を追加することを推奨:"
echo ""
echo "  docs/projects/INDEX.md に追記:"
echo "  | $PROJECT_NAME | $(cat $TARGET_PATH/.framework-version) | $(date +%Y-%m-%d) | - | アクティブ |"
echo ""
