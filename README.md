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
| CI/CD | GitHub Actions | lint・dry-run・手動承認・デプロイ |
| 対象ミドルウェア | Nginx | LB・Web サーバの設定管理と更新 |

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
| Step 7 | バージョン検知 → dry-run 自動トリガー | 🚧 進行中 |
| Step 8 | Terraform による IaC 土台 | 🔲 未着手 |

---

## ディレクトリ構成

```
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── dev/
│   │       ├── hosts.yml
│   │       └── group_vars/
│   │           ├── all.yml       # 全ホスト共通変数
│   │           └── web.yml       # web グループ変数
│   ├── roles/
│   │   ├── nginx/                # インストール・設定・再起動
│   │   ├── healthcheck/          # サービス起動確認・HTTP 疎通確認
│   │   └── lb_control/           # LB からの切り離し・組み込み・バックアップ管理
│   └── playbooks/
│       ├── rolling_update.yml    # メインのローリング更新
│       ├── update.yml
│       └── site.yml
├── scripts/
│   └── watch_lb.sh               # LB へ1秒ごとにリクエストし応答サーバを表示
├── Vagrantfile                   # lb01・web01・web02 の VM 定義
├── requirements.txt              # ansible-lint・yamllint のバージョン固定
├── .gitattributes                # LF 強制
└── .github/
    └── workflows/
        ├── lint.yml              # yamllint + ansible-lint（push 時自動実行）
        └── deploy.yml            # dry-run（push 時）→ 承認 → deploy（手動）
```

---

## ローカル検証環境

Vagrant + VirtualBox で 3VM 構成を起動します。

```
192.168.56.10  lb01   # Nginx ロードバランサ
192.168.56.11  web01  # Nginx Web サーバ
192.168.56.12  web02  # Nginx Web サーバ
```

```bash
# VM 起動
vagrant up

# LB への応答確認（1秒ごとにポーリング）
bash scripts/watch_lb.sh
```

---

## ドキュメント

- [docs/architecture.md](docs/architecture.md) — 設計方針・ロール設計・主要な設計判断
- [docs/workflow.md](docs/workflow.md) — CI/CD ワークフロー詳細・act によるローカル実行

---

## 主要コマンド

```bash
# 構文チェック
ansible-playbook ansible/playbooks/rolling_update.yml --syntax-check

# ドライラン
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev --check --diff

# ローリング更新実行
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev

# Lint
cd ansible && yamllint ./
cd ansible && ansible-lint playbooks/
```
