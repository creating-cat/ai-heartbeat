# テーマ：replaceツールチュートリアル

## 目的：
replaceツールの厳密なマッチング、`expected_replacements`、および安全な使用方法を理解する。

## ステップ0: テストファイルの作成
* `projects/tutorial_theme/replace_test/`ディレクトリを作成し、その中に`target.txt`ファイルを作成する。
  * `target.txt`: 
  ```
  Line 1: Apple is red.
  Line 2: Banana is yellow.
  Line 3: Apple is sweet.
  Line 4: Grape is purple.
  ```

## ステップ1: 単一の置換
* `target.txt`の`Apple is red.`を`Orange is orange.`に置換する。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Line 1: Apple is red.`
  * `new_string`: `Line 1: Orange is orange.`

## ステップ2: 複数箇所の置換
* `target.txt`の`Apple`を`Orange`に全て置換する。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Apple`
  * `new_string`: `Orange`
  * `expected_replacements`: `2`

## ステップ3: 厳密なマッチングの理解
* `target.txt`の`Line 2: Banana is yellow.`を`Line 2: Banana is green.`に置換しようとするが、`old_string`に余分なスペースを含ませて失敗させる。
  * `file_path`: `projects/tutorial_theme/replace_test/target.txt`の絶対パス
  * `old_string`: `Line 2: Banana is yellow. ` (末尾にスペース)
  * `new_string`: `Line 2: Banana is green.`
* エラーメッセージを確認し、厳密なマッチングの重要性を考察する。

## ステップ4: 置換前のファイル内容確認
* `replace`ツールを使用する前に、必ず`read_file`ツールで対象ファイルの内容を確認する。

## ステップ5: 内省活動
* `replace`ツールの安全な使用方法と、どのようなシナリオで活用できるかを考察する。
* コードのリファクタリングや設定ファイルの一括変更など、具体的な応用例を検討する。

---