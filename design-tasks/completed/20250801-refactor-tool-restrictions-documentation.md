# ツール利用制限に関するドキュメントの分離

## 1. 概要

### 1.1. 目的
現在 `ai-works-lib/ai-docs/TOOL_USAGE.md` に集約されている「ツールの利用制限」に関する情報を、独立した `TOOL_RESTRICTIONS.md` ファイルに分離する。
これにより、ドキュメントの保守性を向上させ、AIが利用制限をより迅速かつ正確に把握できるようにする。

### 1.2. 背景
今後、利用制限のあるツールが追加・変更される可能性が高い。
現状の `TOOL_USAGE.md` では、重要な制限事項が他の情報に埋もれてしまい、可読性が低下する懸念がある。
「ツールの使い方」と「ツールの制約」という関心を分離することで、各ドキュメントの目的を明確化し、AIにとっても開発者にとっても理解しやすい構造を目指す。

---

## 2. 修正方針

### 2.1. `TOOL_RESTRICTIONS.md` の新規作成
- `ai-works-lib/ai-docs/` 配下に `TOOL_RESTRICTIONS.md` を新規作成する。
- `TOOL_USAGE.md` の「4. 制限のあるツール群」セクションの内容を、この新しいファイルに完全に移設する。

### 2.2. `TOOL_USAGE.md` の修正
- 移設した「4. 制限のあるツール群」セクションを削除する。
- 代わりに、新しく作成した `TOOL_RESTRICTIONS.md` への参照を追記する。

### 2.3. 関連ドキュメントの参照更新
- `GEMINI.md` の「7. 詳細情報リソース」リストに `TOOL_RESTRICTIONS.md` を追加する。
- `ai-works-lib/ai-docs/ACTIVITY_DETAILS.md` の「観測の注意事項」セクションにあるツール制限に関する参照先を、`TOOL_RESTRICTIONS.md` に更新する。

---

## 3. 影響範囲

- **新規作成**:
  - `ai-works-lib/ai-docs/TOOL_RESTRICTIONS.md`
- **修正対象**:
  - `ai-works-lib/ai-docs/TOOL_USAGE.md`
  - `ai-works-lib/GEMINI.md`
  - `ai-works-lib/ai-docs/ACTIVITY_DETAILS.md`

---

## 4. 完了の定義

- `TOOL_RESTRICTIONS.md` が、`TOOL_USAGE.md` から移設された正しい情報を含んで作成されている。
- `TOOL_USAGE.md` から利用制限に関する詳細な記述が削除され、`TOOL_RESTRICTIONS.md` への参照に置き換えられている。
- `GEMINI.md` と `ACTIVITY_DETAILS.md` の参照先が正しく更新されている。
- 上記の変更によって、ドキュメント間の情報に矛盾や欠落が生じていない。

---

## 5. 参考情報（具体的な修正diff案）

以下は、このタスクを実行するための具体的なdiff案です。これを参考に実装を進めてください。

