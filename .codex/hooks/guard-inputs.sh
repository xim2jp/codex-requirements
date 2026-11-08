#!/usr/bin/env bash
# PreToolUse（Codex hooks、matcher: apply_patch|Edit|Write）: 読み取り専用領域・生成物への手書きを拒否する。
#   - docs/00-inputs/ はユーザー持ち込み資料（RFP 原本）。INDEX.md と README.md 以外は書き換え不可
#   - deliverables/ は Office 納品物（office-deliverables の build.sh が Markdown 正本から生成）
#   - docs/01-rfp/extracted/ は RFP 原本のテキスト化（build.sh extract が生成）
# apply_patch はパッチ本文（tool_input.command）の「*** Add/Update/Delete File: パス」「*** Move to: パス」から、
# Edit / Write は tool_input.file_path からパスを取る。シェル（build.sh）は対象外。依存なし（sed / grep のみ）。
# 拒否は hookSpecificOutput.permissionDecision = "deny"。
input=$(cat)
root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && root=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
root="${root:-$PWD}"

paths=$(
  printf '%s' "$input" | grep -oE '\*\*\* (Add|Update|Delete) File: [^\\"]+|\*\*\* Move to: [^\\"]+' | sed -E 's/^\*\*\* [A-Za-z ]+: //'
  printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
)
[ -z "$paths" ] && exit 0

deny() {
  esc=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$esc"
  exit 0
}

while IFS= read -r path; do
  [ -z "$path" ] && continue
  path="${path%"${path##*[![:space:]]}"}"   # 末尾の空白を落とす
  rel="${path#"$root"/}"; rel="${rel#./}"
  case "$rel" in
    docs/00-inputs/INDEX.md|docs/00-inputs/README.md) ;;
    docs/00-inputs/*)
      deny "docs/00-inputs/ はユーザーの持ち込み資料（RFP 原本）で読み取り専用です（INDEX.md のみ更新可）。解釈や補足は docs/01-rfp/rfp-analysis.md と OQ に書いてください。" ;;
    deliverables/*)
      deny "deliverables/ は生成物です。内容は docs/03-requirements/ の Markdown、体裁は docs/04-deliverables/*.yaml を直し、bash .agents/skills/office-deliverables/scripts/build.sh all で再生成してください。" ;;
    docs/01-rfp/extracted/*)
      deny "docs/01-rfp/extracted/ は RFP 原本の機械抽出です。bash .agents/skills/office-deliverables/scripts/build.sh extract で再生成してください。" ;;
  esac
done <<< "$paths"
exit 0
