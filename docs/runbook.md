# Runbook

## 事前確認

### dev

- [ ] Vagrant VM が起動している
- [ ] self-hosted runner が起動している
- [ ] `lb01` / `web01` / `web02` に SSH できる
- [ ] `http://192.168.56.10/` へアクセスできる

```bash
vagrant status
cd ansible
ansible all -i inventory/dev -m ping
```

### prod

- [ ] Terraform apply 済み
- [ ] GitHub Secrets `AWS_ROLE_ARN` が設定済み
- [ ] GitHub environment `production` が設定済み
- [ ] EC2 が SSM managed instance として見えている
- [ ] ALB target group が Healthy
- [ ] S3 bucket `zduo-ansible-ssm` が存在する

```bash
aws sts get-caller-identity
aws ssm describe-instance-information --region ap-northeast-1
cd ansible && ansible-inventory -i inventory/prod --list
```

## アップデート検知

`scripts/check_vulnerability.sh` を cron などから定期実行する。スクリプトは `config/check_vulnerability.env` を読み込み、更新候補がある場合に GitHub Issue 作成と Slack 通知を行う。

実行内容:

1. 代表 Web サーバへ SSH する
2. `dpkg -l apache2` で現行バージョンを取得する
3. `apt-get update` 後に `apt-cache policy apache2` で candidate を取得する
4. 現行と candidate が異なる場合、重複 Issue がなければ作成する
5. `SLACK_WEBHOOK_URL` が設定されていれば Slack に通知する

既に同じ candidate の Issue が開いている場合、デフォルトでは Slack へ再通知しない。毎回通知したい場合は `NOTIFY_EXISTING_ISSUE="true"` を設定する。

```bash
# リポジトリルートで実行
bash scripts/check_vulnerability.sh
```

更新検知時も終了コードは `0`。SSH 失敗、candidate 取得失敗、GitHub Issue 作成失敗、Slack 通知失敗は運用上の失敗として `1` を返す。

設定ファイル:

```bash
config/check_vulnerability.env
```

事前確認:

```bash
gh auth status
curl --version
```

## dev ローリング更新

### 手動実行

```bash
cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/dev --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/dev
```

### GitHub Actions

`deploy.yml` を `environment=dev` で手動実行する。`ansible/**` が main に push された場合も dev として dry-run から deploy まで自動実行される。

### 確認

```bash
# リポジトリルートで実行
bash scripts/watch_lb.sh
```

`web01` / `web02` が交互に応答し、更新中も LB 経由の応答が継続することを確認する。

## prod ローリング更新

### 手動実行

```bash
cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/prod --check --diff
ansible-playbook playbooks/rolling_update.yml -i inventory/prod
```

### GitHub Actions

`deploy.yml` を `environment=prod` で手動実行する。

1. dry-run が実行される
2. GitHub environment `production` の承認待ちになる
3. 承認後に deploy が実行される
4. `apache_version` input を指定していた場合、deploy 成功後に `inventory/prod/group_vars/web.yml` が更新される

### 実行中の確認

- ALB target group で対象 instance が 1 台ずつ deregister / register されること
- register 後に Healthy へ戻ること
- `serial: 1` により同時に複数台が更新されないこと
- 失敗時は `any_errors_fatal: true` により後続更新が止まること

## 切り戻し

切り戻しは通常の `rolling_update.yml` に古い `apache_version` を渡して実行する。

### 手動実行

```bash
cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/prod \
  -e "apache_version=<切り戻し先バージョン>"
```

dev の場合:

```bash
cd ansible
ansible-playbook playbooks/rolling_update.yml -i inventory/dev \
  -e "apache_version=<切り戻し先バージョン>"
```

### GitHub Actions

`rollback.yml` を手動実行する。

入力:

- `environment`: `dev` または `prod`
- `rollback_version`: 切り戻し先の Apache バージョン

実行後、対象 inventory の `apache_version` が `rollback_version` に同期される。

## バージョン確認

```bash
# dev 例
ssh -i .vagrant/machines/web01/virtualbox/private_key vagrant@192.168.56.11 \
  "dpkg -l apache2 | awk '/^ii/{print \$3}'"

# apt candidate 確認
ssh -i .vagrant/machines/web01/virtualbox/private_key vagrant@192.168.56.11 \
  "apt-cache policy apache2"
```

## トラブルシューティング

### SSM 接続ができない

確認項目:

- EC2 instance profile に `AmazonSSMManagedInstanceCore` が付いている
- SSM Agent が起動している
- EC2 から HTTPS outbound が許可されている
- Ansible SSM 用 S3 bucket へ Get/Put/Delete できる
- `inventory/prod/group_vars/web.yml` の `ansible_aws_ssm_bucket_name` が正しい

### ALB target が Healthy に戻らない

確認項目:

- EC2 security group が ALB security group から `web_http_port` を許可している
- Apache が `web_http_port` で listen している
- `/index.html` が HTTP 200 を返す
- ALB target group の health check path が `/index.html`

### dev で SSH できない

確認項目:

- `vagrant up` 済み
- self-hosted runner が Vagrant VM に到達できる環境で動いている
- `ansible/inventory/dev/group_vars/all.yml` の Vagrant private key path が runner から見える

### backup ファイルが増え続ける

`template` task は `backup: true` を使う。世代管理は `backup_cleanup` role で行う。

対象に漏れがある場合は、各 role の defaults に cleanup target を追加する。

## 関連リソース

| リソース | 確認先 |
|---|---|
| dev LB | `http://192.168.56.10/` |
| prod ALB | Terraform output `alb_dns_name` |
| EC2 | AWS Console -> EC2 -> Instances |
| SSM | AWS Console -> Systems Manager |
| S3 | `zduo-ansible-ssm` |
| GitHub Actions | Repository -> Actions |
