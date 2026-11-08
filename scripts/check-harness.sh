#!/bin/bash
# check-harness.sh - エージェント / Skill 定義がハーネス執筆ガイド（docs/operations/harness-authoring-guide.md）に沿っているかを検査する。
# CI（framework-checks.yml）から実行。失敗は exit 1。警告は exit 0。
# 使い方: bash scripts/check-harness.sh [--strict]（--strict で警告も失敗扱い）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS="$ROOT/.codex/agents"
SKILLS="$ROOT/.agents/skills"
STRICT=0; [ "$1" = "--strict" ] && STRICT=1
ERR=0; WARN=0
err()  { echo "❌ $1"; ERR=$((ERR+1)); }
warn() { echo "⚠️  $1"; WARN=$((WARN+1)); }

frontmatter() { awk 'NR==1{if($0!="---"){exit 1}; next} /^---$/{exit} {print}' "$1"; }
field() { frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n1; }

echo "🔍 ハーネス検査"
echo ""
echo "── agents（Codex カスタムエージェント .codex/agents/*.toml）"
# TOML は Python 3.11+ の tomllib で読む。1 行 1 項目（base<TAB>key<TAB>value）に展開して bash で検査する
PYTOML=$(command -v python3)
if [ -z "$PYTOML" ] || ! "$PYTOML" -c 'import tomllib' 2>/dev/null; then
  err "agents の検査には Python 3.11+（tomllib）が必要"
else
  while IFS=$'\t' read -r base kind val; do
    case "$kind" in
      parse_error) err "$base: TOML として読めない（$val）" ;;
      missing) err "$base: 必須項目 $val が無い" ;;
      name) [ "$val" = "$base" ] || err "$base: name=$val がファイル名と一致しない" ;;
      desc_len) [ "$val" -le 400 ] || warn "$base: description が ${val} 字（目安 300、上限 400）" ;;
      model)
        # 役割ごとのモデル（harness-authoring-guide.md §1-6）：本筋 = gpt-6.1-sol/high、点検役 = gpt-6.1-sol/medium、作業役 = gpt-6-luna/low
        case "$base" in
          *-reviewer) want="gpt-6.1-sol/medium" ;;
          office-document-producer) want="gpt-6-luna/low" ;;
          *) want="gpt-6.1-sol/high" ;;
        esac
        [ "$val" = "$want" ] || warn "$base: model/effort が $want ではない（$val。役割ごとのモデルは harness-authoring-guide.md §1-6）" ;;
      unknown) warn "$base: Codex のカスタムエージェントで効かない項目 $val" ;;
      skill) [ -d "$SKILLS/$val" ] || err "$base: 存在しない Skill '$val' を参照" ;;
      no_sdlc) err "$base: 「最初に読むもの」に .agents/skills/sdlc-toolkit/SKILL.md が無い" ;;
      version_note) warn "$base: 版数注記 $val が残っている" ;;
      size) [ "$val" -le 10240 ] || warn "$base: ${val} bytes（目安 8KB、上限 10KB）" ;;
    esac
  done < <("$PYTOML" - "$AGENTS" <<'PY'
import sys, os, re, glob, tomllib
KNOWN = {"name","description","developer_instructions","model","model_reasoning_effort","model_reasoning_summary","model_verbosity","features","skills"}
for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.toml"))):
    base = os.path.basename(p)[:-5]
    out = lambda k, v="": print(f"{base}\t{k}\t{v}")
    try:
        d = tomllib.load(open(p, "rb"))
    except Exception as e:
        out("parse_error", str(e).replace("\t", " ")); continue
    for k in ("name", "description", "developer_instructions"):
        if not d.get(k): out("missing", k)
    out("name", d.get("name", ""))
    out("desc_len", len(d.get("description", "")))
    out("model", f'{d.get("model","")}/{d.get("model_reasoning_effort","")}')
    for k in d:
        if k not in KNOWN: out("unknown", k)
    ins = d.get("developer_instructions", "")
    for s in sorted(set(re.findall(r"\.agents/skills/([a-z0-9-]+)/SKILL\.md", ins))): out("skill", s)
    if ".agents/skills/sdlc-toolkit/SKILL.md" not in ins: out("no_sdlc")
    v = sorted(set(re.findall(r"v0\.\d+(?:\.\d+)?", ins)))
    if v: out("version_note", " ".join(v))
    out("size", os.path.getsize(p))
PY
)
fi
ls "$AGENTS"/*.md >/dev/null 2>&1 && warn ".codex/agents/ に .md が残っている（Codex は .toml だけを読む）"

echo "── skills"
for f in "$SKILLS"/*/SKILL.md; do
  dir=$(basename "$(dirname "$f")")
  if ! frontmatter "$f" >/dev/null 2>&1 || [ -z "$(frontmatter "$f")" ]; then err "$dir: frontmatter が無い"; continue; fi
  name=$(field "$f" name); desc=$(field "$f" description)
  [ "$name" = "$dir" ] || err "$dir: name:$name がディレクトリ名と一致しない"
  dlen=$(printf '%s' "$desc" | wc -m)
  [ "$dlen" -le 500 ] || warn "$dir: description が ${dlen} 字（上限 400 目安）"
  lines=$(wc -l < "$f")
  [ "$lines" -le 500 ] || warn "$dir: SKILL.md が ${lines} 行（上限 500）"
  grep -qE 'v0\.[0-9]+(\.[0-9]+)?' "$f" && warn "$dir: SKILL.md に版数注記が残っている"
