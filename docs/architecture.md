# アーキテクチャ

## 目的

このリポジトリは、Apache の更新を LB 配下の複数 Web サーバへ **1 台ずつ** 適用し、更新中もサービス全体を止めない運用パターンを Ansible / GitHub Actions / Terraform で実装する。

dev と prod は同じ `rolling_update.yml` を使い、環境差は inventory と role 変数で吸収する。

## 全体像

```text
dev:
  client -> lb01(Nginx) -> web01/web02(Apache: web_http_port)

prod:
  client -> AWS ALB -> EC2 web instances(Apache: web_http_port)
```

ローリング更新の流れ:

```text
1. 対象 Web サーバを LB から切り離す
2. Apache を指定バージョンへ更新する
3. 設定ファイルと index.html を配置する
4. systemd と HTTP でヘルスチェックする
5. 対象 Web サーバを LB に戻す
6. 次の Web サーバへ進む
```

`serial: 1` と `any_errors_fatal: true` により、1 台ずつ処理し、途中で失敗した場合は全体を止める。

## 主要な設計判断

| 判断ポイント | 選択 | 理由 |
|---|---|---|
| 更新対象 | Apache | Web サーバ本体をバージョン固定で更新し、rollback も同じ playbook で扱う |
| dev LB | Nginx upstream | AWS なしで LB drain / restore を学習・検証できる |
| prod LB | AWS ALB | 実運用に近い target group 登録・解除でローリング更新する |
| prod 接続 | AWS SSM | SSH ポートを開けず、GitHub Actions から OIDC で操作する |
| 共通 port | `web_http_port` | Apache listen、LB upstream、healthcheck が同じ backend port を参照する |
| backup 世代管理 | `backup_cleanup` role | `backup: true` で作られる `*~` ファイルを各 role から共通処理で整理する |

## Ansible role

| role | 責務 |
|---|---|
| `apache` | Apache の PPA 追加、バージョン固定インストール、設定配置、起動、自動起動、管理ファイルの backup 世代管理 |
| `nginx` | dev LB 用 Nginx のインストールと `/etc/nginx/nginx.conf` 配置 |
| `lb_control` | dev は Nginx upstream の down/restore、prod は ALB target の deregister/register |
| `healthcheck` | Apache service の active 確認と、dev での HTTP 疎通確認 |
| `backup_cleanup` | Ansible backup ファイルの古い世代を削除する共通 role |

## 変数配置

| 場所 | 例 | 用途 |
|---|---|---|
| `ansible/playbooks/group_vars/web.yml` | `web_http_port` | playbook 全体で共有する Web backend の値 |
| `inventory/dev/group_vars/all.yml` | Vagrant 接続、`lb_control_type: nginx` | dev 全体の接続・LB 方式 |
| `inventory/dev/group_vars/web.yml` | `apache_version` | dev Web サーバ固有値 |
| `inventory/prod/group_vars/all.yml` | `lb_control_type: alb`、`aws_region`、`project_name` | prod 全体の AWS / ALB 設定 |
| `inventory/prod/group_vars/web.yml` | SSM 接続、`apache_version` | prod Web サーバ接続・バージョン |
| `roles/*/defaults/main.yml` | package 名、backup 世代数 | role の安全な default |

## backup 方針

Ansible の `template` task は `backup: true` を付け、変更前ファイルを `ファイル名.<timestamp>~` として保存する。

世代管理は `backup_cleanup` role へ集約している。

対象:

- `/etc/nginx/nginx.conf`
- `/etc/nginx/conf.d/proxy.conf`
- `/etc/nginx/conf.d/upstream.conf`
- `/etc/apache2/ports.conf`
- `/etc/apache2/sites-available/000-default.conf`
- `{{ apache_document_root }}/index.html`

## CI/CD

dev は self-hosted runner から Vagrant VM へ SSH する。push 時も手動実行時も、dry-run 成功後に承認なしで deploy する。

prod は GitHub-hosted runner から AWS OIDC で認証し、SSM 経由で EC2 を操作する。手動実行のみで、dry-run 後に GitHub environment `production` の承認を必要とする。

詳細は [workflow.md](workflow.md) を参照。
