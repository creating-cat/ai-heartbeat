# 思考ログ作成ツール設計書

## 概要

### 目的
AI心臓システムで動作するAIエージェントが、標準フォーマットに従った思考ログを効率的かつ確実に作成できるMCPツールを提供する。

### 対象システム
- AI心臓システム（本リポジトリ）
- Gemini CLI を使用するAIエージェント

### 設計日時・バージョン
- 初版作成: 2025年1月15日
- バージョン: v0.1.0-design

## 要件分析

### 現在の手動プロセス
AIエージェントは現在、以下の手動プロセスで思考ログを作成している：

```markdown
# ハートビートログ：YYYYMMDDHHMMSS

## 活動種別
[実行した活動種別（観測・思考・創造・内省・その他）。補助的な操作を使用した場合は、括弧書きで操作名を追記。例: 思考 (ファイル読み込み使用)]

## 活動内容
[今回のハートビートでの簡潔な活動内容。(詳細は関連ファイルに記載されていることが前提)]

## 成果物、関連ファイル
[このハートビートで作成または修正したファイルの**プロジェクトルートからの相対パス**を列挙(この思考ログファイル自身は除く)。例: artifacts/laughter/thoughts_on_laughter.md]

## 自己評価、備考
[このハートビートでの活動内容の評価やその他特記事項があれば記載。例: Web検索クォータ制限のため、文献調査を中断。]
```

### 解決したい課題
1. **フォーマットの一貫性**: 手動作成時のフォーマットブレ
2. **ファイル配置ミス**: 不適切なディレクトリへの保存
3. **重複ログ作成**: 同一ハートビートIDでの複数ログ作成
4. **パス記述ミス**: 相対パス形式の間違い
5. **ルール違反**: 運用ガイドラインの見落とし

### 期待される効果
1. **品質向上**: 標準化されたフォーマットでの一貫した記録
2. **エラー防止**: 自動バリデーションによる操作ミスの防止
3. **効率化**: 定型作業の自動化による思考活動への集中
4. **安全性**: 禁止操作の事前チェック

## 技術仕様

### MCP Tool Definition
```javascript
{
  name: "create_thinking_log",
  description: "AI心臓システム用の標準フォーマット思考ログを作成",
  inputSchema: {
    type: "object",
    properties: {
      heartbeatId: {
        type: "string",
        description: "ハートビートID (YYYYMMDDHHMMSS形式)",
        pattern: "^\\d{14}$"
      },
      activityType: {
        type: "string",
        description: "活動種別",
        enum: ["観測", "思考", "創造", "内省", "その他"]
      },
      activityContent: {
        type: "string",
        description: "活動内容の簡潔な説明"
      },
      artifacts: {
        type: "array",
        description: "作成・修正したファイルのパス一覧",
        items: { type: "string" },
        default: []
      },
      evaluation: {
        type: "string",
        description: "自己評価・備考",
        default: ""
      },
      auxiliaryOperations: {
        type: "array",
        description: "使用した補助操作",
        items: {
          type: "string",
          enum: ["ファイル読み込み", "軽微な検索", "軽微な置換", "Web検索", "その他"]
        },
        default: []
      },
      currentTheme: {
        type: "string",
        description: "現在のテーマ名（自動検出も可能）"
      }
    },
    required: ["heartbeatId", "activityType", "activityContent"]
  }
}
```

### 入力パラメータ詳細

#### heartbeatId (必須)
- 形式: YYYYMMDDHHMMSS (14桁の数字)
- 例: "20250115143000"
- バリデーション: 正規表現、未来日時チェック、重複チェック

#### activityType (必須)
- 値: "観測", "思考", "創造", "内省", "その他"
- 補助操作使用時は自動で括弧書き追加

#### activityContent (必須)
- 今回のハートビートでの活動内容
- 簡潔な説明（詳細は関連ファイルに記載前提）

#### artifacts (オプション)
- 作成・修正したファイルの相対パス配列
- プロジェクトルートからの相対パス
- 思考ログファイル自身は除外

#### evaluation (オプション)
- 自己評価や特記事項
- Web検索制限等の制約情報も記録

#### auxiliaryOperations (オプション)
- 使用した補助操作の配列
- activityTypeに自動で括弧書き追加

