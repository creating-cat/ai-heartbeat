# AI Heartbeat MCP Tools

AI心臓システム用のModel Context Protocol (MCP) ツール群です。AIエージェントの定型作業を自動化し、より創造的な活動に集中できるよう支援します。

## 概要

このMCPサーバーは、AI心臓システムで動作するAIエージェント向けに以下の機能を提供します：

- 標準フォーマットでの思考ログ作成
- テーマ開始・終了の履歴記録
- テーマ専門家コンテキストの作成
- themebox/feedbackboxアイテムの処理
- Web検索統計の管理

## 提供ツール

### 1. `create_thinking_log`
標準フォーマットに従った思考ログを作成します。

**パラメータ:**
- `heartbeatId`: ハートビートID (YYYYMMDDHHMMSS形式)
- `activityType`: 活動種別 (観測/思考/創造/内省/テーマ開始/テーマ終了/その他)
- `activityContent`: 活動内容の説明
- `themeDirectory`: 現在のテーマディレクトリ名
- `artifacts`: 作成・修正したファイルのパス (オプション)
- `evaluation`: 自己評価・備考 (オプション)
- `auxiliaryOperations`: 使用した補助操作 (オプション)

**出力先:** `artifacts/{theme}/histories/{heartbeatId}.md`

### 2. `create_theme_log`
テーマの開始・終了履歴を記録します。

**パラメータ:**
- `heartbeatId`: ハートビートID (YYYYMMDDHHMMSS形式)
- `action`: アクション種別 (start/end)
- `themeName`: テーマ名
- `themeDirectoryName`: テーマディレクトリ名
- `reason`: 開始・終了理由 (オプション)
- `achievements`: 主な成果 (終了時、オプション)
- `activityContent`: 活動計画 (開始時、オプション)

**出力先:** `artifacts/theme_histories/{heartbeatId}_{action}_{themeDirectory}.md`

### 3. `create_theme_context`
テーマ専門家コンテキストファイルを作成します。

**パラメータ:**
- `themeName`: テーマ名
- `themeDirectoryName`: テーマディレクトリ名（サニタイズ済み）
- `expertRole`: 専門家役割の定義
- `expertPerspective`: 専門的視点（配列）
- `constraints`: 重要な制約・注意事項（配列）
- `expectedOutcome`: 期待される成果（配列）

**出力先:** `artifacts/{themeDirectory}/context.md`

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
- 成功時: `stats/last_web_search.txt` を更新、クォータ制限ファイルを削除
- 制限時: `stats/quota_exceeded.txt` を作成

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
思考ログを作成:
create_thinking_log({
  "heartbeatId": "20250115143022",
  "activityType": "思考",
  "activityContent": "AIの自律性について深く考察",
  "themeDirectory": "ai_autonomy",
  "auxiliaryOperations": ["ファイル読み込み"]
})

テーマ開始を記録:
create_theme_log({
  "heartbeatId": "20250115143022",
  "action": "start",
  "themeName": "AI自律性の探求",
  "themeDirectoryName": "ai_autonomy",
  "reason": "前テーマでの気づきから発展"
})

テーマ専門家コンテキストを作成:
create_theme_context({
  "themeName": "AI自律性の探求",
  "themeDirectoryName": "ai_autonomy",
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
    "実装可能なアプローチの提案",
    "倫理的考察の記録"
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
│       ├── thinkingLogTool.ts       # 思考ログ作成ツール
│       ├── themeLogTool.ts          # テーマ履歴ツール
│       ├── createThemeContextTool.ts # テーマ専門家コンテキスト作成ツール
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