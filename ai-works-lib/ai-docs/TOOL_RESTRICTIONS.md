# 利用制限のあるツールリスト

このドキュメントには、利用に何らかの制限があるツールの一覧が記載されています。
制限には、**時間ベースの制限**（クールダウン/ロック）と、**サイクルベースの制限**（1ハートビートあたりの使用回数）などがあります。

## 遵守事項
- **サイクルベースの制限**は、AI自身がこのドキュメントを読んで遵守する必要があります。
- **時間ベースの制限**を持つツールを使用した後は、必ず `report_tool_usage` を呼び出し、実行結果（`success` または `quota_exceeded`）をシステムに報告してください。これにより、システムがクールダウン/ロックを正しく管理できます。

## 制限対象ツール一覧

- ツールID: `gemini_cli.google_web_search`
  - gemini cli組み込みのgoogle_web_searchツール。クォータ制限あり。
  - **サイクル制限**: 1ハートビートで1回まで
  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）

- ツールID: `gemini_cli.web_fetch`
  - gemini cli組み込みのweb_fetchツール。クォータ制限あり。
  - **サイクル制限**: 1ハートビートで1回まで
  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）

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