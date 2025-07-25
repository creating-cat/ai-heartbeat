# テーマ：Gemini CLI組み込みツール総合チュートリアル

## 目的：
Gemini CLIの主要な組み込みツール（`read_many_files`、`replace`、`run_shell_command`）の効率的な使用方法とベストプラクティスを体系的に理解し、実践的なスキルを身につける。

## 事前準備
* `projects/tutorial_theme/`ディレクトリを作成し、チュートリアル用の作業環境を整備する。

## セクション1: read_many_filesツール - 効率的なファイル読み込み

### ステップ1.1: 基本的なファイル読み込み
* `read_many_files`ツールを使用して、`ai-works/artifacts/`ディレクトリ配下の全ての`.md`ファイルを読み込む。
  * **考察**: ファイルパターンの指定方法と、効率的な読み込み方法について考察する。
* **パス指定のベストプラクティス**: 絶対パスでの読み込みを推奨し、その理由（安定性、明確性）を簡潔に説明する。

### ステップ1.2: 応用的な使用方法
* 複数のディレクトリから特定の拡張子のファイルを読み込む実例を試す。
* ファイル名パターンを使用した柔軟な読み込み方法を実践する。

### ステップ1.3: 大量ファイル処理の考察
* `read_many_files`ツールの効率的な使用方法について考察する。
* 大量のファイルを扱う際の注意点や最適化方法を検討する。

## セクション2: replaceツール - 安全で正確なファイル編集

### ステップ2.1: テストファイルの作成
* `projects/tutorial_theme/replace_test/`ディレクトリを作成し、その中に`target.txt`ファイルを作成する。
  * `target.txt`の内容: 
  ```
  Line 1: Apple is red.
  Line 2: Banana is yellow.
  Line 3: Apple is sweet.
  Line 4: Grape is purple.
  ```

### ステップ2.2: 正確な置換のデモンストレーションと`old_string`の厳密性
* `read_file`で`target.txt`の内容を確認後、`old_string`を完全に一致させて単一置換を成功させる。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Line 1: Apple is red.`
  * `new_string`: `Line 1: Orange is orange.`
* `read_file`で`target.txt`の内容を確認後、`old_string`にわざと空白を追加して元の文字列と不一致させることで単一置換を失敗させる。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Line 2: Banana is yellow. `
  * `new_string`: `Line 2: Muscat is green.`
* **考察**: `replace`ツールが`old_string`の厳密な一致を要求することの重要性を強調する。**特に、改行コード、空白、インデントのわずかな違いでもマッチしない**ことを説明し、以下の点に注意を促す。
    *   `old_string`は、置換対象のテキストを**完全にコピー＆ペースト**して使用することを強く推奨する。
    *   目に見えない文字（スペース、タブ、改行）が一致しているか、テキストエディタの機能などで確認する。
    *   `read_file`でファイルの内容を読み込み、その結果を直接`old_string`として使用することで、最も正確な文字列を取得できる。

### ステップ2.3: 複数置換と安全な運用
* `expected_replacements`を指定した複数置換をデモする。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Apple`
  * `new_string`: `Orange`
  * `expected_replacements`: `2`
* **考察**: `replace`ツール使用前の`read_file`による内容確認の習慣化を強く推奨する。意図しない置換を防ぐための具体的なチェックポイントを提示する。**複数置換の場合も、`old_string`の厳密性は変わらない**ことを強調する。

## セクション3: run_shell_commandツール - システム操作とプロセス管理

### ステップ3.1: 基本的なコマンド実行と出力の理解
* `ls -l`や`echo`など、基本的なコマンドをいくつか実行し、`stdout`、`stderr`、`exit code`の確認方法を学ぶ。
* `description`と`directory`引数の活用方法を実践し、これらがAIの活動の透明性と正確性にどう貢献するかを考察する。

### ステップ3.2: 長時間処理と`timeout`コマンド
* `sleep 5`コマンドを`timeout 2s`で実行し、2秒後に強制終了されることを確認する。
  * **考察**: `npm install`のような長時間コマンドを安全に実行するために`timeout`が不可欠であることを強調する。
  * **`declare_extended_processing`ツールによる事前宣言の重要性**と、それが活動ログ頻度異常を防ぐメカニズムについて深く考察する。

### ステップ3.3: バックグラウンド実行とプロセス管理
* `sleep 10 &`コマンドをバックグラウンドで実行し、PIDとPGIDを確認する。
* **考察**: バックグラウンドプロセスを起動した場合、AIがそのプロセスを明示的に終了させる責任があることを強調する。`kill`コマンドや`kill -- -PGID`によるプロセス終了方法を説明し、リソース管理の重要性を考察する。

## セクション4: 統合実践 - 3つのツールの連携活用

### ステップ4.1: 実践的なワークフロー
* `read_many_files`でプロジェクトファイルを調査
* `replace`で設定ファイルを更新
* `run_shell_command`でビルドやテストを実行
という一連のワークフローを実践する。

### ステップ4.2: エラーハンドリングとトラブルシューティング
* 各ツールで発生しうる典型的なエラーケースを意図的に発生させ、適切な対処方法を学ぶ。
* **`replace`ツールのエラー**: `old_string`が一致しない場合のエラーメッセージを理解し、`read_file`で正確な文字列を取得して再試行する方法を具体的に説明する。
* ツール間の連携時に注意すべきポイントを整理する。

## セクション5: 総合内省活動

### ステップ5.1: ツール使用の最適化
* 3つのツールそれぞれの特性と最適な使用場面について総合的に考察する。
* 効率的なファイル操作、安全な編集作業、適切なシステム操作の原則を整理する。

### ステップ5.2: AI心臓システムとの関連性
* これらの組み込みツールがAI心臓システムの運用安定性にどのように貢献するかについて深く考察する。
* 自律的なAI活動における各ツールの役割と重要性を分析する。

### ステップ5.3: 将来の応用可能性
* 学習した知識を活用して、より複雑な自動化タスクや開発ワークフローにどう応用できるかを検討する。
* 継続的な学習と改善のためのアプローチを考察する。

## 完了条件
* 3つの主要ツールの基本的な使用方法を習得
* 各ツールの安全な使用方法とベストプラクティスを理解
* ツール間の連携による効率的なワークフローを実践
* AI心臓システムにおける各ツールの役割を理解

一連の活動が終わったら、このテーマを終了してください。