#### currentTheme (オプション)
- 現在のテーマ名
- 未指定時は自動検出を試行

### 出力形式
- 成功時: 作成されたファイルのパス情報
- エラー時: 詳細なエラーメッセージと修正提案

## アーキテクチャ設計

### コンポーネント構成

```
ThinkingLogTool
├── ThinkingLogValidator     # バリデーション層
├── ThemeDetector           # テーマ検出層
├── DirectoryManager        # ディレクトリ管理層
├── ThinkingLogGenerator    # ファイル生成層
├── DuplicationPreventer    # 重複防止層
└── ConfigIntegrator        # 設定統合層
```

### クラス設計

#### ThinkingLogValidator
```javascript
class ThinkingLogValidator {
  validateHeartbeatId(id) {
    // YYYYMMDDHHMMSS形式チェック
    // 未来日時でないかチェック
    // 既存ログとの重複チェック
  }
  
  validateFilePaths(paths) {
    // 相対パス形式チェック
    // 許可されたディレクトリ内かチェック
    // ファイル存在確認
  }
  
  validateThemeConsistency(theme, heartbeatId) {
    // 現在のテーマとの整合性チェック
    // テーマディレクトリの存在確認
  }
}
```

#### ThemeDetector
```javascript
class ThemeDetector {
  async getCurrentTheme() {
    // artifacts/配下のディレクトリから現在のテーマを推定
    // 最新のテーマ履歴ファイルから取得
    // フォールバック: ユーザー入力要求
  }
  
  async getThemeDirectory(theme) {
    // テーマ名から適切なディレクトリ名を生成
    // 既存ディレクトリとの重複チェック
  }
}
```

#### DirectoryManager
```javascript
class DirectoryManager {
  async ensureThemeStructure(theme) {
    // artifacts/{theme}/histories/ の作成
    // artifacts/{theme}/ の作成（存在しない場合）
    // 適切な権限設定
  }
  
  generateFilePath(theme, heartbeatId) {
    // artifacts/{theme}/histories/{heartbeatId}.md
    // 重複ファイル検出時の連番処理
  }
}
```

#### ThinkingLogGenerator
```javascript
class ThinkingLogGenerator {
  generateContent(params) {
    // 標準フォーマットでのマークダウン生成
    // 活動種別に補助操作を括弧書きで追加
    // 相対パス形式での成果物リスト生成
  }
  
  async writeToFile(content, filePath) {
    // ディレクトリ自動作成
    // ファイル書き込み
    // エラーハンドリング
  }
}
```

#### DuplicationPreventer
```javascript
class DuplicationPreventer {
  async checkExistingLogs(heartbeatId) {
    // 同一ハートビートIDのログ存在チェック
    // パターン異常検知（ADVICE_THINKING_LOG_PATTERN対応）
    // 警告またはエラー返却
  }
  
  async suggestSequentialName(basePath) {
    // _01, _02 等の連番提案
    // ただし運用ガイドラインに従い1回のみ許可
  }
}
```

#### ConfigIntegrator
```javascript
class ConfigIntegrator {
  async loadHeartbeatConfig() {
    // ../heartbeat.conf の読み込み
    // システム設定との整合性確保
  }
  
  async loadOperationGuidelines() {
    // ../ai-docs/ 配下のガイドライン参照
    // 動的なルール適用
  }
}
```

### データフロー

1. **入力受信**: MCPクライアントからのパラメータ受信
2. **バリデーション**: 入力パラメータの妥当性チェック
3. **テーマ検出**: 現在のテーマ情報の取得・確認
4. **重複チェック**: 既存ログとの重複確認
5. **ディレクトリ準備**: 必要なディレクトリ構造の作成
6. **コンテンツ生成**: 標準フォーマットでのマークダウン生成
7. **ファイル書き込み**: 指定場所への安全な書き込み
8. **結果返却**: 成功情報またはエラー詳細の返却

## 実装計画

### 開発フェーズ

#### Phase 1: 基本機能 (v0.1.0)
- [ ] 基本的なバリデーション機能
- [ ] 標準フォーマットでのファイル生成
- [ ] 簡単なテーマ検出
- [ ] 基本的なエラーハンドリング

