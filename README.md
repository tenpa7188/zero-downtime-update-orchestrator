# zero-downtime-update-orchestrator

ミドルウェアの脆弱性対応を起点にした、**ゼロダウンタイム更新オーケストレーション基盤**のリポジトリです。

検証環境と本番環境で同じ Ansible playbook を使い、LB から 1 台ずつ切り離し、Apache を更新し、ヘルスチェック後に LB へ戻す流れを自動化します。

```text
脆弱性検知 → Slack / Issue 通知 → dev 更新承認 → dev dry-run / 更新
         → dev 確認 → prod dry-run → 承認 → prod ローリング更新
         → 動作確認（→ 問題あれば切り戻し）
```

## 技術スタック

| 領域 | 技術 | 用途 |
|---|---|---|
| 構成管理・更新自動化 | Ansible | Apache 更新、LB 制御、ヘルスチェック、切り戻し |
| ローカル検証環境 | Vagrant + VirtualBox | `lb01` x 1、`web01` / `web02` x 2 の擬似マルチホスト環境 |
| 本番インフラ | Terraform + AWS | VPC、EC2、ALB、IAM、S3 の IaC 管理 |
| CI/CD | GitHub Actions | lint、dry-run、dev 自動 deploy、prod 承認付き deploy、rollback |
| Web ミドルウェア | Apache | Web サーバ本体。dev / prod 共通でローリング更新対象 |
| LB | Nginx / AWS ALB | dev は Nginx LB、prod は ALB |
| 本番接続 | AWS SSM | SSH ポート不要。SSM + S3 ステージングで Ansible 接続 |

AI 補助機能は未実装です。差し込み候補は [docs/ai_extension_points.md](docs/ai_extension_points.md) に整理しています。

## 現在の構成

```text
.
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   ├── dev/
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/
│   │   │       ├── all.yml
│   │   │       └── web.yml
│   │   └── prod/
│   │       ├── aws_ec2.yml
│   │       └── group_vars/
│   │           ├── all.yml
│   │           └── web.yml
│   ├── playbooks/
│   │   ├── group_vars/
│   │   │   └── web.yml        # web_http_port など playbook 共通値
│   │   ├── rolling_update.yml # dev / prod 共通のローリング更新
│   │   ├── site.yml
│   │   └── update.yml         # LB 用 Nginx 更新
│   └── roles/
│       ├── apache/            # Web サーバ Apache
│       ├── backup_cleanup/    # Ansible backup ファイルの世代管理
│       ├── healthcheck/       # systemd + HTTP ヘルスチェック
│       ├── lb_control/        # Nginx LB / ALB の drain・restore
│       └── nginx/             # dev LB 用 Nginx
├── terraform/
│   └── environments/
│       └── prod/
├── scripts/
│   ├── check_vulnerability.sh
│   └── watch_lb.sh
├── config/
│   └── check_vulnerability.env.example
├── docs/
│   ├── ai_extension_points.md
│   ├── architecture.md
│   ├── runbook.md
│   └── workflow.md
├── .github/
│   ├── actions/
│   │   └── setup-ansible-deploy/
│   └── workflows/
│       ├── deploy.yml
│       ├── lint.yml
│       ├── rollback.yml
│       └── self-hosted-test.yml
├── .claude/
│   └── skills/
│       └── ansible-dry-codegen/
├── Vagrantfile
├── requirements-deploy.txt
└── requirements-lint.txt
```

## 環境差分

| 環境 | LB | Web 接続 | Runner | deploy 承認 |
|---|---|---|---|---|
| dev | Nginx on `lb01` | SSH（Vagrant 鍵） | self-hosted | なし |
| prod | AWS ALB | AWS SSM | ubuntu-latest | GitHub environment `production` |

共通の Web backend port は [ansible/playbooks/group_vars/web.yml](ansible/playbooks/group_vars/web.yml) の `web_http_port` で管理します。Apache の listen、Nginx upstream、healthcheck はこの値を参照します。

## アップデート検知

`scripts/check_vulnerability.sh` は代表 Web サーバの `apache2` 現行バージョンと apt candidate を比較します。更新候補がある場合は GitHub Issue を作成し、Slack webhook が設定されていれば通知します。検知しても `deploy.yml` は実行しません。

実値は git 管理外の `config/check_vulnerability.env` に置きます。設定項目の雛形は `config/check_vulnerability.env.example` です。

```bash
# リポジトリルートで実行
bash scripts/check_vulnerability.sh
```

cron では環境変数を並べず、リポジトリルートへ移動してスクリプトを呼び出します。

```cron
0 9 * * * cd /mnt/c/source/zero-downtime-update-orchestrator && bash scripts/check_vulnerability.sh
```

## ローカル検証環境

Vagrant + VirtualBox で 3 台の VM を起動します。

```text
192.168.56.10  lb01   # Nginx ロードバランサ
192.168.56.11  web01  # Apache Web サーバ
192.168.56.12  web02  # Apache Web サーバ
```

```bash
vagrant up

cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/dev --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/dev
```

LB 経由の応答サーバを確認する場合:

```bash
# リポジトリルートで実行
bash scripts/watch_lb.sh
```

## 本番環境

Terraform は `terraform/environments/prod` にあります。EC2 は SSH を開けず、GitHub Actions から AWS OIDC で認証し、Ansible は SSM 接続で実行します。

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

`terraform output github_actions_role_arn` の値を GitHub Secrets の `AWS_ROLE_ARN` に設定します。

## GitHub Actions

- `lint.yml`: `ansible/**` 変更時に `yamllint` と `ansible-lint`
- `deploy.yml`: dry-run 後にローリング更新
  - push 時: dev 固定、承認なしで dry-run から deploy まで実行
  - 手動実行 dev: 承認なし
  - 手動実行 prod: `production` environment 承認あり
- `rollback.yml`: 手動実行で指定した Apache バージョンへ切り戻し
- `self-hosted-test.yml`: self-hosted runner の疎通確認

詳細は [docs/workflow.md](docs/workflow.md) を参照してください。

## 主要コマンド

```bash
# Ansible lint
cd ansible
yamllint ./
ansible-lint playbooks/

# dev dry-run / deploy
ansible-playbook playbooks/rolling_update.yml -i inventory/dev --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/dev

# prod inventory 確認 / dry-run / deploy
ansible-inventory -i inventory/prod --list
ansible-playbook playbooks/rolling_update.yml -i inventory/prod --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/prod

# rollback
ansible-playbook playbooks/rolling_update.yml -i inventory/prod \
  -e "apache_version=<切り戻し先バージョン>"
```

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — 設計方針、role 責務、変数配置
- [docs/runbook.md](docs/runbook.md) — 運用手順、切り戻し、トラブルシューティング
- [docs/workflow.md](docs/workflow.md) — GitHub Actions の流れ
- [docs/ai_extension_points.md](docs/ai_extension_points.md) — AI 機能を後付けする候補
