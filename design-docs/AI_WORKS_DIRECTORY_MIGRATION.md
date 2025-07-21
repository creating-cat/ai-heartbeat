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

## 各コンポーネントへの影響範囲詳細分析

### 1. **MCPツール群への影響**

#### 1.1 直接的なパス参照を含むツール

**activityLogTool.ts** (影響度: 高):
- `artifacts/{THEME_START_ID_テーマ名}/histories/{ハートビートID}.md` → `ai-works/artifacts/{THEME_START_ID_テーマ名}/histories/{ハートビートID}.md`
- `stats/extended_processing/current.conf` → `ai-works/stats/extended_processing/current.conf`
- **修正箇所**: パス定数、ファイル作成・参照処理

**itemProcessorTool.ts** (影響度: 高):
- `themebox/` → `ai-works/themebox/`
- `feedbackbox/` → `ai-works/feedbackbox/`
- **修正箇所**: directoryPath変数の設定

**themeLogTool.ts** (影響度: 高):
- `artifacts/theme_histories/` → `ai-works/artifacts/theme_histories/`
- **修正箇所**: THEME_HISTORIES_DIR定数

**listThemeArtifactsTool.ts** (影響度: 中):
- `artifacts/{THEME_START_ID_テーマ名}/` → `ai-works/artifacts/{THEME_START_ID_テーマ名}/`
- **修正箇所**: resolveThemePath関数の呼び出し

**reportToolUsageTool.ts** (影響度: 中):
- `stats/cooldown/` → `ai-works/stats/cooldown/`
- `stats/lock/` → `ai-works/stats/lock/`
- **修正箇所**: COOLDOWN_DIR, LOCK_DIR定数

**checkThemeStatusTool.ts** (影響度: 中):
- `artifacts/theme_histories/` → `ai-works/artifacts/theme_histories/`
- **修正箇所**: パス参照処理

**createThemeExpertContextTool.ts** (影響度: 中):
- `artifacts/{THEME_START_ID_テーマ名}/contexts/` → `ai-works/artifacts/{THEME_START_ID_テーマ名}/contexts/`
- **修正箇所**: resolveThemePath関数の呼び出し

**declareExtendedProcessingTool.ts** (影響度: 中):
- `stats/extended_processing/` → `ai-works/stats/extended_processing/`
- **修正箇所**: declarationFile変数

#### 1.2 ライブラリファイルへの影響

**themeUtils.ts** (影響度: 高):
- `resolveThemePath()` 関数でのパス解決ロジック
- **修正箇所**: artifacts基準パスの変更

### 2. **シェルスクリプトへの影響**

#### 2.1 heartbeat.sh (影響度: 高)
- `mkdir -p stats/cooldown stats/lock` → `mkdir -p ai-works/stats/cooldown ai-works/stats/lock`
- feedbackboxチェック処理のパス参照
- **修正箇所**: ディレクトリ作成、feedbackbox監視処理

#### 2.2 setup.sh (影響度: 中)
- 初期ディレクトリ作成処理
- **修正箇所**: mkdir処理でのパス指定

#### 2.3 lib/health_check_core.sh (影響度: 高)
- `stats/extended_processing/current.conf` → `ai-works/stats/extended_processing/current.conf`
- `artifacts/` パス参照 → `ai-works/artifacts/`
- **修正箇所**: _get_latest_activity_log_info, _get_latest_theme_log_info, check_extended_processing_deadline関数

### 3. **設定・ドキュメントファイルへの影響**

#### 3.1 GEMINI.md (影響度: 高)
- `artifacts/{THEME_START_ID_テーマ名}/` → `ai-works/artifacts/{THEME_START_ID_テーマ名}/`
- `projects/` → `ai-works/projects/`
- `feedbackbox/` → `ai-works/feedbackbox/`
- **修正箇所**: AI動作ルールでのパス指定

#### 3.2 ai-docs/ 配下のドキュメント (影響度: 中)
- 各種ガイドでのパス参照
- **修正箇所**: 操作例、パス説明

### 4. **影響度別優先順位**

#### 高影響度（移行必須・即座に修正）
1. **MCPツール**: activityLogTool, itemProcessorTool, themeLogTool, themeUtils
2. **シェルスクリプト**: heartbeat.sh, health_check_core.sh
3. **設定ファイル**: GEMINI.md

#### 中影響度（移行推奨・順次修正）
1. **MCPツール**: その他のツール群
2. **初期化**: setup.sh
3. **ドキュメント**: ai-docs/ 配下

#### 低影響度（移行後対応可）
1. **ユーザー向けドキュメント**: README.md, SYSTEM_OVERVIEW.md等

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
- MCPサーバー再起動による設定反映

### 3. **設定不整合リスク**
**対策:**
- 設定ファイルの一括更新
- パス参照の網羅的確認
- ドキュメントとの整合性確認
- 異常検知システムの動作確認

### 4. **MCPツール特有のリスク**
**対策:**
- TypeScriptコンパイルエラーの事前確認
- パス定数の一元管理による整合性確保
- ツール個別の動作テスト実施

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

