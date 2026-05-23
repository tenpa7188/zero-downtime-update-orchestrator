# CI/CD ワークフロー

## 全体フロー

```text
cron: check_vulnerability.sh
  └─ GitHub Issue / Slack 通知

push to main (ansible/**)
  ├─ lint.yml
  └─ deploy.yml
       └─ dev dry-run → dev deploy

workflow_dispatch: deploy.yml
  ├─ environment=dev
  │    └─ dry-run → deploy
  └─ environment=prod
       └─ dry-run → production 承認 → deploy

workflow_dispatch: rollback.yml
  └─ 指定した environment / rollback_version で rolling_update.yml を実行
```

## workflows

### `check_vulnerability.sh`

| 項目 | 内容 |
|---|---|
| トリガー | cron などの定期実行 |
| 設定 | `config/check_vulnerability.env` |
| 内容 | Apache 更新候補の検知、GitHub Issue 作成、Slack 通知 |
| 実行しないこと | `deploy.yml` の自動起動 |

### `lint.yml`

| 項目 | 内容 |
|---|---|
| トリガー | `ansible/**` への push / pull request |
| Runner | `ubuntu-latest` |
| 内容 | `yamllint ./`、`ansible-lint playbooks/` |

### `deploy.yml`

| 項目 | dev | prod |
|---|---|---|
| トリガー | push / 手動 | 手動 |
| Runner | self-hosted | ubuntu-latest |
| 接続 | Vagrant VM へ SSH | AWS SSM |
| 承認 | なし | GitHub environment `production` |
| 実行 | dry-run 成功後に deploy | dry-run 成功後、承認されると deploy |

`apache_version` input を空にした場合は inventory の `apache_version` を使う。値を指定した場合は `-e apache_version=...` で上書きし、deploy 成功後に `ansible/inventory/<env>/group_vars/web.yml` へ同期する。

### `rollback.yml`

| 項目 | 内容 |
|---|---|
| トリガー | 手動 |
| 入力 | `environment`、`rollback_version` |
| Runner | dev は self-hosted、prod は ubuntu-latest |
| 内容 | `rolling_update.yml` に `-e apache_version=<rollback_version>` を渡して実行 |
| 後処理 | 対象 inventory の `apache_version` を rollback version に同期 |

## 共通 action

`.github/actions/setup-ansible-deploy/action.yml` は deploy / rollback で共通の準備を行う。

prod のみ実行する処理:

- `requirements-deploy.txt` のインストール
- Ansible collections cache の復元
- `ansible-galaxy collection install -r ansible/requirements.yml`
- `aws-actions/configure-aws-credentials` による OIDC 認証

dev は self-hosted runner 側に Ansible 実行環境がある前提のため、上記の prod 専用処理はスキップする。

## 必要な GitHub 設定

### Secrets

| Secret | 用途 |
|---|---|
| `AWS_ROLE_ARN` | prod deploy / rollback で Assume する IAM role ARN |

### Environments

| Environment | 用途 |
|---|---|
| `production` | prod deploy の手動承認 |

## self-hosted runner

dev は Vagrant VM の private network に到達できる self-hosted runner で実行する。

```bash
cd ~/actions-runner
./run.sh
```

runner 上では、Ansible と Vagrant VM への SSH 接続が使える状態にしておく。
