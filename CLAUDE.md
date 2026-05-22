# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## プロジェクトの目的

ゼロダウンタイムで Apache を更新するオーケストレーション基盤。実務の SRE ワークフローを題材に、dev / prod の両環境で同じ Ansible playbook を使ってローリング更新・動作確認・切り戻しを行う。

```text
脆弱性検知 → 更新計画 → dev dry-run → dev 更新 → prod dry-run
         → 承認 → prod ローリング更新 → 動作確認（→ 問題あれば切り戻し）
```

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

## 現在の構成

```text
ansible/
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── dev/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       └── web.yml
│   └── prod/
│       ├── aws_ec2.yml
│       └── group_vars/
│           ├── all.yml
│           └── web.yml
├── playbooks/
│   ├── group_vars/
│   │   └── web.yml
│   ├── rolling_update.yml
│   ├── site.yml
│   └── update.yml
└── roles/
    ├── apache/
    ├── backup_cleanup/
    ├── healthcheck/
    ├── lb_control/
    └── nginx/

.github/
├── actions/
│   └── setup-ansible-deploy/
└── workflows/
    ├── deploy.yml
    ├── lint.yml
    ├── rollback.yml
    └── self-hosted-test.yml

.claude/
└── skills/
    └── ansible-dry-codegen/
```

## 主要な設計判断

| 判断ポイント | 選択 | 理由 |
|---|---|---|
| Web 更新対象 | Apache | バージョン固定、設定配置、rollback を学習しやすい |
| dev LB | Nginx | Vagrant だけで LB drain / restore を検証できる |
| prod LB | AWS ALB | 実運用に近い target group 操作を行う |
| prod 接続 | AWS SSM | SSH ポートを開けずに GitHub Actions から操作する |
| Web port | `web_http_port` | Apache、LB upstream、healthcheck の共通概念として扱う |
| backup 世代管理 | `backup_cleanup` role | role 横断で同じ cleanup 処理を使う |

## Ansible role の責務

- `apache`: Apache の PPA 追加、バージョン固定インストール、設定配置、起動、backup 世代管理
- `nginx`: dev LB 用 Nginx のインストールとベース設定
- `lb_control`: dev は Nginx upstream、prod は ALB target group を操作
- `healthcheck`: service active 確認と dev の HTTP 疎通確認
- `backup_cleanup`: `backup: true` で生成された古い `*~` ファイルを削除

## CI/CD

- `deploy.yml`
  - push: dev dry-run -> dev deploy
  - workflow_dispatch dev: dry-run -> deploy
  - workflow_dispatch prod: dry-run -> production approval -> deploy
- `rollback.yml`
  - workflow_dispatch の `rollback_version` を `apache_version` として `rolling_update.yml` に渡す
- `.github/actions/setup-ansible-deploy`
  - prod 用の Python dependencies、Ansible collections、AWS OIDC 認証を共通化

## よく使う確認コマンド

```bash
cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/dev --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/dev

ansible-inventory -i inventory/prod --list
ansible-playbook playbooks/rolling_update.yml -i inventory/prod --check --diff

yamllint ./
ansible-lint playbooks/
```

## ドキュメント

- `README.md`: 全体像
- `docs/architecture.md`: 設計判断と role 責務
- `docs/runbook.md`: 運用手順
- `docs/workflow.md`: GitHub Actions 詳細
- `docs/ai_extension_points.md`: 将来の AI 差し込み候補
- `.claude/skills/ansible-dry-codegen/SKILL.md`: Claude Code 向けの Ansible DRY 生成ルール