## Phase 6: ファイルアクセス制限記述の簡素化

### 6.1 現在の問題点
ai-worksディレクトリ統合により、ファイルアクセス制限の記述を大幅にシンプル化できる機会が生まれた。

**現在の複雑な記述:**
- `artifacts/`, `projects/`, `stats/`, `themebox/`, `feedbackbox/`を個別に詳細説明
- 同じような制限事項を複数箇所で重複説明
- 許可/禁止の境界が分かりにくい冗長な構造

### 6.2 簡素化のメリット
1. **明確な境界**: `ai-works/` = 許可領域、それ以外 = 禁止領域
2. **理解しやすさ**: AIにとって判断が簡単
3. **保守性向上**: 新しいディレクトリ追加時の説明更新が不要
4. **AIファースト設計**: 曖昧さを排除した明確なルール

### 6.3 修正対象ファイル

#### 6.3.1 GEMINI.md (最重要)
**現在の記述 (3.3 ファイル出力)**:
- 複雑な個別ディレクトリ説明
- 冗長な制限事項の列挙

**簡素化案**:
```markdown
### 3.3 ファイル出力(任意)

**許可領域**: `ai-works/` 配下のみファイル操作が許可されています

* **テーマ成果物**: `ai-works/artifacts/{THEME_START_ID_テーマ名}/` 配下
  * ファイル名: `{ハートビートID}_filename.md` 形式
  * 例外: `contexts/`, `histories/` 配下は専用ルール適用
* **プロジェクト**: `ai-works/projects/` 配下（全ての操作が許可）
* **システム状態**: `ai-works/stats/` 配下（MCPツール経由推奨）
* **テーマ・フィードバック**: `ai-works/themebox/`, `ai-works/feedbackbox/` 配下（リネームのみ）

**重要**: `ai-works/` 以外のファイル操作は固く禁止

**詳細**: `ai-docs/OPERATION_DETAILS.md` の「3. ファイル操作制限」を参照
```

#### 6.3.2 ai-docs/OPERATION_DETAILS.md
**現在の記述 (3. ファイル操作制限の詳細)**:
- 3.1-3.5の複雑な階層構造
- 個別ディレクトリの詳細説明

**簡素化案**:
```markdown
## 3. ファイル操作制限の詳細

### 3.1 基本原則
**許可領域**: `ai-works/` ディレクトリ配下のみ
**禁止領域**: `ai-works/` 以外の全てのファイル・ディレクトリ

### 3.2 ai-works/ 内の操作ルール
| ディレクトリ | 操作 | 用途 | 備考 |
|-------------|------|------|------|
| `artifacts/{テーマ}/` | 作成・修正 | テーマ成果物・活動ログ | ファイル名規則あり |
| `artifacts/theme_histories/` | 作成 | テーマ履歴 | MCPツール推奨 |
| `projects/` | 全操作 | 開発プロジェクト | 独立git管理 |
| `stats/` | 作成 | システム状態 | MCPツール経由推奨 |
| `themebox/`, `feedbackbox/` | リネームのみ | 処理済みマーク | processed.プレフィックス |

### 3.3 ファイル作成ルール
* **ファイル名**: 英語で作成
* **ファイル内容**: 日本語で記述（ユーザーリーダブル）
* **作成範囲**: 一回のハートビートで適切な範囲

### 3.4 厳格な制限事項
**禁止対象**: `ai-works/` 以外の全てのファイル・ディレクトリ
- システムスクリプト（`*.sh`, `lib/`）
- 設定ファイル（`.gitignore`, `heartbeat.conf`等）
- ドキュメント（`ai-docs/`, `README.md`等）
- その他プロジェクトルート直下のファイル

**違反の影響**: システムの安定性を損なう重大な問題となるため、絶対に遵守すること
```

### 6.4 その他の修正対象
- **ai-docs/THEME_MANAGEMENT_GUIDE.md**: ファイル操作説明の簡素化
- **ai-docs/GUIDELINES.md**: 制限事項の統一
- **README.md**: ユーザー向け説明の更新

### 6.5 実装方針
1. **段階的修正**: GEMINI.md → OPERATION_DETAILS.md → その他の順
2. **一貫性確保**: 全ドキュメントで同じ表現・構造を使用
3. **AIファースト**: 明確で判断しやすい記述を優先
4. **後方互換性**: 既存の機能に影響しない範囲で簡素化

### 6.6 期待される効果
1. **理解度向上**: AIがファイル操作制限を正確に理解
2. **判断速度向上**: 許可/禁止の判断が瞬時に可能
3. **保守性向上**: 新機能追加時の文書更新が簡単
4. **エラー削減**: 制限違反による問題の発生率低下

## 次のステップ

1. **移行スクリプト作成** ✅ 完了
2. **MCPツール修正実装** ✅ 完了
3. **テスト環境での検証** ✅ 完了
4. **本環境での移行実行** ✅ 完了
5. **ファイルアクセス制限記述の簡素化** ← 次の実装対象

この設計に基づいて、安全で確実な移行を実現する。