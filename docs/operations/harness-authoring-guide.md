# ハーネス執筆ガイド（Codex 版：agents / skills / hooks / MCP）

このフレームワークの `.codex/`（サブエージェント・フック）と `.agents/`（スキル）は、OpenAI Codex の **GPT-6 世代**（`gpt-6.1-sol`・`gpt-6-luna` など）を前提に書く。旧世代向けの「手順を一歩ずつ指示し、禁止事項を繰り返して縛る」書き方は捨て、**役割・入出力・品質基準・判断の軸**を簡潔に渡す。モデルは与えられた目的と制約から手順を自分で組める。この文書は、エージェント定義と Skill を新設・改訂するときの正本である。

## 1. 設計原則

1. **一度だけ書く**。全エージェント共通の作法（成果物の置き場、Handoff、Self-Check、Verdict、修正ループ、オーナー制約）は `sdlc-toolkit/SKILL.md` にだけ書き、各エージェントは `developer_instructions` 冒頭の「最初に読むもの」で読み込む。エージェント本文で共通作法を再説明しない。
2. **意図と不変条件を書き、手順は書かない**。「第 1 パスで A、第 2 パスで B」のような段取りは不要。何を達成するか、何が満たされていなければ Block か、どこで迷ったら誰に聞くか、を書く。
3. **機械で守れることは hooks で守る**。`docs/00-inputs/` の読み取り専用、レビューレポートの Verdict ブロック必須、は `.codex/hooks.json` の hooks が強制・検査する。プロンプトで「絶対禁止」を繰り返さない。
4. **履歴を書かない**。「v0.8.0 で追加」のような版数注記は CHANGELOG の仕事。プロンプトには現在の仕様だけを書く。
5. **描写は短く、判断材料は厚く**。ドメインのチェック観点・Block 条件・固有ノウハウは残す。言い換え・強調・重複は削る。
6. **モデルは役割で使い分ける**。推論の深さが成果物の質を決める本筋（RFP 作成・RFP 分析と要件定義・PM）は `gpt-6.1-sol`／`model_reasoning_effort = "high"`、点検役（`*-reviewer`）は `gpt-6.1-sol`／`medium`、手を動かす作業役（Office 生成：スクリプト実行・設定ファイル記入・体裁確認）は `gpt-6-luna`／`low`。モデル ID は Codex のモデル一覧に合わせ、新しい世代が出たら書き換える（`check-harness.sh` の期待値も合わせる）。全部を親セッションと同じモデルで動かしたい案件は、案件側で `model` と `model_reasoning_effort` の行を消す（親の値を受け継ぐ）。
7. **信頼する**。モデルは文脈を読み、必要な参照を自分で開く。「必読」「必ず Read」は、読まないと成果物が壊れる入力に限って書く。

## 2. エージェント定義のテンプレート

`.codex/agents/<name>.toml`（1 ファイル 1 エージェント）。本文は `developer_instructions` に Markdown で書く（TOML の複数行リテラル `'''…'''`。本文に `'''` を書かない）。

```toml
name = "<kebab-case。ファイル名と一致。改名は破壊的変更>"
description = "<1〜3 文、300 字以内。何をする／いつ使う／起動語。版数注記を書かない>"
model = "<gpt-6.1-sol（本筋・点検役）／gpt-6-luna（作業役）。§1-6>"
model_reasoning_effort = "<high（本筋）／medium（点検役）／low（作業役）>"
developer_instructions = '''
> **最初に読むもの**（作業前に読む）：`.agents/skills/sdlc-toolkit/SKILL.md`、`.agents/skills/<ドメイン Skill>/SKILL.md`
> - **使ってよい操作**：<レビュワーなど制限が必要な場合のみ>

# <役割名>

<1〜3 段落：この役割は何に責任を持ち、どんな姿勢で臨むか。設計者としての裁量と、上流を勝手に変えない線引き>
'''

## 入力
<読むべき成果物のパス。判断の根拠になる正本（RFP 原本・rfp-analysis・requirements）と、自フェーズの直接入力>

## 成果物
<出力パスと、その文書の骨子（見出しレベルの構成）。テンプレが Skill にあればパスだけ>

## 品質基準
<この役割の成果物が満たすべきこと。レビュワーなら Block / Major の判定条件。producer なら Self-Check 項目になる観点>

## 判断の軸
<裁量を発揮する場面と、ユーザーや PM に確認すべき場面。運用者（受注側）固有の制約がこの役割でどう効くか>

## 連携
<誰から受け取り、誰に渡すか。Handoff の Next suggested agent(s)>
```

目安：**150 行・8KB 以内**。超えるなら、知識部分を Skill の references に移す。

### 書いてよいこと／書かないこと

| 書く | 書かない |
|------|---------|
| 成果物パス（安定 API） | 共通作法の再説明（Handoff / Self-Check / Verdict の書式） |
| ドメインのチェック観点・Block 条件 | 「第 N パス」などの実行手順 |
| 固有ノウハウ（Stripe の端数処理、LIFF の制約など） | 版数注記（v0.x で追加） |
| 判断の軸・トレードオフ | 「必読」「絶対禁止」の反復 |
| 連携先エージェント名 | 他エージェントの責務の説明 |

### 項目の決め方

