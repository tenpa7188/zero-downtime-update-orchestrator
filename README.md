# zero-downtime-update-orchestrator

> **⚠️ このリポジトリは現在構築中です。**
> 設計・実装はステップごとに段階的に進めています。

---

## 概要

ミドルウェアの脆弱性対応を起点にした、**ゼロダウンタイム更新オーケストレーション基盤**のポートフォリオです。

実務の SRE 運用フローを題材に、以下を自動化・体系化することを目標としています。

```
脆弱性検知 → 更新計画 → 検証環境で更新 → 動作確認
         → 商用ローリング更新 → 動作確認（→ 問題あれば切り戻し）
```

---

## 技術スタック

| 領域 | 技術 | 用途 |
|---|---|---|
| 構成管理・更新自動化 | Ansible | ミドルウェア更新・ローリング更新・切り戻し |
| IaC | Terraform | インフラ構築（予定） |
| CI/CD | GitHub Actions | lint・dry-run・デプロイ自動化（予定） |
| 対象ミドルウェア | Nginx | 更新・設定管理の対象 |

> AI 補助機能（脆弱性要約・手順書ドラフト生成・ログ分析など）は将来追加予定。現時点では未実装。

---

## 実装状況

| ステップ | 内容 | 状態 |
|---|---|---|
| Step 1 | inventory 設計 + ansible.cfg + 接続確認 | 🔲 未着手 |
| Step 2 | nginx role（インストール・冪等性） | 🔲 未着手 |
| Step 3 | template + handler（設定管理・再起動制御） | 🔲 未着手 |
| Step 4 | healthcheck role + update playbook + tags | 🔲 未着手 |
| Step 5 | serial + lb_control（ローリング更新） | 🔲 未着手 |
| Step 6 | Terraform による IaC 土台 | 🔲 未着手 |
| Step 7 | GitHub Actions による CI/CD 土台 | 🔲 未着手 |

---

## 設計方針

- **AIがなくても成立する骨組みを先に作る**
  現時点では Ansible を中心とした更新基盤そのものを構築することを優先する。

- **後からAIを差し込める設計にする**
  `scripts/`・CI/CD ジョブ・healthcheck 出力など、5箇所に AI 拡張ポイントを設計上確保している（詳細: `docs/ai_extension_points.md`）。

- **環境差は inventory で吸収する**
  同一の playbook を `-i ansible/inventory/dev` または `-i ansible/inventory/prod` で切り替えて実行する。

---

## ディレクトリ構成（予定）

```
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── dev/
│   │   └── prod/
│   ├── roles/
│   │   ├── nginx/
│   │   ├── healthcheck/
│   │   └── lb_control/
│   └── playbooks/
├── terraform/
├── scripts/
├── docs/
└── .github/workflows/
```

---

## ローカル検証環境

Vagrant + VirtualBox で擬似マルチホスト環境（lb × 1、web × 2）を構築して動作確認する。

---

## ドキュメント

- `docs/architecture.md` — 構成図・設計思想（予定）
- `docs/runbook.md` — 運用手順書（予定）
- `docs/ai_extension_points.md` — AI 後付け拡張ポイントの設計メモ（予定）
