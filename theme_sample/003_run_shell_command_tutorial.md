# テーマ：run_shell_commandツールチュートリアル

## 目的：
run_shell_commandツールの基本的な使用方法、`timeout`コマンドとの連携、およびバックグラウンド実行を理解する。

## ステップ1: 基本的なコマンド実行
* `ls -l`コマンドを実行し、現在のディレクトリの内容をリスト表示する。

## ステップ2: `timeout`コマンドとの連携
* `sleep 5`コマンドを`timeout 2s`で実行し、2秒後に強制終了されることを確認する。
  * `command`: `timeout 2s sleep 5`
* `npm install`のような長時間かかるコマンドを安全に実行する方法を考察する。

## ステップ3: バックグラウンド実行
* `sleep 10 &`コマンドをバックグラウンドで実行し、すぐにプロンプトが返ってくることを確認する。
  * `command`: `sleep 10 &`
* バックグラウンドで実行されたプロセスの管理（PGIDなど）について考察する。

## ステップ4: `description`引数の使用
* `echo "Hello from shell!"`コマンドを`description`引数付きで実行する。
  * `command`: `echo "Hello from shell!"`
  * `description`: `シェルからメッセージを表示します。`

## ステップ5: `directory`引数の使用
* `projects/tutorial_theme`ディレクトリ内で`ls -l`コマンドを実行する。
  * `command`: `ls -l`
  * `directory`: `ai-works/projects/tutorial_theme`の相対パス

## ステップ6: 内省活動
* `run_shell_command`ツールの安全な使用方法と、どのようなシナリオで活用できるかを考察する。
* 開発サーバーの起動と停止、ログの監視、特定のスクリプトの自動実行など、具体的な応用例を検討する。

---
