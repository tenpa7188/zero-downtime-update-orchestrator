以下の手順でgit commitを実行してください。

1. `git status` と `git diff` を実行して変更内容を確認する
2. 変更内容を日本語で要約してコミットメッセージを作成する
   - 1行目: 変更の要約（50文字以内）
   - フォーマット例: `feat: nginx role にヘルスチェック機能を追加`
   - プレフィックス: feat / fix / docs / refactor / chore から適切なものを選ぶ
3. ステージされていないファイルを `git add` する（.vagrant/ や node_modules/ は除外）
4. 作成したメッセージで `git commit` を実行する
5. コミット結果を報告する
