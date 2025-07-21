# AI Heartbeat MCP Tools

AI心臓システム用のModel Context Protocol (MCP) ツール群です。AIエージェントの定型作業を自動化し、より創造的な活動に集中できるよう支援します。

## 概要

このMCPサーバーは、AI心臓システムで動作するAIエージェント向けに以下の機能を提供します：

- 標準フォーマットでの活動ログ作成
- テーマ開始・終了の履歴記録
- テーマ専門家コンテキストの作成
- themebox/feedbackboxアイテムの処理
- Web検索統計の管理

## 提供ツール

### 1. `create_activity_log`
標準フォーマットに従った活動ログを作成します。

**パラメータ:**
- `heartbeatId`: ハートビートID (YYYYMMDDHHMMSS形式)
- `activityType`: 活動種別 (観測/思考/創造/内省/テーマ開始/テーマ終了/その他)
- `activityContent`: 活動内容の説明
- `themeDirectory`: 現在のテーマディレクトリ名
- `artifacts`: 作成・修正したファイルのパス (オプション)
- `evaluation`: 自己評価・備考 (オプション)
- `auxiliaryOperations`: 使用した補助操作 (オプション)

**出力先:** `ai-works/artifacts/{theme}/histories/{heartbeatId}.md`

### 2. `create_theme_log`
テーマの開始・終了履歴を記録します。

**パラメータ:**
- `action`: アクション種別 (start/end)
- `themeStartId`: テーマ開始時のハートビートID (YYYYMMDDHHMMSS形式)
- `themeEndId`: テーマ終了時のハートビートID (終了時のみ必須)
- `themeName`: テーマ名
- `themeDirectoryPart`: テーマディレクトリ名の一部（例: "ai_research" → ディレクトリ "20250115143000_ai_research"）
- `reason`: 開始・終了理由 (オプション)
- `achievements`: 主な成果 (終了時、オプション)
- `activityContent`: 活動計画 (開始時、オプション)

**出力先:** 
- テーマディレクトリ: `ai-works/artifacts/{themeStartId}_{themeDirectoryPart}/`
- 履歴ファイル: `ai-works/artifacts/theme_histories/{themeStartId|themeEndId}_{action}_{themeDirectoryPart}.md`

### 3. `create_theme_expert_context`
テーマ専門家コンテキストファイルを作成します。

**パラメータ:**
- `themeName`: テーマ名
- `themeStartId`: テーマのTHEME_START_ID (YYYYMMDDHHMMSS形式)
- `themeDirectoryPart`: テーマディレクトリ名の一部（例: "ai_research" → ディレクトリ "20250115143000_ai_research"）
- `expertRole`: 専門家役割の定義
- `expertPerspective`: 専門的視点（配列）
- `constraints`: 重要な制約・注意事項（配列）
- `expectedOutcome`: 期待される成果（配列）

**出力先:** `ai-works/artifacts/{themeStartId}_{themeDirectoryPart}/context.md`

### 4. `check_and_process_item`
themebox または feedbackbox の最初のアイテムを処理します。

**パラメータ:**
- `type`: 処理対象 (themebox/feedbackbox)

**動作:**
- `draft.` や `processed.` で始まらない `.md` ファイルを検索
- 最初のファイルを `processed.` プレフィックス付きにリネーム
- ファイル内容を返却

### 5. `update_web_search_stats`
Web検索の実行結果に基づいて統計ファイルを更新します。

**パラメータ:**
- `status`: 検索結果 (success/quota_exceeded)

**動作:**
- 成功時: クールダウンファイルを作成
- 制限時: ロックファイルを作成してツール使用を制限

## セットアップ

### 前提条件
- Node.js 18.0.0 以上
- npm または yarn

### インストール
```bash
cd mcp/ai-heartbeat-mcp
npm install
```

### ビルド
```bash
npm run build
```

### 開発モード
```bash
npm run dev
```

## 使用方法

### Gemini CLI での設定
`.gemini/settings.json` に以下を追加：

```json
{
  "mcpServers": {
    "ai-heartbeat-mcp": {
      "command": "node",
      "args": ["mcp/ai-heartbeat-mcp/dist/index.js"]
    }
  }
}
```

### 使用例

```markdown
活動ログを作成:
create_activity_log({
  "heartbeatId": "20250115143022",
  "activityType": "思考",
  "activityContent": "AIの自律性について深く考察",
  "themeDirectory": "ai_autonomy",
  "auxiliaryOperations": ["ファイル読み込み"]
})

テーマ開始を記録:
create_theme_log({
  "action": "start",
  "themeStartId": "20250115143022",
  "themeName": "AI自律性の探求",
  "themeDirectoryPart": "ai_autonomy",
  "reason": "前テーマでの気づきから発展"
})

テーマ終了を記録:
create_theme_log({
  "action": "end",
  "themeStartId": "20250115143022",
  "themeEndId": "20250115180000",
  "themeName": "AI自律性の探求",
  "themeDirectoryPart": "ai_autonomy",
  "reason": "探求が一段落",
  "achievements": [
    "自律性の理論的フレームワークの構築",
    "実装可能なアーキテクチャの設計",
    "倫理的ガイドラインの策定"
  ]
})

テーマ専門家コンテキストを作成:
create_theme_expert_context({
  "themeName": "AI自律性の探求",
  "themeStartId": "20250115143022",
  "themeDirectoryPart": "ai_autonomy",
  "expertRole": "AI研究者として、自律性の理論と実践の両面から探求を進めます。",
  "expertPerspective": [
    "機械学習と認知科学の融合的視点",
    "自律システムの設計原理と実装",
    "倫理的AI開発の重要性"
  ],
  "constraints": [
    "一回のハートビートでは特定の側面に集中",
    "理論と実践のバランスを保つ",
    "システムの継続性を最優先"
  ],
  "expectedOutcome": [
    "AI自律性の深い理解",
    "実装可能な自律システムの設計",
    "倫理的配慮を含む包括的な視点"
  ]
})
```

## ファイル構造

```
mcp/ai-heartbeat-mcp/
├── src/
│   ├── index.ts              # MCPサーバーエントリーポイント
│   ├── lib/
│   │   └── timeUtils.ts      # 時刻関連ユーティリティ
│   └── tools/
│       ├── activityLogTool.ts       # 活動ログ作成ツール
│       ├── themeLogTool.ts          # テーマ履歴ツール
│       ├── createThemeExpertContextTool.ts # テーマ専門家コンテキスト作成ツール
│       ├── itemProcessorTool.ts     # アイテム処理ツール
│       └── webSearchStatsTool.ts    # Web検索統計ツール
├── dist/                     # ビルド出力
├── package.json
├── tsconfig.json
└── README.md
```

## 技術スタック

- **言語**: TypeScript
- **ランタイム**: Node.js
- **MCPフレームワーク**: @modelcontextprotocol/sdk
- **バリデーション**: zod
- **ファイル操作**: fs-extra

## 開発

### コード品質
- TypeScriptによる型安全性
- Zodによる入力バリデーション
- エラーハンドリングの統一

### セキュリティ
- パストラバーサル攻撃の防止
- ファイル名のサニタイゼーション
- 入力値の厳密な検証

## ライセンス

MIT License - AI心臓システム本体と同じライセンス条件