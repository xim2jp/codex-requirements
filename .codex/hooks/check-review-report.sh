#!/usr/bin/env bash
# Stop / SubagentStop（Codex hooks）: 直近に書かれたレビューレポート（reviews/*-loopN.md）に
# 機械可読 Verdict ブロックが揃っているか検査する。欠けていれば decision: block の reason で書き直しを促す
# （PM がこのブロックを読んでループを回す）。対象は 120 分以内に更新されたレポートだけ。
# stop_hook_active が true（すでにこのフックで続行させた後）のときは、無限ループを避けて止めない。
input=$(cat)
printf '%s' "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && root=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
root="${root:-$PWD}"
[ -d "$root/docs" ] || exit 0

problems=""
while IFS= read -r f; do
  case "$f" in *-response-loop*) continue ;; esac   # producer の対応表は対象外
  missing=""
  for key in "VERDICT:" "LOOP:" "RETURN_TO:" "REPORT:"; do
    grep -q "^${key}" "$f" || missing="$missing $key"
  done
  if grep -q "^VERDICT:" "$f" && ! grep -Eq "^VERDICT:[[:space:]]*(BLOCK|WARNING|APPROVE)\b" "$f"; then
    missing="$missing VERDICT=BLOCK|WARNING|APPROVE"
  fi
  [ -n "$missing" ] && problems="$problems ${f#"$root"/}（欠落:${missing}）"
done < <(find "$root/docs" -path '*/reviews/*' -name '*-loop[0-9]*.md' -mmin -120 2>/dev/null)

[ -z "$problems" ] && exit 0
msg="レビューレポートの Verdict ブロックが不完全です:${problems}。末尾に VERDICT: / LOOP: N/5 / RETURN_TO: / REPORT: の 4 行を追記してください（sdlc-toolkit SKILL.md §5）。"
printf '{"decision":"block","reason":"%s"}\n' "$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
exit 0
