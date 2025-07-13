# AI心臓システム MCP プロジェクト構造

## 概要

このドキュメントでは、AI心臓システム用MCP（Model Context Protocol）のプロジェクト構造と技術スタックについて詳細に説明します。

## 技術選択

### TypeScript SDK使用の決定
- **採用SDK**: [@modelcontextprotocol/typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk)
- **言語**: TypeScript (Node.js)

### TypeScript採用の理由
1. **型安全性**: コンパイル時のエラー検出、IDEでの強力な補完機能
2. **開発効率**: 公式SDKによる標準的な実装パターン
3. **保守性**: 型定義による自己文書化
4. **AI心臓システムとの親和性**: JavaScriptベースでの自然な統合

## ディレクトリ構造

```
mcp/
├── docs/                           # ドキュメント
│   ├── design/                     # 設計書
│   │   └── thinking-log-tool-design.md
│   ├── architecture/               # アーキテクチャドキュメント
│   │   └── project-structure.md   # このファイル
│   └── README.md                   # ドキュメント概要
├── ai-heartbeat-mcp/               # メインプロジェクト
│   ├── src/                        # ソースコード
│   │   ├── index.ts                # MCPサーバーのエントリーポイント
│   │   ├── tools/                  # 各ツールの実装
│   │   │   ├── thinking-log/       # 思考ログ作成ツール
│   │   │   │   ├── index.ts        # ツール定義・エクスポート
│   │   │   │   ├── validator.ts    # 入力パラメータのバリデーション
│   │   │   │   ├── generator.ts    # ログファイル生成ロジック
│   │   │   │   └── types.ts        # 思考ログ関連の型定義
│   │   │   ├── theme-manager/      # テーマ管理ツール（将来実装）
│   │   │   │   ├── index.ts
│   │   │   │   ├── detector.ts     # テーマ検出ロジック
│   │   │   │   ├── migrator.ts     # テーマ移行ロジック
│   │   │   │   └── types.ts
│   │   │   └── artifact-creator/   # 成果物作成ツール（将来実装）
│   │   │       ├── index.ts
│   │   │       ├── template.ts     # テンプレート管理
│   │   │       └── types.ts
│   │   ├── core/                   # 共通機能・基盤
│   │   │   ├── config.ts           # 設定管理（heartbeat.conf連携）
│   │   │   ├── file-system.ts      # ファイル操作の共通機能
│   │   │   ├── validation.ts       # 共通バリデーションロジック
│   │   │   └── types.ts            # 共通型定義
│   │   ├── utils/                  # ユーティリティ関数
│   │   │   ├── timestamp.ts        # 日時処理（ハートビートID等）
│   │   │   ├── path-helper.ts      # パス操作ヘルパー
│   │   │   └── error-handler.ts    # エラーハンドリング
│   │   └── constants/              # 定数定義
│   │       ├── directories.ts      # ディレクトリパス定数
│   │       ├── file-patterns.ts    # ファイル名パターン定数
│   │       └── activity-types.ts   # 活動種別定数
│   ├── tests/                      # テストファイル
│   │   ├── tools/                  # ツール別テスト
│   │   │   ├── thinking-log/
│   │   │   ├── theme-manager/
│   │   │   └── artifact-creator/
│   │   ├── core/                   # 共通機能テスト
│   │   └── utils/                  # ユーティリティテスト
│   ├── config/                     # 設定ファイル
│   │   ├── default.json            # デフォルト設定
│   │   └── development.json        # 開発環境設定
│   ├── package.json                # プロジェクト設定・依存関係
│   ├── tsconfig.json               # TypeScript設定
│   ├── jest.config.js              # テスト設定
│   ├── .eslintrc.js               # ESLint設定
│   └── README.md                   # プロジェクト固有のREADME
├── examples/                       # 使用例・サンプルコード
│   ├── basic-usage.js              # 基本的な使用例
│   ├── advanced-usage.js           # 高度な使用例
│   └── integration-test.js         # 統合テスト例
└── scripts/                       # 開発・ビルドスクリプト
    ├── build.sh                    # ビルドスクリプト
    ├── test.sh                     # テスト実行スクリプト
    └── dev.sh                      # 開発環境起動スクリプト
```

