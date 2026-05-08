# zero-downtime-update-orchestrator

ミドルウェアの脆弱性対応を起点にした、**ゼロダウンタイム更新オーケストレーション基盤**のリポジトリです。

実務の運用フローを題材に、以下を自動化・体系化することを目標としています。

```
脆弱性検知 → 更新計画 → 検証環境で更新 → 動作確認
         → 商用ローリング更新 → 動作確認（→ 問題あれば切り戻し）
```

---

## 技術スタック

| 領域 | 技術 | 用途 |
|---|---|---|
| 構成管理・更新自動化 | Ansible | ミドルウェア更新・ローリング更新・切り戻し |
| ローカル検証環境 | Vagrant + VirtualBox | lb × 1・web × 2 の擬似マルチホスト環境 |
| 本番インフラ | Terraform + AWS | VPC・EC2・ALB・IAM・S3 の IaC 管理 |
| CI/CD | GitHub Actions | lint・dry-run・手動承認・デプロイ |
| 対象ミドルウェア | Apache（Web）/ Nginx（LB・dev のみ） | バージョン管理とローリング更新 |
| 本番接続 | AWS SSM | SSH ポート不要・インスタンスプロファイルで認証 |

> AI 補助機能（脆弱性要約・手順書ドラフト生成・ログ分析など）は将来追加予定。現時点では拡張ポイントのみ設計済み。

---

## 実装状況

| ステップ | 内容 | 状態 |
|---|---|---|
| Step 1 | inventory 設計・ansible.cfg・接続確認 | ✅ 完了 |
| Step 2 | nginx role（インストール・冪等性） | ✅ 完了 |
| Step 3 | template + handler（設定管理・再起動制御） | ✅ 完了 |
| Step 4 | healthcheck role + update playbook + tags | ✅ 完了 |
| Step 5 | serial + lb_control（ローリング更新） | ✅ 完了 |
| Step 6 | GitHub Actions による CI/CD（lint・dry-run・承認・deploy） | ✅ 完了 |
| Step 7 | Terraform による AWS prod 環境構築（VPC・EC2・ALB・IAM・S3） | ✅ 完了 |
| Step 8 | prod 環境での実機ローリング更新テスト | 🚧 進行中 |

---

## ディレクトリ構成

```
.
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml              # Ansible コレクション（amazon.aws / community.aws）
│   ├── inventory/
│   │   ├── dev/                      # 検証環境（Vagrant VM）
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/
│   │   │       ├── all.yml
│   │   │       └── web.yml
│   │   └── prod/                     # 本番環境（AWS EC2）
│   │       ├── aws_ec2.yml           # 動的インベントリ（amazon.aws.aws_ec2）
│   │       └── group_vars/
│   │           ├── all.yml           # lb_control_type: alb など
│   │           └── web.yml           # SSM 接続設定・apache バージョン
│   ├── roles/
│   │   ├── nginx/                    # LB 用 Nginx（dev 検証環境のみ）
│   │   ├── apache/                   # Web サーバ Apache（dev / prod 共通）
│   │   ├── healthcheck/              # サービス起動確認・HTTP 疎通確認
│   │   └── lb_control/               # LB 切り離し・組み込み（Nginx / ALB 対応）
│   └── playbooks/
│       ├── rolling_update.yml        # メインのローリング更新（dev / prod 共通）
│       ├── update.yml
│       └── site.yml
├── terraform/
│   └── environments/
│       └── prod/
│           ├── locals.tf             # common_tags
│           ├── variables.tf          # リージョン・プロジェクト名・AMI など
│           ├── provider.tf
│           ├── main.tf               # VPC・SG・EC2・ALB
│           ├── s3.tf                 # Ansible SSM ステージング用 S3
│           ├── iam_github.tf         # GitHub Actions OIDC ロール
│           ├── iam_ec2.tf            # EC2 インスタンスプロファイル（SSM + S3）
│           └── outputs.tf
├── scripts/
│   ├── check_vulnerability.sh        # apt でバージョン比較・脆弱性検知
│   └── watch_lb.sh                   # LB へ 1 秒ごとにリクエストし応答サーバを表示
├── docs/
│   ├── architecture.md               # 設計方針・ロール設計
│   ├── runbook.md                    # 運用手順書（ローリング更新・切り戻し）
│   └── workflow.md                   # CI/CD ワークフロー詳細
├── Vagrantfile                       # lb01・web01・web02 の VM 定義
├── requirements-lint.txt             # yamllint・ansible-lint のバージョン固定
├── requirements-deploy.txt           # boto3・botocore のバージョン固定
└── .github/
    └── workflows/
        ├── lint.yml                  # yamllint + ansible-lint
        ├── deploy.yml                # dry-run → 承認 → ローリング更新
        └── rollback.yml              # 切り戻し（手動実行）
```

---

## 環境別の接続方式

| 環境 | LB | Web 接続 | GitHub Actions Runner |
|---|---|---|---|
| dev | Nginx（Vagrant VM） | SSH（Vagrant 鍵） | self-hosted（WSL2） |
| prod | AWS ALB | AWS SSM（ポート22不要） | ubuntu-latest（OIDC 認証） |

---

## ローカル検証環境（dev）

Vagrant + VirtualBox で 3VM 構成を起動します。

```
192.168.56.10  lb01   # Nginx ロードバランサ
192.168.56.11  web01  # Apache Web サーバ
192.168.56.12  web02  # Apache Web サーバ
```

```bash
# VM 起動
vagrant up

# LB への応答確認（1秒ごとにポーリング）
bash scripts/watch_lb.sh
```

---

## 主要コマンド

### dev 環境

```bash
# ドライラン
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev --check --diff

# ローリング更新実行
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev
```

### prod 環境（AWS）

```bash
# 事前：AWS 認証
export AWS_PROFILE=your-profile

# ドライラン
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/prod --check --diff

# ローリング更新実行
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/prod
```

### Terraform（prod インフラ管理）

```bash
cd terraform/environments/prod

terraform init
terraform plan
terraform apply
```

### Lint

```bash
cd ansible && yamllint ./
cd ansible && ansible-lint playbooks/
```

---

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — 設計方針・ロール設計・主要な設計判断
- [docs/runbook.md](docs/runbook.md) — 運用手順書（ローリング更新・切り戻し・トラブルシューティング）
- [docs/workflow.md](docs/workflow.md) — CI/CD ワークフロー詳細
