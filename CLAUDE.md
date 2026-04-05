# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクトの目的

ゼロダウンタイムでミドルウェアを更新するオーケストレーション基盤。実務の SRE ワークフローを題材にしている。

```
脆弱性検知 → 更新計画 → 検証環境で更新 → 動作確認 → 商用ローリング更新 → 動作確認（→ 問題あれば切り戻し）
```

対象ミドルウェア: Nginx。Ansible で構成管理し、LB 配下の複数サーバに対してローリング更新を行う。

## 協働ルール（必須）

このプロジェクトはポートフォリオ作成と **Ansible 学習** を同時に進める。以下のルールは厳守する。

- **1ステップずつ進める** — 1回の応答で複数ステップを実装しない
- **先に設計意図を説明する** — コードを出す前に、何を・なぜ作るかを必ず説明する
- **最小限のコードのみ** — 最小差分で提示する。完成品ではなく雛形・TODO で留める
- **求められていない機能を追加しない** — エラーハンドリング・抽象化・改善を勝手に追加しない
- **ユーザーが書く余地を残す** — 穴埋め・雛形を優先し、丸ごと完成させない
- **毎回最後に「次に自分で考える問い」を出す** — 1〜3 個

## 出力フォーマット（必須）

実装を伴う応答は毎回以下の構成で出力する。

1. 今回のステップの目的
2. なぜこの順番なのか
3. 今回身につける Ansible 知識
4. 実装内容
5. コードまたは設定
6. 重要な実務観点
7. 実行・確認方法
8. 次に自分で考える問い
9. 次ステップ候補（2案提示、実装はしない）

## ディレクトリ構成（最終形のイメージ）

```
ansible/
├── ansible.cfg
├── inventory/
│   ├── dev/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── web.yml
│   │       └── lb.yml
│   └── prod/
│       ├── hosts.yml
│       └── group_vars/
│           ├── all.yml
│           ├── web.yml
│           └── lb.yml
├── roles/
│   ├── nginx/          # ミドルウェアのインストール・更新・設定管理
│   ├── healthcheck/    # 更新後の動作確認
│   └── lb_control/     # LBからの切り離し・組み込み
└── playbooks/
    ├── rolling_update.yml
    ├── rollback.yml
    ├── healthcheck.yml
    └── version_check.yml

terraform/
├── environments/dev/
├── environments/prod/
└── modules/

scripts/                # AI拡張の入口（現時点ではAI未実装）
├── check_vulnerability.sh
└── generate_report.sh

docs/
├── runbook.md
├── architecture.md
└── ai_extension_points.md   # AI後付け拡張ポイントの設計メモ

.github/workflows/
├── lint.yml            # ansible-lint / yamllint
└── deploy.yml          # lint → dry-run → 手動承認 → 実行
```

## 主要な設計判断

| 判断ポイント | 選択 | 理由 |
|---|---|---|
| 対象ミドルウェア | Nginx | インストール・設定・リロード・バージョン管理がバランス良く学べる |
| inventory 分割 | 環境別ディレクトリ（`dev/`・`prod/`） | `-i` で切り替え。同一 playbook で環境差を吸収するパターンを学べる |
| role の粒度 | 3つ（nginx / healthcheck / lb_control） | ローリング更新の各フェーズと 1:1 対応。単体テストしやすい |
| 検証環境の LB | Nginx upstream ブロック | AWS なしで学習可能。Terraform 追加時に ALB へ差し替え |
| AI 機能 | 未実装・拡張ポイントのみ確保 | 5箇所の差し込み余地は `docs/ai_extension_points.md` に記載 |

## Ansible 学習ロードマップ

この順番に意味がある。

1. **inventory + ansible.cfg + ping** — 「誰に対して実行するか」を先に確立する
2. **nginx role（インストール）** — tasks・defaults・冪等性の基本
3. **template + handler** — Jinja2 設定ファイル・変更時のみ再起動するパターン
4. **healthcheck role + update playbook + tags** — role の組み合わせ・タグ設計
5. **serial + lb_control = ローリング更新** — ゼロダウンタイムパターン・delegate_to

Step 5 完了後に Terraform・GitHub Actions を追加する。

## 主要コマンド（実装後に使用）

```bash
# 構文チェック
ansible-playbook ansible/playbooks/rolling_update.yml --syntax-check

# ドライラン（check mode）
ansible-playbook -i ansible/inventory/dev ansible/playbooks/rolling_update.yml --check --diff

# 検証環境に対して実行
ansible-playbook -i ansible/inventory/dev ansible/playbooks/rolling_update.yml

# タグを指定して実行
ansible-playbook -i ansible/inventory/dev ansible/playbooks/rolling_update.yml --tags update

# Lint
ansible-lint ansible/playbooks/
yamllint ansible/
```

## AI 拡張ポイント（将来・現時点では未実装）

プロジェクト構成を変えずに後付けできる 5 箇所。

1. `scripts/check_vulnerability.sh` → AI が CVE 情報を要約・緊急度判定
2. `docs/runbook.md` 生成 → AI が更新メタデータからドラフト作成
3. CI `deploy.yml` の承認前ステップ → AI が dry-run 結果を分析・推奨判定
4. healthcheck 出力 → AI がログの異常を検知・報告
5. 切り戻し判断 → AI がメトリクスから切り戻し推奨を提示

各ポイントは「構造化入力（JSON/ログ）→ 判断 → 構造化出力」の形にする。骨組みが完成するまで AI API は呼び出さない。
