# テーマ管理ガイド

このドキュメントは、AI心臓システムにおけるテーマの選択・移行・履歴記録の全般的な管理方法を定義します。

## 1. テーマ移行時の処理概要

このガイドは、GEMINI.mdでテーマ移行が決定された際に参照する詳細手順を定義します。
ユーザーからの新たなテーマ指示がない場合、自律的に新しいテーマを決定してください。

## 2. テーマ選択の優先順位

### 2.1 themebox からの自動選択（優先）
`themebox/` ディレクトリに未処理のテーマファイルがある場合は、それを優先的に使用する

### 2.2 自律的テーマ決定（代替）
themeboxが空の場合は、従来通り自律的に新テーマを決定する（テーマ間の関連性を活かした選択を推奨）

## 3. themebox テーマ管理

### 3.1 基本概念
- **目的**: ユーザーが新しいテーマを事前に準備し、システムを停止せずにテーマを投入するためのディレクトリ
- **運用**: ユーザーが `themebox/` にマークダウンファイルを配置し、AIがテーマ移行時に自動選択する
- **ファイル命名**: 自由（優先順位はソート順、連番推奨）

### 3.2 除外ルール
- `draft.` で始まるファイル名は無視（編集中）
- `processed.` で始まるファイル名は無視（処理済み）

### 3.3 選択・処理方法
- **選択方法**: ソート順で最初の有効なファイルを選択
- **使用後処理**: 選択されたファイルに `processed.` プレフィックスを付与
- **ファイル内容**: ファイル内容をそのまま新テーマとして使用

## 4. テーマ履歴記録

### 4.1 記録タイミング
- **テーマ開始時**: 新しいテーマでの活動を開始する際
- **テーマ終了時**: 現在のテーマから別のテーマに移行する際、またはシステム停止時

### 4.2 保存場所
- ディレクトリ: `artifacts/theme_histories/`
- このディレクトリが存在しない場合は自動作成する

## 5. ファイル命名規則

### 5.1 テーマ開始記録
- ファイル名: `YYYYMMDDHHMMSS_start_テーマ名.md`
- 例: `20250115143000_start_AI自己研鑽.md`

### 5.2 テーマ終了記録
- ファイル名: `YYYYMMDDHHMMSS_end_テーマ名.md`
- 例: `20250115180000_end_AI自己研鑽.md`

### 5.3 タイムスタンプ
- ハートビートのタイムスタンプを使用
- 形式: YYYYMMDDHHMMSS（年月日時分秒）

## 6. ファイル内容

### 6.1 テーマ開始記録 (`_start_` ファイル)

```markdown
# テーマ開始: [テーマ名]

**ディレクトリ**: `artifacts/[実際のディレクトリ名]/`

**開始理由**: 
[初期テーマ/前テーマ「XXX」から移行/など]

**活動内容**: 
[このテーマで何を行うか]
```

### 6.2 テーマ終了記録 (`_end_` ファイル)

```markdown
# テーマ終了: [テーマ名]

**ディレクトリ**: `artifacts/[実際のディレクトリ名]/`

**終了理由**: 
[完了/新テーマ「XXX」へ移行/など]

**主な成果**: 
[重要な成果物や発見の簡潔な説明]
```

## 7. 作成手順

### 7.1 テーマ開始時
1. 新しいテーマでの活動開始を決定
2. **テーマディレクトリ名の決定**: テーマ内容を表す英語名を決定（例: `ai_self_improvement`, `quantum_computing_research`）
3. `artifacts/theme_histories/` ディレクトリの存在確認・作成
4. 上記フォーマットに従って `_start_` ファイルを作成（ディレクトリ名を記録）
5. 通常の思考ログ記録を実行

### 7.2 テーマ終了時
1. テーマ移行またはシステム停止を決定
2. 上記フォーマットに従って `_end_` ファイルを作成
3. 新テーマに移行する場合は、続けて新テーマの `_start_` ファイルを作成

## 8. 注意事項

- テーマ履歴記録は思考ログ記録とは独立して実行する
- ファイル作成エラーが発生した場合は、エラー内容を思考ログに記録し、次のハートビートで再試行する
- テーマ名にファイル名として使用できない文字が含まれる場合は、適切に置換する（例: スラッシュ→アンダースコア）