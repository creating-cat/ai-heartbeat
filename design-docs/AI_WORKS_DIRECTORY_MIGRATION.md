# AI Works ディレクトリ統合移行設計

## 概要

AI活動領域のディレクトリを`ai-works/`配下に統合し、システム管理領域との明確な分離を実現する移行設計。

## 移行の目的

### 1. **責任分離の明確化**
- AI活動領域とシステム管理領域の視覚的分離
- 権限管理の簡素化
- バックアップ・移行対象の明確化

### 2. **保守性の向上**
- AI許可領域の一元管理
- 将来の拡張性確保
- システム構造の理解しやすさ向上

## 現在の構造と移行後の構造

### 現在の構造
```
プロジェクトルート/
├── artifacts/          # AI生成物・活動ログ
├── projects/           # 開発プロジェクト作業領域
├── themebox/           # テーマ事前準備
├── feedbackbox/        # ユーザーフィードバック
├── stats/              # システム状態管理
├── results/            # テスト結果
├── lib/                # システムライブラリ
├── logs/               # システムログ
├── mcp/                # MCPツール
└── ai-docs/            # AIドキュメント
```

### 移行後の構造
```
プロジェクトルート/
├── ai-works/           # AI活動領域統合
│   ├── artifacts/      # AI生成物・活動ログ
│   ├── projects/       # 開発プロジェクト作業領域
│   ├── themebox/       # テーマ事前準備
│   ├── feedbackbox/    # ユーザーフィードバック
│   └── stats/          # システム状態管理
├── results/            # テスト結果
├── lib/                # システムライブラリ
├── logs/               # システムログ
├── mcp/                # MCPツール
└── ai-docs/            # AIドキュメント
```

## 影響範囲分析

### 1. **Shell Scripts**
- `setup.sh`: ディレクトリ作成処理
- `heartbeat.sh`: feedbackbox監視、health check
- `lib/health_check_core.sh`: artifacts/theme_histories参照

### 2. **MCPツール (TypeScript)**
- `src/lib/themeUtils.ts`: パス解決の核心ロジック
- `src/tools/activityLogTool.ts`: artifacts参照
- `src/tools/themeLogTool.ts`: artifacts/theme_histories参照
- `src/tools/createThemeExpertContextTool.ts`: artifacts参照
- `src/tools/listThemeArtifactsTool.ts`: artifacts参照
- `src/tools/reportToolUsageTool.ts`: stats参照
- `src/tools/declareExtendedProcessingTool.ts`: stats参照
- `src/tools/checkThemeStatusTool.ts`: artifacts参照

### 3. **設定ファイル**
- `.gitignore`: 除外ディレクトリ設定

### 4. **ドキュメント**
- `ai-docs/`: 全ファイルでパス参照
- `GEMINI.md`: AI向け仕様書
- `README.md`, `SYSTEM_OVERVIEW.md`: ユーザー向け説明

## 移行手順

### Phase 1: 準備・バックアップ
1. **現在の状態確認**
   - 既存ディレクトリの存在確認
   - データ量・構造の把握

2. **バックアップ作成**
   - 移行対象ディレクトリの完全バックアップ
   - 設定ファイルのバックアップ

3. **新構造作成**
   - `ai-works/`ディレクトリ作成
   - サブディレクトリ構造作成

### Phase 2: データ移行
1. **ディレクトリ移動**
   ```bash
   mv artifacts/ ai-works/
   mv projects/ ai-works/
   mv themebox/ ai-works/
   mv feedbackbox/ ai-works/
   mv stats/ ai-works/
   ```

### Phase 3: コード修正

#### 3.1 MCPツール修正 (最重要)
**修正対象ファイル:**
- `src/lib/themeUtils.ts`
- `src/tools/*.ts` (全ツール)

**修正内容:**
- パス定数の定義と一元管理
- `resolveThemePath`関数の修正
- 全ツールでのパス参照更新

#### 3.2 Shell Script修正
**修正対象ファイル:**
- `setup.sh`
- `heartbeat.sh` 
- `lib/health_check_core.sh`

**修正内容:**
- ディレクトリ作成パスの更新
- ファイル参照パスの更新

#### 3.3 設定ファイル修正
**修正対象ファイル:**
- `.gitignore`