### `TOOL_RESTRICTIONS.md` (新規作成)
```diff
--- /dev/null
+++ b/ai-works-lib/ai-docs/TOOL_RESTRICTIONS.md
@@ -0,0 +1,46 @@
+# ツール利用制限ガイド
+
+このドキュメントには、利用に何らかの制限があるツールの一覧と、その制限を遵守するためのルールが記載されています。
+
+## 目次
+
+1. [遵守事項（最重要）](#1-遵守事項最重要)
+2. [制限対象ツール一覧](#2-制限対象ツール一覧)
+3. [ツール使用報告システム](#3-ツール使用報告システム)
+
+## 1. 遵守事項（最重要）
+
+### サイクルベースの制限
+「1活動サイクルで1回まで」といった**サイクルベースの制限**は、AI自身がこのドキュメントを読んで遵守する必要があります。
+
+### 時間ベースの制限
+**時間ベースの制限**（クールダウン/ロック）を持つツールを使用した後は、**必ず `report_tool_usage` を呼び出し**、実行結果（`success` または `quota_exceeded`）をシステムに報告してください。これにより、システムがクールダウン/ロックを正しく管理できます。
+
+## 2. 制限対象ツール一覧
+
+### Web検索ツール
+- **ツールID**: `gemini_cli.google_web_search`
+  - **説明**: gemini cli組み込みのgoogle_web_searchツール。クォータ制限あり。
+  - **サイクル制限**: 1活動サイクルで1回まで
+  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）
+
+- **ツールID**: `gemini_cli.web_fetch`
+  - **説明**: gemini cli組み込みのweb_fetchツール。クォータ制限あり。
+  - **サイクル制限**: 1活動サイクルで1回まで
+  - **時間制限**: あり（使用後に`report_tool_usage`での報告が必要）
+
+### 外部フェッチツール
+- **ツールID**: `mult-fetch-mcp-server.fetch_html`, `mult-fetch-mcp-server.fetch_json`, `mult-fetch-mcp-server.fetch_txt`, `mult-fetch-mcp-server.fetch_markdown`, `mult-fetch-mcp-server.fetch_plaintext`
+  - **説明**: mult-fetch-mcp-serverのfetch関連ツール。クォータ制限なし。
+  - **サイクル制限**: 連続使用時は`sleep 1`等を使用して一秒以上間隔を空けること
+  - **時間制限**: なし
+
+### カテゴリ生成ツール
+- **ツールID**: `creative-ideation-mcp.generate_categories`
+  - **説明**: creative-ideation-mcpのgenerate_categoriesツール。クォータ制限ありだが実質ほぼなし。
+  - **サイクル制限**: 1活動サイクルで1回まで
+  - **時間制限**: なし
+
+## 3. ツール使用報告システム
+
+`report_tool_usage` ツールは、時間ベースの制限を持つツールの使用状況をシステムに報告するために使用します。
+
+**パラメータ**:
+- `toolId` (string): 報告対象のツールID
+- `status` (string): 'success' または 'quota_exceeded'
+
+**使用例**:
+`gemini_cli.google_web_search` が成功した場合:
+`report_tool_usage({toolId: 'gemini_cli.google_web_search', status: 'success'})`
```

### `TOOL_USAGE.md`, `GEMINI.md`, `ACTIVITY_DETAILS.md` (修正)
```diff
--- a/ai-works-lib/ai-docs/TOOL_USAGE.md
+++ b/ai-works-lib/ai-docs/TOOL_USAGE.md
@@ -5,7 +5,7 @@
 1. MCPツールの概要と理念
 2. 基本的なツール群
 3. テーマ管理ツール群
-4. 制限のあるツール群
+4. ツール使用の制限
 5. 使用時の注意事項とベストプラクティス
 6. トラブルシューティング
 7. 関連ドキュメント
@@ -160,53 +160,13 @@
   themeStartId: "20250125143000"
 })
 ```
