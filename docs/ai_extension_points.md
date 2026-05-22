# AI 拡張ポイント

現時点では AI API 呼び出しは実装しない。更新基盤として成立する骨組みを先に作り、後から差し込める箇所を明確にしておく。

## 候補

| 箇所 | 入力 | 出力 | 目的 |
|---|---|---|---|
| `scripts/check_vulnerability.sh` | installed / candidate version | 更新要否、緊急度、推奨 version | 脆弱性対応の起点を作る |
| `deploy.yml` dry-run 後 | Ansible check diff / logs | deploy 可否、注意点 | 承認前レビューを補助する |
| `docs/runbook.md` | version、対象環境、dry-run 結果 | 作業手順ドラフト | オペレーション手順の作成を補助する |
| `healthcheck` 出力 | systemd status、HTTP 結果 | 異常分類、次の確認観点 | 更新失敗時の切り分けを早くする |
| `rollback.yml` | deploy 結果、healthcheck、ALB 状態 | rollback 推奨判断 | 切り戻し判断を補助する |

## 実装方針

- AI は更新・切り戻しを直接実行しない
- 入力は JSON、ログ、diff など構造化しやすい形で渡す
- 出力は「推奨」「理由」「確認コマンド」「リスク」のように分ける
- CI では AI の判断を人間の承認材料として扱う
- prod では GitHub environment の承認を残す

## 最初に追加しやすい箇所

`deploy.yml` の dry-run 後に、Ansible の `--check --diff` 出力を要約する job を追加するのが最も自然。

理由:

- 既存フローに差し込みやすい
- prod 承認前の判断材料になる
- deploy 実行権限を AI に渡さずに済む