**修正内容:**
- 除外パターンの更新

### Phase 4: ドキュメント更新

#### 4.1 AI向けドキュメント
**修正対象:**
- `ai-docs/` 全ファイル
- `GEMINI.md`

**修正内容:**
- パス参照の一括更新
- 例示コードの修正

#### 4.2 ユーザー向けドキュメント
**修正対象:**
- `README.md`
- `SYSTEM_OVERVIEW.md`
- その他説明ファイル

### Phase 5: テスト・検証
1. **MCPツールビルド確認**
2. **基本機能テスト**
3. **統合テスト**

## 実装詳細

### MCPツール修正戦略

#### パス定数の一元管理
```typescript
// src/lib/pathConstants.ts (新規作成)
export const AI_WORKS_DIR = 'ai-works';
export const ARTIFACTS_DIR = `${AI_WORKS_DIR}/artifacts`;
export const STATS_DIR = `${AI_WORKS_DIR}/stats`;
export const THEMEBOX_DIR = `${AI_WORKS_DIR}/themebox`;
export const FEEDBACKBOX_DIR = `${AI_WORKS_DIR}/feedbackbox`;
export const PROJECTS_DIR = `${AI_WORKS_DIR}/projects`;

```

#### themeUtils.ts修正
```typescript
import { ARTIFACTS_DIR } from './pathConstants';

export function resolveThemePath(/* ... */) {
  // 既存ロジックのartifacts参照をARTIFACTS_DIRに変更
  return path.join(ARTIFACTS_DIR, /* ... */);
}
```

### Shell Script修正戦略

#### setup.sh修正
```bash
# ディレクトリ作成部分
mkdir -p ai-works/artifacts
mkdir -p ai-works/themebox
mkdir -p ai-works/feedbackbox
mkdir -p ai-works/projects
mkdir -p ai-works/results
mkdir -p ai-works/stats
```

#### heartbeat.sh修正
```bash
# feedbackbox監視部分
check_feedbackbox() {
    if [ ! -d "ai-works/feedbackbox" ]; then
        mkdir -p ai-works/feedbackbox
        return 0
    fi
    
    local feedback_files=$(find ai-works/feedbackbox -name "*.md" ...)
    # ...
}
```

## リスク分析と対策

### 1. **データ損失リスク**
**対策:**
- 完全バックアップの実施
- 段階的な移行確認
- ロールバック手順の準備

### 2. **機能停止リスク**
**対策:**
- MCPツールの事前ビルド確認
- 基本機能の動作テスト
- 統合テストの実施

### 3. **設定不整合リスク**
**対策:**
- 設定ファイルの一括更新
- パス参照の網羅的確認
- ドキュメントとの整合性確認

## 移行後の利点

### 1. **運用面**
- AI活動領域の明確な識別
- バックアップ対象の簡素化
- 権限管理の簡素化

### 2. **開発面**
- システム構造の理解しやすさ
- 新機能追加時の配置判断の明確化
- 保守作業の効率化

### 3. **将来性**
- 複数AI対応への拡張性
- 環境分離の容易さ
- 移行・複製の簡素化

## 実装スケジュール

### 推奨実装順序
1. **MCPツール修正** (最重要・最複雑)
2. **Shell Script修正**
3. **データ移行実行**
4. **設定ファイル修正**
5. **ドキュメント更新**
6. **テスト・検証**

### 所要時間見積もり
- **準備・設計**: 完了
- **コード修正**: 2-3時間
- **データ移行**: 30分
- **ドキュメント更新**: 1-2時間
- **テスト・検証**: 1時間
- **合計**: 4-6時間

## 注意事項

### 1. **一括移行の必要性**
- 複雑な依存関係のため段階的移行は困難
- 一度の移行で全体整合性を確保

### 2. **後方互換性**
- 既存データとの互換性は考慮しない
- 新構造での完全な再構築

### 3. **テスト重要性**
- MCPツールの動作確認が最重要
- AI活動の基本フローの確認必須

## 次のステップ

1. **移行スクリプト作成**
2. **MCPツール修正実装**
3. **テスト環境での検証**
4. **本環境での移行実行**

この設計に基づいて、安全で確実な移行を実現する。