## 技術スタック

### 依存関係

#### 本番依存関係
```json
{
  "@modelcontextprotocol/sdk": "^0.4.0",  // MCP公式SDK
  "fs-extra": "^11.2.0",                  // 拡張ファイル操作
  "date-fns": "^3.0.0",                   // 日時処理
  "zod": "^3.22.0",                       // スキーマバリデーション
  "config": "^3.3.9"                      // 設定管理
}
```

#### 開発依存関係
```json
{
  "@types/node": "^20.0.0",               // Node.js型定義
  "@types/fs-extra": "^11.0.0",           // fs-extra型定義
  "@types/jest": "^29.5.0",               // Jest型定義
  "@typescript-eslint/eslint-plugin": "^6.0.0",  // TypeScript ESLint
  "@typescript-eslint/parser": "^6.0.0",  // TypeScript ESLintパーサー
  "eslint": "^8.50.0",                    // リンター
  "jest": "^29.7.0",                      // テストフレームワーク
  "ts-jest": "^29.1.0",                   // Jest TypeScript統合
  "tsx": "^4.0.0",                        // TypeScript実行環境
  "typescript": "^5.2.0"                  // TypeScriptコンパイラ
}
```

### NPMスクリプト
```json
{
  "build": "tsc",                         // TypeScriptコンパイル
  "dev": "tsx watch src/index.ts",        // 開発サーバー起動
  "test": "jest",                         // テスト実行
  "test:watch": "jest --watch",           // テスト監視モード
  "lint": "eslint src/**/*.ts",           // リント実行
  "lint:fix": "eslint src/**/*.ts --fix", // リント自動修正
  "type-check": "tsc --noEmit"            // 型チェックのみ
}
```

## TypeScript設定

### tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2022",                    // 出力ターゲット
    "module": "commonjs",                  // モジュールシステム
    "lib": ["ES2022"],                     // 使用ライブラリ
    "outDir": "./dist",                    // 出力ディレクトリ
    "rootDir": "./src",                    // ソースルートディレクトリ
    "strict": true,                        // 厳格モード
    "esModuleInterop": true,               // ES Module互換性
    "skipLibCheck": true,                  // ライブラリ型チェックスキップ
    "forceConsistentCasingInFileNames": true,  // ファイル名大文字小文字一貫性
    "declaration": true,                   // 型定義ファイル生成
    "declarationMap": true,                // 型定義マップ生成
    "sourceMap": true,                     // ソースマップ生成
    "removeComments": false,               // コメント保持
    "noImplicitAny": true,                 // 暗黙的any禁止
    "strictNullChecks": true,              // null/undefined厳格チェック
    "strictFunctionTypes": true,           // 関数型厳格チェック
    "noImplicitReturns": true,             // 暗黙的return禁止
    "noFallthroughCasesInSwitch": true,    // switch文fallthrough禁止
    "moduleResolution": "node",            // Node.jsモジュール解決
    "baseUrl": "./src",                    // ベースURL
    "paths": {                             // パスマッピング
      "@/*": ["*"],
      "@/tools/*": ["tools/*"],
      "@/core/*": ["core/*"],
      "@/utils/*": ["utils/*"],
      "@/constants/*": ["constants/*"]
    }
  },
  "include": ["src/**/*"],                 // コンパイル対象
  "exclude": ["node_modules", "dist", "tests"]  // 除外対象
}
```

## AI心臓システムとの統合

### 設定ファイル共有戦略
```typescript
// src/core/config.ts
import path from 'path';
import fs from 'fs-extra';

export class HeartbeatConfig {
  static async loadFromParent() {
    const configPath = path.resolve(__dirname, '../../../heartbeat.conf');
    // heartbeat.confの読み込み・パース
    // AI心臓システムの設定を直接参照
  }
}
```

### ディレクトリ構造の参照
```typescript
// src/constants/directories.ts
import path from 'path';

