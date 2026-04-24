# 設計方針

## 基本方針

- **AI がなくても成立する骨組みを先に作る**
  現時点では Ansible を中心とした更新基盤そのものを構築することを優先する。

- **後から AI を差し込める設計にする**
  `scripts/`・CI/CD ジョブ・healthcheck 出力など、5 箇所に AI 拡張ポイントを設計上確保している（詳細: [ai_extension_points.md](ai_extension_points.md)）。

- **環境差は inventory で吸収する**
  同一の playbook を `-i ansible/inventory/dev` または `-i ansible/inventory/prod` で切り替えて実行する。

---

## 主要な設計判断

| 判断ポイント | 選択 | 理由 |
|---|---|---|
| 対象ミドルウェア | Nginx | インストール・設定・リロード・バージョン管理がバランス良く学べる |
| inventory 分割 | 環境別ディレクトリ（`dev/`・`prod/`） | `-i` で切り替え。同一 playbook で環境差を吸収するパターン |
| role の粒度 | 3つ（nginx / healthcheck / lb_control） | ローリング更新の各フェーズと 1:1 対応。単体テストしやすい |
| 検証環境の LB | Nginx upstream ブロック | AWS なしで学習可能。Terraform 追加時に ALB へ差し替え可能 |
| AI 機能 | 未実装・拡張ポイントのみ確保 | 骨格が完成するまで AI API は呼び出さない |

---

## ロール設計

```
nginx/          インストール・設定ファイル配置・Reload ハンドラ
healthcheck/    systemd 状態確認・HTTP 疎通確認
lb_control/     upstream down/restore・nginx reload・drain 待機
```

各ロールはローリング更新の 1 フェーズに対応しており、単独での実行・テストが可能。
