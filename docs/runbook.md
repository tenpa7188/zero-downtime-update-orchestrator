# Runbook — ゼロダウンタイム更新

## 事前確認チェックリスト

- [ ] AWS 認証が通ること（`aws sts get-caller-identity`）
- [ ] EC2 インスタンスが SSM で応答すること（`aws ssm describe-instance-information`）
- [ ] ALB ターゲットグループのヘルスチェックが Healthy であること
- [ ] S3 バケット `zduo-ansible-ssm` が存在すること

---

## ローリング更新（dev）

### 実行前

```bash
# Vagrant VM が起動していることを確認
vagrant status

# ドライラン
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev --check --diff
```

### 実行

```bash
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/dev
```

### 確認

```bash
# LB 経由でレスポンスを確認（1秒ごと）
bash scripts/watch_lb.sh
```

---

## ローリング更新（prod）

### 実行前

```bash
# AWS 認証
export AWS_PROFILE=your-profile

# 動的インベントリで EC2 が見えることを確認
cd ansible && ansible-inventory -i inventory/prod --list

# ドライラン
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/prod --check --diff
```

### 実行

```bash
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/prod
```

### 実行中の確認ポイント

- ALB コンソールで各ターゲットの状態を確認（切り離し → Healthy 復帰）
- `serial: 1` のため 1台ずつ順番に更新される
- 1台でも healthcheck が失敗すると `any_errors_fatal: true` で全体が停止する

---

## 切り戻し（prod）

<!-- TODO: rollback.yml の実行手順を記載する -->
<!-- TODO: 切り戻し対象バージョンの指定方法を記載する -->

```bash
cd ansible && ansible-playbook playbooks/rolling_update.yml \
  -i inventory/prod \
  -e "apache_version=<切り戻し先バージョン>"
```

---

## トラブルシューティング

### SSM 接続ができない

<!-- TODO: SSM Agent の状態確認コマンドを記載する -->
<!-- TODO: IAM インスタンスプロファイルの確認手順を記載する -->

確認項目：
- EC2 インスタンスプロファイルに `AmazonSSMManagedInstanceCore` が付いているか
- SSM Agent がインスタンス上で起動しているか
- セキュリティグループがアウトバウンド HTTPS（443）を許可しているか

### ALB のターゲット登録解除がタイムアウトする

`community.aws.elb_target` の `target_status_timeout` がデフォルト 300 秒。
ALB のヘルスチェック間隔・閾値の設定と照らし合わせて調整する。

### ansible-lint が community.aws を解決できない

```bash
# WSL 上でコレクションをインストール
source .venv/bin/activate
ansible-galaxy collection install -r ansible/requirements.yml
```

---

## 関連リソース

| リソース | 確認先 |
|---|---|
| ALB | AWS コンソール → EC2 → ロードバランサー |
| EC2 インスタンス | AWS コンソール → EC2 → インスタンス |
| SSM セッション履歴 | AWS コンソール → Systems Manager → セッションマネージャー |
| S3 一時ファイル | `zduo-ansible-ssm` バケット（実行後は自動削除） |
| GitHub Actions ログ | リポジトリ → Actions タブ |
