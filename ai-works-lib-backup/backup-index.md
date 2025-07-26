# AI心臓システム ドキュメントバックアップ インデックス

**バックアップ作成日時**: 2025年1月26日
**目的**: GEMINI.mdリファクタリングのための既存ファイル退避

## バックアップファイル一覧

### メインドキュメント
- `GEMINI.md` - メインの動作ルールファイル（592行）
  - システム概要、モード管理、実行フロー
  - 活動種別の詳細定義
  - エラーハンドリング、制約事項

### 詳細ドキュメント群 (ai-docs/)
- `GUIDELINES.md` - 運用ガイドライン・内省活動詳細
- `OPERATION_DETAILS.md` - 運用詳細手順・ツール制限管理
- `THEME_MANAGEMENT_GUIDE.md` - テーマ管理完全ガイド・MCPツール活用
- `THEME_CONCEPT_GUIDE.md` - テーマ概念説明・設計思想
- `THEME_CONTEXT_IMPLEMENTATION.md` - テーマ専門家コンテキスト実装
- `TOOL_RESTRICTIONS.md` - ツール使用制限・クールダウン管理
- `TROUBLESHOOTING_GUIDE.md` - トラブルシューティング・異常検知対応
- `MCP_WARNING_GUIDE.md` - MCPツール警告対応・エラーハンドリング

### 設定ファイル (.gemini/)
- `settings.json` - Gemini CLI設定（MCP設定含む）

## 情報分類

### 必須情報（新GEMINI.mdに含めるべき）
1. **システム基本概念**
   - ハートビートの概念と目的
   - テーマ中心の活動組織
   - 4つの動作モード

2. **基本実行フロー**
   - ハートビートID確認
   - 活動選択と実行
   - ファイル出力
   - 活動ログ記録
   - 完了報告

3. **6つの活動種別**
   - テーマ開始活動
   - 思考活動
   - 観測活動
   - 創造活動
   - 内省活動
   - テーマ終了活動

4. **基本制約**
   - ファイル操作範囲
   - 時間制限の基本
   - 完了報告後の制限

### 詳細情報（別ファイル化すべき）
1. **テーマ管理詳細**
   - サブテーマ分割ロジック
   - 専門家コンテキスト設定
   - テーマ終了判断基準

2. **ツール使用詳細**
   - MCPツール一覧と使用方法
   - クールダウン・制限管理
   - Web検索ツール対応

3. **エラー・例外処理**
   - 異常検知システム
   - 回復処理手順
   - トラブルシューティング

4. **高度な機能**
   - deep_work宣言システム
   - チェックポイントログ
   - feedbackboxシステム

### 重複・整理対象情報
1. **テーマ関連情報の重複**
   - THEME_MANAGEMENT_GUIDE.md
   - THEME_CONCEPT_GUIDE.md
   - THEME_CONTEXT_IMPLEMENTATION.md
   → 統合してTHEME_SYSTEM.mdに再編成

2. **運用詳細の重複**
   - GUIDELINES.md
   - OPERATION_DETAILS.md
   → 基本操作と高度な機能に分離

3. **エラー処理の分散**
   - TROUBLESHOOTING_GUIDE.md
   - MCP_WARNING_GUIDE.md
   → ERROR_HANDLING.mdに統合

## 新構造への移植方針

### 新GEMINI.md (150-200行目標)
- 基本概念と実行フローのみ
- 具体例を活用した理解しやすい記述
- 詳細は別ファイル参照

### 新ai-docs/構造
```
BASIC_OPERATIONS.md      # 基本操作の詳細手順
ACTIVITY_DETAILS.md      # 各活動種別の詳細ガイド
THEME_SYSTEM.md          # テーマ管理統合版
TOOL_USAGE.md            # MCPツール使用ガイド
ERROR_HANDLING.md        # エラー・例外処理完全版
ADVANCED_FEATURES.md     # 高度な機能
TROUBLESHOOTING.md       # トラブルシューティング
```

## 注意事項
- 退避ファイルは新構造完成まで保持
- 重要な運用ノウハウの抜け漏れに注意
- AIファーストな視点での情報再編成を重視
- 既存の複雑な条件分岐は簡素化して移植

## 次のステップ
1. 新GEMINI.mdの基本構造設計
2. 必須情報の抽出と簡潔化
3. 詳細ドキュメントの再構築計画