#### Phase 2: 高度な機能 (v0.2.0)
- [ ] 重複検出・防止機能
- [ ] 設定ファイル統合
- [ ] 詳細なバリデーション
- [ ] 自動テーマ検出の改善

#### Phase 3: 拡張機能 (v0.3.0)
- [ ] テンプレート機能
- [ ] 統計情報収集
- [ ] バックアップ機能
- [ ] 他ツールとの連携

### 優先順位
1. **高**: 基本的な思考ログ作成機能
2. **中**: 重複防止・バリデーション強化
3. **低**: 統計・分析機能

### 依存関係
- Node.js 18+
- @modelcontextprotocol/sdk
- fs-extra (ファイル操作)
- date-fns (日時処理)
- zod (バリデーション)

## 使用例

### 基本的な使用
```javascript
// MCPクライアントから呼び出し
await mcp.call("create_thinking_log", {
  heartbeatId: "20250115143000",
  activityType: "思考",
  activityContent: "AI心臓システムのMCP設計について検討",
  artifacts: [
    "artifacts/ai_heartbeat_mcp/design_document.md"
  ],
  evaluation: "基本設計が完了。次回は実装に着手予定。",
  auxiliaryOperations: ["ファイル読み込み"]
});
```

### 自動検出を活用した使用
```javascript
await mcp.call("create_thinking_log", {
  heartbeatId: "20250115143000",
  activityType: "創造",
  activityContent: "新しいプロジェクトの初期実装"
  // currentTheme は自動検出
  // artifacts は作成されたファイルから自動検出（将来機能）
});
```

## エラーハンドリング

### エラーケース
1. **重複ハートビートID**: 既存ログとの競合
2. **無効なテーマ**: 存在しないテーマ指定
3. **ファイルパス違反**: 禁止ディレクトリへのアクセス
4. **フォーマット違反**: 不正なハートビートID形式
5. **ディスク容量不足**: ファイル書き込み失敗
6. **権限エラー**: ディレクトリ作成・ファイル書き込み権限不足

### 回復戦略
1. **自動修正**: 軽微なフォーマット違反の自動修正
2. **代替提案**: 重複時の連番ファイル名提案
3. **詳細エラー**: 具体的な修正方法の提示
4. **グレースフル・デグラデーション**: 部分的な機能提供

### エラーメッセージ例
```javascript
{
  success: false,
  error: "DUPLICATE_HEARTBEAT_ID",
  message: "ハートビートID '20250115143000' は既に使用されています",
  suggestion: "連番ファイル名 '20250115143000_01.md' の使用を検討してください",
  existingFile: "artifacts/current_theme/histories/20250115143000.md"
}
```

## テストケース

### 正常系テスト
1. 基本的な思考ログ作成
2. 補助操作ありの思考ログ作成
3. 成果物ありの思考ログ作成
4. 自動テーマ検出での作成

### 異常系テスト
1. 無効なハートビートID
2. 重複ハートビートID
3. 存在しないテーマ指定
4. 禁止ディレクトリへのアクセス
5. ディスク容量不足
6. 権限不足

### 境界値テスト
1. 最大長の活動内容
2. 大量の成果物リスト
3. 特殊文字を含むテーマ名

## 将来拡張

### 拡張可能性
1. **テンプレート機能**: 活動種別別のカスタムテンプレート
2. **自動分析**: 過去ログからの傾向分析・提案
3. **統計機能**: 活動種別の統計情報・可視化
4. **バックアップ**: 自動バックアップ・復元機能
5. **検索機能**: 思考ログの全文検索・フィルタリング
6. **エクスポート**: 他形式（PDF、HTML等）への変換

### 他ツールとの連携
1. **テーマ管理ツール**: テーマ移行時の自動連携
2. **成果物作成ツール**: 成果物作成と思考ログの自動関連付け
3. **Web検索ツール**: 検索制限状態の自動反映
4. **統計ツール**: 活動データの自動提供

### パフォーマンス最適化
1. **キャッシュ機能**: テーマ情報・設定のキャッシュ
2. **並列処理**: 複数ファイル操作の並列化
3. **遅延読み込み**: 大量ログファイルの効率的な処理

## 変更履歴

### v0.1.0-design (2025-01-15)
- 初版設計書作成
- 基本要件・仕様の定義
- アーキテクチャ設計の策定
- 実装計画の立案