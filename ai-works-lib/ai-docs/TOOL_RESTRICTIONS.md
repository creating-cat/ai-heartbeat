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
**時間ベースの制限**（クールダウン/ロック）を持つツールを使用した後は、後述の`3. ツール使用報告`を参照し、システムへツールの使用結果を報告してください。これにより、システムがクールダウン/ロックを正しく管理できます。


## 2. 制限対象ツール一覧

- ツールID: `gemini_cli.google_web_search`
  - gemini cli組み込みのgoogle_web_searchツール。クォータ制限あり。
  - **サイクル制限**: 1ハートビートで1回まで
  - **時間制限**: あり（使用後にシステムへの報告が必要）

- ツールID: `gemini_cli.web_fetch`
  - gemini cli組み込みのweb_fetchツール。クォータ制限あり。
  - **サイクル制限**: 1ハートビートで1回まで
  - **時間制限**: あり（使用後にシステムへの報告が必要）

- ツールID: `mult-fetch-mcp-server.fetch_html`
- ツールID: `mult-fetch-mcp-server.fetch_json`
- ツールID: `mult-fetch-mcp-server.fetch_txt`
- ツールID: `mult-fetch-mcp-server.fetch_markdown`
- ツールID: `mult-fetch-mcp-server.fetch_plaintext`
  - mult-fetch-mcp-serverのfetch関連ツール。クォータ制限なし。
  - **サイクル制限**: 連続使用時は`sleep 1`等を使用して一秒以上間隔を空けること
  - **時間制限**: なし

- ツールID: `creative-ideation-mcp.generate_categories`
  - mult-fetch-mcp-serverのgenerate_categoriesツール。クォータ制限ありだが実質ほぼなし。
  - **サイクル制限**: 1ハートビートで1回まで
  - **時間制限**: なし


## 3. ツール使用報告

### 3.1. ツール使用報告方法

時間制限のあるツールを使用した場合、そのツールの使用結果をシステムに報告する必要があります。
報告方法は以下になります。

- 実行結果が成功だった場合
  - ツールが正常に完了したことを示すため、クールダウン用の以下のファイルを作成します。
    - `stats/cooldown/{toolId}`
    - ファイル内容は空で良いです。
    - 例: `gemini_cli.google_web_search` が成功した場合に作成するファイル
      - `stats/cooldown/gemini_cli.google_web_search`

- 実行結果がクォータ超過だった場合
  - ツールのAPIクォータ制限に達したことを示すため、ロック用のファイルを作成します。
    - `stats/lock/{toolId}`
    - ファイル内容は空で良いです。
    - 例: `gemini_cli.google_web_search` でクォータエラーが発生した場合
      - `stats/lock/gemini_cli.google_web_search`


### 3.2. MCPツールを利用した報告の効率化手段・
上記のファイルを作成するためのMCPツールとして、`report_tool_usage` があります。
時間ベースの制限を持つツールの使用状況をシステムに報告するために使用します。

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