done

echo "── 差し戻し先・連携先の実在（rework-loop.md / pm-playbook.md）"
for ref in "$SKILLS/sdlc-toolkit/references/rework-loop.md" "$SKILLS/sdlc-toolkit/references/pm-playbook.md"; do
  for a in $(grep -oE '[a-z0-9]+(-[a-z0-9]+)+' "$ref" | sort -u); do
    case "$a" in *-*-*|*-*) ;; *) continue;; esac
    # エージェント名らしい語（既知のサフィックス）だけ検査
    echo "$a" | grep -qE '(-planner|-reviewer|-strategist|-architect|-designer|-builder|-director|-specialist|-worker|-tester|-auditor|-analyst|-facilitator|-generator|-producer|-guardian|-adversary|-manager)$' || continue
    [ -f "$AGENTS/$a.toml" ] || err "$(basename "$ref"): 存在しないエージェント '$a' を参照"
  done
done

echo "── office-deliverables スクリプト"
OD="$SKILLS/office-deliverables/scripts"
for f in build.sh office_build.py extract_inputs.py docx_builder.py xlsx_builder.py pptx_builder.py check.py mdparse.py profile.py common.py requirements.txt; do
  [ -f "$OD/$f" ] || err "office-deliverables/scripts/$f が無い"
done
[ -x "$OD/build.sh" ] || err "office-deliverables/scripts/build.sh に実行権限が無い"
command -v python3 >/dev/null && for f in "$OD"/*.py; do python3 -m py_compile "$f" 2>/dev/null || err "$(basename "$f") に構文エラー"; done

echo "── hooks"
[ -f "$ROOT/.codex/hooks.json" ] || err ".codex/hooks.json が無い"
for h in guard-inputs.sh check-review-report.sh; do
  [ -x "$ROOT/.codex/hooks/$h" ] || err ".codex/hooks/$h が無いか実行権限が無い"
done
command -v jq >/dev/null && { jq empty "$ROOT/.codex/hooks.json" 2>/dev/null || err "hooks.json が不正な JSON"; }
for h in guard-inputs.sh check-review-report.sh; do
  grep -q ".codex/hooks/$h" "$ROOT/.codex/hooks.json" 2>/dev/null || err "hooks.json に $h の登録が無い"
done
[ -d "$ROOT/.claude" ] && warn ".claude/ が残っている（Codex 版では使わない）"

echo ""
echo "結果: エラー $ERR 件 / 警告 $WARN 件"
[ "$ERR" -gt 0 ] && exit 1
[ "$STRICT" = "1" ] && [ "$WARN" -gt 0 ] && exit 1
exit 0