-
-## 4. 制限のあるツール群
-
-### 4.1 Web検索ツール
-
-#### gemini_cli.google_web_search
-**制限**: 1活動サイクルで1回まで、クォータ制限あり
-
-```
-google_web_search({
-  query: "検索クエリ"
-})
-```
-
-**使用後の必須処理**:
-```
-report_tool_usage({
-  toolId: "gemini_cli.google_web_search",
-  result: "success" // または "quota_exceeded"
-})
-```
-
-#### gemini_cli.web_fetch
-**制限**: 1活動サイクルで1回まで、クォータ制限あり
-
-```
-web_fetch({
-  url: "https://example.com"
-})
-```
-
-### 4.2 外部フェッチツール
-
-#### mult-fetch-mcp-server系ツール
-**制限**: 連続使用時は1秒以上の間隔が必要
-
-**対象ツール**:
-- `mult-fetch-mcp-server.fetch_html`
-- `mult-fetch-mcp-server.fetch_json`
-- `mult-fetch-mcp-server.fetch_txt`
-- `mult-fetch-mcp-server.fetch_markdown`
-- `mult-fetch-mcp-server.fetch_plaintext`
-
-**使用方法**:
-```
-fetch_html({ url: "https://example.com" })
-// 連続使用時は必ず1秒以上の間隔を空ける
-sleep 1
-fetch_json({ url: "https://api.example.com" })
-```
-
-**注意事項**:
-- **サイクル制限**: 連続使用時は`sleep 1`等を使用して一秒以上間隔を空けること
-- **時間制限**: なし（report_tool_usage不要）
-- **クォータ制限**: なし
-
-### 4.3 creative-ideation-mcp.generate_categories
-**制限**: 1活動サイクルで1回まで
-
-```
-generate_categories({
-  input: "カテゴリ生成の対象"
-})
-```
-
-**詳細制限**:
-- **サイクル制限**: 1活動サイクルで1回まで
-- **時間制限**: なし（report_tool_usage不要）
-- **クォータ制限**: ありだが実質ほぼなし
-
-### 4.4 ツール使用報告システム
-
-#### report_tool_usage の使用方法
-時間ベース制限を持つツールを使用した後は、システムがクールダウンやロックを正しく管理できるよう、ツールの実行結果を報告する必要があります。
-
-**MCPツールによる報告（推奨）**:
-```
-report_tool_usage({
-  toolId: "gemini_cli.google_web_search",
-  status: "success" // または "quota_exceeded"
-})
-```
-
-**手動での状態報告（代替手段）**:
-MCPツールが利用できない場合や、基本的なファイル操作として、以下のコマンドを実行して状態ファイルを手動で作成してください。
-
-*   **成功 (`success`) の場合:**
-    ツールが正常に完了したことを示すため、クールダウン用のファイルを作成します。
-    ```bash
-    touch stats/cooldown/{toolId}
-    ```
-    **例:** `gemini.google.search` が成功した場合
-    `touch stats/cooldown/gemini.google.search`
-
-*   **クォータ超過 (`quota_exceeded`) の場合:**
-    ツールのAPIクォータ制限に達したことを示すため、ロック用のファイルを作成します。
-    ```bash
-    touch stats/lock/{toolId}
-    ```
-    **例:** `gemini.google.search` でクォータエラーが発生した場合
-    `touch stats/lock/gemini.google.search`
-
-**報告が必要なツール**:
-
-- gemini_cli.google_web_search
-- gemini_cli.web_fetch
+ 
+## 4. ツール使用の制限
+
+一部のツールには、システムの安定性や外部サービスの利用規約を守るために、利用制限が設けられています。
+制限には、**サイクルベースの制限**（1活動サイクルあたりの使用回数）と、**時間ベースの制限**（クールダウン/ロック）があります。
+
+**重要**: 制限対象のツールと具体的なルールについては、必ず以下の専門ドキュメントを参照してください。
+
+**詳細**: `./TOOL_RESTRICTIONS.md` を参照
 
 ## 5. 使用時の注意事項とベストプラクティス
 
--- a/ai-works-lib/GEMINI.md
+++ b/ai-works-lib/GEMINI.md
@@ -248,6 +248,7 @@
 - `./ai-docs/ACTIVITY_DETAILS.md` - 各活動種別の詳細ガイド  
 - `./ai-docs/THEME_SYSTEM.md` - テーマ・サブテーマ管理
 - `./ai-docs/TOOL_USAGE.md` - MCPツール使用方法
- `./ai-docs/ERROR_HANDLING.md` - エラー・例外処理
+- `./ai-docs/TOOL_RESTRICTIONS.md` - ツール利用制限ガイド
+- `./ai-docs/ERROR_HANDLING.md` - エラー・例外処理
 - `./ai-docs/ADVANCED_FEATURES.md` - 高度な機能
 
--- a/ai-works-lib/ai-docs/ACTIVITY_DETAILS.md
+++ b/ai-works-lib/ai-docs/ACTIVITY_DETAILS.md
@@ -131,9 +131,7 @@
 - `get_latest_activity_log`ツール: 過去ログの効率的な参照
 
 ### 観測の注意事項
- Web検索ツールには利用制限がある場合がある
- `report_tool_usage`ツールでの結果報告が必要
- クォータ制限時は内部観測や既存知識を活用
+- Web検索ツールなど、一部のツールには利用制限があります。詳細は `./TOOL_RESTRICTIONS.md` を参照してください。
 - Web検索は効率化手段であり、常に利用できるとは限らない
 
 ### 基本的な実行手順
```
