# CI/CD ワークフロー

## 全体フロー

```
push (ansible/** 変更時)
  ├─ [lint.yml]    yamllint + ansible-lint
  └─ [deploy.yml]  dry-run → deploy（dev / 承認なし）

workflow_dispatch（手動実行）
  ├─ dev:  dry-run → deploy（承認なし）
  └─ prod: dry-run → 承認（environment: production）→ deploy
```

---

## ジョブ詳細

### lint（lint.yml）

| 項目 | 内容 |
|---|---|
| トリガー | `ansible/**` への push・PR |
| 実行環境 | ubuntu-latest |
| 内容 | `yamllint ./` → `ansible-lint playbooks/` |

### dry-run（deploy.yml）

| 項目 | 内容 |
|---|---|
| トリガー | `ansible/**` への push・手動実行 |
| 実行環境 | dev は self-hosted runner、prod は ubuntu-latest |
| 内容 | `ansible-playbook --check --diff` |
| 対象環境 | push 時は `dev` 固定、手動時は選択可（dev / prod） |

### approve（deploy.yml）

| 項目 | 内容 |
|---|---|
| トリガー | prod 手動実行の dry-run 成功後のみ |
| 内容 | GitHub environment `production` による承認待ち |

### deploy（deploy.yml）

| 項目 | 内容 |
|---|---|
| トリガー | dev は dry-run 成功後、prod は approve 成功後 |
| 実行環境 | dev は self-hosted runner、prod は ubuntu-latest |
| 内容 | `ansible-playbook`（実際のローリング更新） |


---

## self-hosted runner のセットアップ

GitHub Actions の self-hosted runner を WSL2 (Ubuntu-24.04) 上に配置し、Vagrant VM への SSH を可能にしている。

```bash
# runner の手動起動（WSL2 内）
cd ~/actions-runner && ./run.sh
```
