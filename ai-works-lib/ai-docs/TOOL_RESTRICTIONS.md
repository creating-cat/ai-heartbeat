# ツール利用制限ガイド

このドキュメントには、利用に何らかの制限があるツールの一覧と、その制限を遵守するためのルールが記載されています。

## 目次

1. [遵守事項（最重要）](#1-遵守事項最重要)
2. [制限対象ツール一覧](#2-制限対象ツール一覧)
3. [ツール使用報告システム](#3-ツール使用報告システム)

## 1. 遵守事項（最重要）

### サイクルベースの制限
「1活動サイクルで1回まで」といった**サイクルベースの制限**は、AI自身がこのドキュメントを読んで遵守する必要があります。

### 時間ベースの制限
**時間ベースの制限**（クールダウン/ロック）を持つツールを使用した後は、**必ず `report_tool_usage` を呼び出し**、実行結果（`success` または `quota_exceeded`）をシステムに報告してください。これにより、システムがクールダウン/ロックを正しく管理できます。

## 2. 制限対象ツール一覧

### Web検索ツール
- **ツールID**: `gemini_cli.google_web_search`
  - **説明**: gemini cli組み込みのgoogle_web_searchツール。クォータ制限あり。
  - **サイクル制限**: 1活動サイクルで1回まで
  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）

- **ツールID**: `gemini_cli.web_fetch`
  - **説明**: gemini cli組み込みのweb_fetchツール。クォータ制限あり。
  - **サイクル制限**: 1活動サイクルで1回まで
  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）

### 外部フェッチツール
- **ツールID**: `mult-fetch-mcp-server.fetch_html`, `mult-fetch-mcp-server.fetch_json`, `mult-fetch-mcp-server.fetch_txt`, `mult-fetch-mcp-server.fetch_markdown`, `mult-fetch-mcp-server.fetch_plaintext`
  - **説明**: mult-fetch-mcp-serverのfetch関連ツール。クォータ制限なし。
  - **サイクル制限**: 連続使用時は`sleep 1`等を使用して一秒以上間隔を空けること
  - **時間制限**: なし

### カテゴリ生成ツール
- **ツールID**: `creative-ideation-mcp.generate_categories`
  - **説明**: creative-ideation-mcpのgenerate_categoriesツール。クォータ制限ありだが実質ほぼなし。
  - **サイクル制限**: 1活動サイクルで1回まで
  - **時間制限**: なし

## 3. ツール使用報告システム

`report_tool_usage` ツールは、時間ベースの制限を持つツールの使用状況をシステムに報告するために使用します。

**パラメータ**:
- `toolId` (string): 報告対象のツールID
- `status` (string): 'success' または 'quota_exceeded'

**使用例**:
`gemini_cli.google_web_search` が成功した場合:
```
report_tool_usage({
  toolId: 'gemini_cli.google_web_search', 
  status: 'success'
})
```

### 手動での状態報告（代替手段）
MCPツールが利用できない場合や、基本的なファイル操作として、以下のコマンドを実行して状態ファイルを手動で作成してください。

**成功 (`success`) の場合:**
ツールが正常に完了したことを示すため、クールダウン用のファイルを作成します。
```bash
touch stats/cooldown/{toolId}
```
**例:** `gemini_cli.google_web_search` が成功した場合
```bash
touch stats/cooldown/gemini_cli.google_web_search
```

**クォータ超過 (`quota_exceeded`) の場合:**
ツールのAPIクォータ制限に達したことを示すため、ロック用のファイルを作成します。
```bash
touch stats/lock/{toolId}
```
**例:** `gemini_cli.google_web_search` でクォータエラーが発生した場合
```bash
touch stats/lock/gemini_cli.google_web_search
```

**報告が必要なツール**:
- gemini_cli.google_web_search
- gemini_cli.web_fetch