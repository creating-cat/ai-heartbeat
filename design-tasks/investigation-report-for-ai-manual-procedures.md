# AI向けドキュメントの手動操作手順の明確化に関する調査報告

## 1. 概要

このドキュメントは、タスク「AI向けドキュメントの手動操作手順の明確化」(`document-ai-manual-procedures.md`) の基礎情報として、AI向けドキュメントに不足している手動操作手順の詳細を調査した結果をまとめたものです。

AIがMCPツールに依存せず、自律的にタスクを遂行できるよう、ツールの内部実装 (`mcp/ai-heartbeat-mcp/`) と旧ドキュメント (`ai-works-lib.backup/`) を参照し、具体的なファイル操作の仕様を明らかにしました。

## 2. 調査結果詳細

### 2.1. テーマ履歴記録の手動作成方法

-   **関連ドキュメント**: `ai-docs/THEME_SYSTEM.md`
-   **調査対象ツール**: `create_theme_log` (`mcp/ai-heartbeat-mcp/src/tools/themeLogTool.ts`)

#### 判明した仕様

**A. ファイルの保存場所と命名規則**

-   **保存場所**: `artifacts/theme_histories/`
-   **命名規則**:
    -   テーマ開始時: `{THEME_START_ID}_start_{themeDirectoryPart}.md`
    -   テーマ終了時: `{THEME_END_ID}_end_{themeDirectoryPart}.md`

**B. ファイルフォーマット**

**メインテーマ開始時のフォーマット:**
```markdown
# テーマ開始: [テーマ名]

**THEME_START_ID**: [テーマ開始時のハートビートID]
**テーマディレクトリ**: `artifacts/[THEME_START_ID]_[themeDirectoryPart]/`

**開始理由**: 
[テーマの開始理由]

**活動内容**: 
[このテーマで何を行うか]
```

**サブテーマ開始時のフォーマット:**
```markdown
# サブテーマ開始: [サブテーマ名]

**PARENT_THEME_START_ID**: [親テーマのTHEME_START_ID]
**PARENT_THEME_DIRECTORY**: [親テーマのディレクトリ名]
**THEME_START_ID**: [サブテーマ開始時のハートビートID]
**テーマディレクトリ**: `artifacts/[PARENT_THEME_START_ID]_[親テーマディレクトリ]/subthemes/[THEME_START_ID]_[サブテーマディレクトリ]/`

**開始理由**: 
[サブテーマの開始理由]

**活動内容**: 
[このサブテーマで何を行うか]
```

**テーマ終了時のフォーマット:**
```markdown
# テーマ終了: [テーマ名]

**THEME_START_ID**: [テーマ開始時のハートビートID]
**THEME_END_ID**: [テーマ終了時のハートビートID]

**終了理由**: 
[テーマの終了理由]

**主な成果**: 
[主な成果物のリスト]
```

### 2.2. 専門家コンテキストの手動作成方法

-   **関連ドキュメント**: `ai-docs/ADVANCED_FEATURES.md`
-   **調査対象ツール**: `create_theme_expert_context` (`mcp/ai-heartbeat-mcp/src/tools/createThemeExpertContextTool.ts`)

#### 判明した仕様

**A. ファイルの保存場所と命名規則**

-   **保存場所**: `artifacts/{THEME_START_ID_テーマ名}/contexts/`
-   **ファイル名**: `{ハートビートID}.md`

**B. ファイルフォーマット**

```markdown
# テーマ専門家コンテキスト

## 専門家設定
**[専門家としての役割・立場・専門分野]**

## 専門性・役割
- [このテーマにおける専門的な視点やアプローチ]

## 重要な制約・注意事項
- [活動する上での制約や注意点]

## 期待される成果
- [このコンテキストで期待される成果や方向性]
```

### 2.3. `themebox`/`feedbackbox`の手動処理フロー

-   **関連ドキュメント**: `ai-docs/ADVANCED_FEATURES.md`
-   **調査対象ツール**: `check_and_process_item` (`mcp/ai-heartbeat-mcp/src/tools/itemProcessorTool.ts`)

#### 判明した仕様

1.  **対象ディレクトリの確認**: `ai-works/themebox/` または `ai-works/feedbackbox/` を確認します。
2.  **処理対象ファイルの検索と選定**:
    -   ディレクトリ内の `.md` ファイルを検索します。
    -   `draft.` や `processed.` のプレフィックスが付いているファイルは無視します。
    -   残ったファイルを名前順でソートし、**最初の1つ**を処理対象として選択します。
3.  **ファイルの処理とリネーム**:
    -   選択したファイルの内容を読み込みます。
    -   読み込み後、ファイル名の先頭に `processed.` プレフィックスを付けてリネームします。 (例: `mv themebox/new_idea.md themebox/processed.new_idea.md`)