# テーマ：read_many_filesツールチュートリアル

## 目的：
read_many_filesツールの機能と、特に`respect_git_ignore`、`exclude`、`include`オプションの挙動を理解する。

## ステップ0: テストファイルの作成
* `projects/tutorial_theme/read_many_files_test/`ディレクトリを作成し、その中に以下のファイルを作成する。
  * `file1.txt`: `This is file1.`
  * `file2.log`: `This is file2.log.`
  * `file3.md`: `This is file3.md.`
  * `temp/file4.tmp`: `This is file4.tmp.`

## ステップ1: 基本的なファイル読み込み
* `read_many_files`ツールを使用して、`projects/tutorial_theme/read_many_files_test/`ディレクトリ内の全ての`.txt`ファイルを読み込む。
  * `paths`: `["./**/*.txt"]`
  * `path`: `projects/tutorial_theme/read_many_files_test/`の絶対パス

## ステップ2: `.gitignore`の影響を理解する（仮想）
* 実際には`.gitignore`ファイルを作成しませんが、もし`projects/tutorial_theme/read_many_files_test/.gitignore`に`*.log`が記述されていた場合、`*.log`ファイルは読み込まれないことを想定して考察する。
* `read_many_files`ツールを使用して、`projects/tutorial_theme/read_many_files_test/`ディレクトリ内の全てのファイルを読み込もうとする。
  * `paths`: `["./**/*"]`
  * `path`: `projects/tutorial_theme/read_many_files_test/`の絶対パス
  * `respect_git_ignore`: `true` (デフォルト)
* 結果が`file2.log`を含まないことを想定し、`.gitignore`の影響を考察する。

## ステップ3: `.gitignore`を無視して読み込む（仮想）
* ステップ2と同じ条件で、`respect_git_ignore: false`を指定して再度読み込む。
* `file2.log`が読み込まれることを想定し、`respect_git_ignore`の効果を考察する。

## ステップ4: `exclude`オプションの使用
* `projects/tutorial_theme/read_many_files_test/`ディレクトリ内の全てのファイルを読み込む際に、`.log`ファイルを除外する。
  * `paths`: `["./**/*"]`
  * `path`: `projects/tutorial_theme/read_many_files_test/`の絶対パス
  * `exclude`: `["**/*.log"]`

## ステップ5: `include`オプションの使用
* `projects/tutorial_theme/read_many_files_test/`ディレクトリ内のファイルから、`.md`ファイルのみを読み込む。
  * `paths`: `["./**/*"]`
  * `path`: `projects/tutorial_theme/read_many_files_test/`の絶対パス
  * `include`: `["**/*.md"]`

## ステップ6: 複合的な条件での読み込み
* `projects/tutorial_theme/read_many_files_test/`ディレクトリ内のファイルから、`file1.txt`と`file3.md`のみを読み込む。
  * `paths`: `["file1.txt", "file3.md"]`
  * `path`: `projects/tutorial_theme/read_many_files_test/`の絶対パス

## ステップ7: 内省活動
* `read_many_files`ツールの各オプションが、どのようなシナリオで有効かを考察する。
* 大規模なプロジェクトでのファイル検索・読み込みにおけるベストプラクティスを検討する。

---