- `model` / `model_reasoning_effort` は役割で決める（§1-6）。`check-harness.sh` が役割との一致を検査する
- Codex のカスタムエージェントで効く項目は `name`・`description`・`developer_instructions`・`model`・`model_reasoning_effort`・`model_reasoning_summary`・`model_verbosity`・`features`・`skills` だけ。`sandbox_mode`・`mcp_servers`・`approval_policy` は書いても親を上書きしない（`check-harness.sh` が警告）
- サブエージェントは親のスキルを受け継ぐが、確実に読ませるため「最初に読むもの」に `sdlc-toolkit` を必ず書く（`check-harness.sh` が検査）。ドメイン Skill は 1〜2 本まで。SKILL.md は 150 行以内に保つ
- レビュワーを個別に読み取り専用にはできない（サンドボックスは親を受け継ぐ）。操作の制限は「使ってよい操作」に書き、守れない操作は hooks で止める
- Codex は明示の指示があるときだけサブエージェントを起動する。PM がどのフェーズでどのエージェントを起動するかを `AGENTS.md` に書く（案件テンプレート `templates/project-init/AGENTS.md`）

## 3. Skill のテンプレート

```markdown
---
name: <kebab-case。ディレクトリ名と一致>
description: <何の知識集か＋どの場面で参照するか＋起動語。400 字以内>
---

# <Skill 名>

<2〜3 段落：この領域で一貫して守る原則。運用者固有の判断があればここ>

## 参照ファイル
| ファイル | 内容 | いつ読むか |

## 原則
<番号付き、1 項目 1〜2 行。各項目は「なぜ」を含む>

## アンチパターン
<箇条書き。実際に起きた失敗を優先>
```

- SKILL.md は **500 行以内**。深い知識は `references/`、雛形は `templates/`、実行物は `scripts/` に置く
- 「エージェント別の使い方ガイド」節は書かない（各エージェント定義が自分の入出力を知っている。重複は乖離の元）
- Codex は最初に `name`・`description` だけを読み、使うと決めたときに SKILL.md 全体を読む。description に「いつ使うか」を具体的に書く
- 表示名や暗黙の起動の可否は、スキルの `agents/openai.yaml`（`interface`・`policy.allow_implicit_invocation`）で決められる

## 4. hooks（機械で守る不変条件）

`.codex/hooks.json` に登録。スクリプトは `.codex/hooks/` に置く。フックはセッションの作業フォルダで実行されるので、`$(git rev-parse --show-toplevel)` でリポジトリのルートから参照する。入力は標準入力の JSON（`cwd`・`tool_name`・`tool_input` など）。プロジェクトのフックは、フォルダを信頼し、`/hooks` で内容を承認したときだけ動く（内容を変えたら再承認）。

| hook | 守る不変条件 | 挙動 |
|------|------------|------|
| `guard-inputs.sh`（`PreToolUse`、matcher `apply_patch\|Edit\|Write`） | `docs/00-inputs/` は INDEX.md 以外書き換え禁止。`deliverables/`（Office 納品物）と `docs/01-rfp/extracted/` は生成物なので手書き禁止 | パッチ本文の `*** Add/Update/Delete File:`・`*** Move to:` と `file_path` から対象を取り、`permissionDecision: "deny"` で拒否し理由を返す。シェル（`build.sh`）は止めない |
| `check-review-report.sh`（`Stop`・`SubagentStop`） | 直近 120 分に書かれた `reviews/*-loopN.md` に Verdict ブロック 4 行が揃っている | 欠けていれば `decision: "block"` の `reason` で続行させ書き直しを促す。`stop_hook_active` が true のときは止めない（無限ループ防止） |

hooks は依存ゼロの bash で書く。新しい不変条件を足すときは「プロンプトで言い続けるより hook で守れるか」を先に考える。

## 5. MCP サーバー

- 常時接続は増やさない（ツール定義がコンテキストを食う）。登録は作業単位で付け外す
- 案件に配布する雛形は `templates/project-init/config.toml.example`（`[mcp_servers.<名前>]`）。案件の `.codex/config.toml` に必要なものだけ写す。トークンは `env_vars`・`bearer_token_env_var` で環境変数から読み、コミットしない
- サブエージェントは親の MCP 設定を受け継ぐ（カスタムエージェントの `mcp_servers` は効かない）
- 要件定義では原則 MCP を常用しない。RFP・参考資料がクラウドストレージにある場合だけ、そのコネクタを付ける

## 6. 配布

Codex 版は plugin 配布を持たない。コピー配布（`new-project.sh`・`update-project.sh`・`export-to-projects.sh`）と ZIP キット（`build-kit.sh`）で配る。配布単位は `.agents/`・`.codex/` 全体。案件側の `.codex/config.toml`（MCP など）は配布物に含めず、更新でも上書きしない。

## 7. 改訂時のチェック

`bash scripts/check-harness.sh` がエージェント TOML・Skill frontmatter の必須項目、office-deliverables スクリプトの存在と構文、エージェント TOML の読み込み・必須項目、役割ごとの `model`／`model_reasoning_effort`、「最初に読むもの」の `sdlc-toolkit`、Codex で効かない項目、hooks.json の登録、description 長、版数注記の残存、サイズ超過、rework-loop の差し戻し先の実在を検査する。`scripts/check-layout-drift.sh`、`scripts/smoke-test.sh`（new-project → setup → Office 生成の通し確認）と合わせて CI で走る。Office 生成スクリプトを変えたら smoke-test に加えて、実際の Word / Excel / PowerPoint で開いて PDF 化し、ページ画像で崩れを確認する（`office-deliverables/references/office-style-guide.md` §5）。
