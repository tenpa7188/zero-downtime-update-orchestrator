# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## プロジェクトの目的

ゼロダウンタイムで Apache を更新するオーケストレーション基盤。実務の SRE ワークフローを題材に、dev / prod の両環境で同じ Ansible playbook を使ってローリング更新・動作確認・切り戻しを行う。

```text
脆弱性検知 → 更新計画 → dev dry-run → dev 更新 → prod dry-run
         → 承認 → prod ローリング更新 → 動作確認（→ 問題あれば切り戻し）
```

## 作業ルール

このプロジェクトはポートフォリオ作成と Ansible 学習を兼ねる。変更時は以下を守る。

- 既存の role / inventory / workflow の責務を読んでから編集する
- 振る舞いを変える変更と DRY 化だけの変更を混ぜすぎない
- Ansible では role defaults、inventory vars、playbook group_vars の置き場所を意識する
- `backup: true` を付けるファイル更新 task には、必要に応じて `backup_cleanup` role による世代管理を追加する
- prod の承認フローを外さない
- 可能なら `yamllint`、`ansible-lint`、`ansible-playbook --syntax-check` を実行する

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
