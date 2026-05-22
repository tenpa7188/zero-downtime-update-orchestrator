---
name: ansible-dry-codegen
description: Ansible の playbook、role、inventory、group_vars、handler、template を DRY な構成で生成・リファクタリングする。role 境界、環境別 override、重複削減を意識して ansible/** を編集・作成・レビュー・lint するときに使う。
paths:
  - ansible/**
---

# Ansible DRY コード生成

このリポジトリで Ansible コードを生成・修正・リファクタリングするときに使う。

## 作業手順

1. 編集前に既存の role、playbook、inventory、group_vars の書き方を読む。
2. 環境ごとの差分、role の default、task の流れ、再利用できる task 形状を分けて考える。
3. 広すぎる `common` role より、小さく明確な role 境界を優先する。
4. ユーザーが明示しない限り、振る舞いは変えない。
5. `ansible-playbook --syntax-check`、`yamllint`、`ansible-lint` で確認する。

## DRY ルール

- 安全な fallback 値は `roles/<role>/defaults/main.yml` に置く。
- 環境固有の値は `inventory/<env>/group_vars/` に置く。
- 複数 role が同じ group 向けに共有する値は `ansible/playbooks/group_vars/<group>.yml` に置く。
- dev/prod に同じ変数値を重複させず、同じ振る舞いなら role default に寄せる。
- `lb01` のようなホスト名を直書きせず、既存の role 変数があればそれを使う。
- nginx LB と AWS ALB のように backend が分かれる role は task ファイルを分割する。
- 各 task に同じ `when` を繰り返すより、`include_tasks` で backend 別 task に一度だけ振り分ける。
- template 配置や cleanup の繰り返しは、意味と module option が同じ場合だけ loop 化する。
- 運用意図が task 名で明確になるなら、無理に一つの抽象 task にまとめない。

## Ansible パターン

- 再利用する delegated role では `delegate_to: "{{ variable_name }}"` を優先する。
- `become: true` は権限が必要な task の近く、または全 task が権限を必要とする block に置く。
- バックアップ世代数、drain wait、port、package 名のような運用 knob は role defaults に置く。
- package version、cloud region、SSM 設定、host address のような実環境差分は inventory vars に置く。
- role 間の隠れた結合を避ける。複数 role が同じ値を必要とする場合は、`web_http_port` のような明確な共有変数を使う。
- check mode で実行できない task には明示的な guard を置く。

## レビューチェックリスト

- 繰り返しの `when` 条件は、たいてい `include_tasks` wrapper か block に移せる。
- `src`、`dest`、`owner`、`group`、`mode`、`backup` が同型の template task は loop 化を検討する。
- 繰り返しの cleanup shell は、parameterized task か role にする。
- dev/prod の group_vars にコピーされた値は、環境ポリシーでない限り role defaults に寄せる。
- 定義済みだが未使用の変数は、使うか削除する。
- playbook は role の orchestration に集中し、実装詳細は role 側に持たせる。
