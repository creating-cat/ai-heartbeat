# テーマ: AI心臓システムスナップショット取得のためのハートビートの一旦停止

## テーマの目的
ユーザーが安全に現在のAI心臓システムのスナップショットを取得するために、
ハートビートを一旦停止し、活動を停止した状態でスナップショットを取得できるようにする。

### 実行手順
1. **ハートビート停止**: `stop.sh`を実行してハートビートを停止する。
2. **割り込み処理実施**: `interrupt_for_snapshot.sh &`として割り込み処理をバックグラウンド実行する。
3. **安定するまで待つ**: `sleep 30`を実行してしばらく待つ。
  - この間にユーザーがスナップショットを取り、その後ハートビートがリスタートされます。
4. **本テーマ終了**: 本テーマの終了活動を行う。

### 重要な注意事項
- あなたはスナップショットそのものを認識する必要はありません。
- もしかしたら`sleep 30`は途中でユーザーによってキャンセルされるかもしれませんが、その後ハートビートを受け取ったらテーマ終了活動に進んで大丈夫です。
- もしかしたらsleep後の最初の活動ログ作成時やチェックポイントログ作成時に、何らかの警告が表示される可能性がありますが、スナップショットからの再開による時間経過のためである可能性があるので、この最初の警告は無視して良いです。