export const AI_HEARTBEAT_PATHS = {
  // AI心臓システムのディレクトリを直接参照
  ARTIFACTS: path.resolve(__dirname, '../../../artifacts'),
  AI_DOCS: path.resolve(__dirname, '../../../ai-docs'),
  THEMEBOX: path.resolve(__dirname, '../../../themebox'),
  STATS: path.resolve(__dirname, '../../../stats'),
  FEEDBACKBOX: path.resolve(__dirname, '../../../feedbackbox'),
  PROJECTS: path.resolve(__dirname, '../../../projects'),
} as const;
```

### ガイドライン参照
```typescript
// src/core/guidelines.ts
export class GuidelinesLoader {
  static async loadOperationDetails() {
    const guidelinesPath = path.resolve(__dirname, '../../../ai-docs/OPERATION_DETAILS.md');
    // 運用ガイドラインの動的読み込み
  }
  
  static async loadThemeHistoryGuide() {
    const guidePath = path.resolve(__dirname, '../../../ai-docs/THEME_HISTORY_GUIDE.md');
    // テーマ履歴ガイドの読み込み
  }
}
```

## 開発フェーズ

### Phase 1: 基盤構築
1. **プロジェクト構造作成**: 基本的なディレクトリ・ファイル構成
2. **TypeScript設定**: tsconfig.json, package.json等の設定
3. **MCPサーバー基盤**: 基本的なMCPサーバーの実装
4. **共通機能**: config, file-system等の基盤機能

### Phase 2: 思考ログツール実装
1. **型定義**: 思考ログ関連の型定義
2. **バリデーター**: 入力パラメータの検証
3. **ジェネレーター**: ログファイル生成
4. **統合**: MCPツールとしての統合

### Phase 3: テスト・品質向上
1. **ユニットテスト**: 各コンポーネントのテスト
2. **統合テスト**: 実際のAI心臓システムとの統合テスト
3. **リント・フォーマット**: コード品質の向上

### Phase 4: 拡張機能
1. **テーマ管理ツール**: テーマ移行・管理機能
2. **成果物作成ツール**: 成果物生成支援
3. **統計・分析機能**: 活動データの分析

## コーディング規約

### ファイル命名規則
- **TypeScriptファイル**: kebab-case (例: `thinking-log.ts`)
- **ディレクトリ**: kebab-case (例: `thinking-log/`)
- **型定義**: PascalCase (例: `ThinkingLogParams`)
- **関数・変数**: camelCase (例: `createThinkingLog`)
- **定数**: SCREAMING_SNAKE_CASE (例: `AI_HEARTBEAT_PATHS`)

### インポート規則
```typescript
// 外部ライブラリ
import fs from 'fs-extra';
import { z } from 'zod';

// 内部モジュール（パスマッピング使用）
import { HeartbeatConfig } from '@/core/config';
import { validateHeartbeatId } from '@/utils/timestamp';
import { AI_HEARTBEAT_PATHS } from '@/constants/directories';
```

### エラーハンドリング規則
```typescript
// カスタムエラークラスの使用
export class ThinkingLogError extends Error {
  constructor(
    message: string,
    public code: string,
    public suggestion?: string
  ) {
    super(message);
    this.name = 'ThinkingLogError';
  }
}
```

## 品質保証

### テスト戦略
1. **ユニットテスト**: 各関数・クラスの単体テスト
2. **統合テスト**: ツール間の連携テスト
3. **E2Eテスト**: 実際のAI心臓システムとの統合テスト

### コード品質
1. **ESLint**: TypeScript専用ルールセット
2. **Prettier**: コードフォーマット統一
3. **型チェック**: 厳格なTypeScript設定

### CI/CD（将来検討）
1. **自動テスト**: プルリクエスト時の自動テスト実行
2. **型チェック**: TypeScriptコンパイルチェック
3. **リント**: ESLintによる自動チェック

## 変更履歴

### v0.1.0-structure (2025-01-15)
- 初版プロジェクト構造設計
- TypeScript SDK採用決定
- ディレクトリ構造・技術スタック定義
- AI心臓システム統合戦略策定