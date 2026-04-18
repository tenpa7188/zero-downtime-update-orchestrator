WSL上で以下のlintコマンドを実行してください。

```bash
wsl -d Ubuntu-24.04 -- bash -c "cd /mnt/c/source/zero-downtime-update-orchestrator/ansible && echo '=== yamllint ===' && yamllint ./ && echo '=== ansible-lint ===' && ansible-lint playbooks/ --nocolor"
```

結果を表示し、エラーがあれば原因と修正方法を説明してください。
エラーがなければ「lint OK」と報告してください。
