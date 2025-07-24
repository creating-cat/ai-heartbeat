# AI作業環境の再構築

## 問題の背景

現在のAI心臓システムでは、AIの活動領域である`ai-works/`がgitignoreされているため、Gemini CLIのAIエージェントがファイルアクセスで制約を受けている。

### 具体的な問題
- ファイル検索やコンテキスト取得時に`ai-works/`配下が見えにくい
- AIが自分の過去の活動履歴や成果物にアクセスしにくい
- テーマ管理やフィードバック処理で不便

### 検討した解決案
1. **選択的gitignore**: 重要ファイルのみ追跡対象に
   - 問題: AI成果物がシステムリポジトリに混入するリスク
2. **作業ディレクトリ変更**: Gemini CLIの作業基準を`ai-works/`に変更
   - 問題: 相対パス管理の複雑化

## 採用する解決方針

**テンプレートベースの作業環境分離**

### 新しいディレクトリ構造
```
ai-heart-system/
├── システム管理領域（git管理）
│   ├── setup.sh, heartbeat.sh, stop.sh, restart.sh
│   ├── lib/ (ライブラリ群)
│   ├── mcp/ (MCPツール)
│   ├── heartbeat.conf
│   ├── .gemini/ (システム開発用設定)
│   │   └── settings.json
│   └── ai-works-lib/ ← 新設（空ディレクトリは除外）
│       ├── .gemini/ (AI活動用設定)
│       │   └── settings.json
│       ├── GEMINI.md
│       └── ai-docs/ (AI向けドキュメント)
└── ai-works/ ← AI活動領域（git除外、ai-works-libからコピー生成）
    ├── .gemini/ (ai-works-libからコピー)
    │   └── settings.json
    ├── GEMINI.md (ai-works-libからコピー)
    ├── ai-docs/ (ai-works-libからコピー)
    ├── artifacts/ (setup.shで作成)
    │   └── theme_histories/ (setup.shで作成)
    ├── themebox/ (setup.shで作成)
    ├── feedbackbox/ (setup.shで作成)
    ├── projects/ (setup.shで作成)
    └── stats/ (setup.shで作成)
        ├── cooldown/ (setup.shで作成)
        ├── lock/ (setup.shで作成)
        └── extended_processing/ (setup.shで作成)
```

### 設計の利点
1. **責任分離の明確化**: システム管理とAI活動の完全分離
2. **git管理問題の解決**: AI成果物の混入リスクなし
3. **相対パス問題の解決**: AIにとって自然なファイル構造
4. **環境の再現性**: いつでもクリーンな状態から開始可能
5. **カスタマイズ可能**: AI活動中にドキュメントや設定を独自修正可能
6. **設定の一元管理**: AI活動に必要な全設定がテンプレートに含まれる
7. **開発環境の分離**: システム開発用とAI活動用の設定が独立

## 詳細影響範囲調査結果

### 直接的な影響箇所

#### 1. システムスクリプト（修正必要）
**setup.sh**
- L106-110: `ai-works/` ディレクトリ作成処理
- L115-119: ディレクトリ作成完了メッセージ
- L189: `find ai-works/themebox` でのテーマファイル検索
- L212: `ai-works/themebox/` への初期テーマファイル作成
- L228: tmux起動時の作業ディレクトリ指定が必要

**heartbeat.sh**
- L19: `ai-works/stats/cooldown ai-works/stats/lock` ディレクトリ作成
- L108-109: `ai-works/feedbackbox` ディレクトリ作成・存在確認
- L114: `find ai-works/feedbackbox` でのフィードバックファイル検索
- L173: `ai-works/stats/lock/` でのロックファイルチェック
- L189: `ai-works/stats/cooldown/` でのクールダウンファイルチェック
- L453: `ai-works/artifacts/theme_histories` への参照
- L512: `ai-works/artifacts` での初回起動チェック

#### 2. ライブラリスクリプト（修正必要）
**lib/health_check_core.sh**
- L48, L99: `ai-works/stats/extended_processing/current.conf` への参照
- L141, L144: `find ai-works/artifacts` での活動ログ検索（macOS/Linux分岐）
- L218, L221: `find ai-works/artifacts/theme_histories` でのテーマログ検索
- L261: `find ai-works/artifacts/theme_histories` での同一タイムスタンプファイル検索
- L366, L369: `find ai-works/artifacts` での内省ログ検索

#### 3. MCPツール（修正不要 - 既に対応済み）
**mcp/ai-heartbeat-mcp/src/lib/pathConstants.ts**
- 既に `ai-works/` 基準でパス定数を定義済み
- 作業ディレクトリが `ai-works/` になれば相対パスとして正常動作

**mcp/ai-heartbeat-mcp/src/tools/createThemeExpertContextTool.ts**
- L131: `ai-works/artifacts/**` でのglob検索
- 作業ディレクトリ変更により相対パスとして動作

#### 4. ドキュメント（テンプレート移動対象）
**移動対象ファイル**
- `GEMINI.md` → `ai-works-lib/GEMINI.md`
- `ai-docs/` → `ai-works-lib/ai-docs/`

**参照更新が必要なドキュメント**
- `.kiro/steering/system_maintenance.md`: L78-79, L129, L169-172
- `ai-docs/TROUBLESHOOTING_GUIDE.md`: L62
- `ai-docs/THEME_MANAGEMENT_GUIDE.md`: L92, L111, L122

### 新たに発見された課題

#### 課題1: Gemini CLI設定の作業ディレクトリ指定
**問題**: Gemini CLIには明示的な作業ディレクトリ指定オプションが見当たらない
**影響**: tmuxセッション起動時の `-c` オプションで対応する必要がある
**対策**: `setup.sh` L228付近で `tmux new-session -d -s agent -c "ai-works"`

#### 課題2: MCPサーバーのパス参照
**問題**: `.gemini/settings.json` の `ai-heartbeat-mcp` が `./mcp/ai-heartbeat-mcp/dist/index.js` を参照
**影響**: 作業ディレクトリが `ai-works/` になると `../mcp/ai-heartbeat-mcp/dist/index.js` に変更が必要
**対策**: 設定ファイルのパス修正またはシンボリックリンク作成

#### 課題3: システムスクリプトからの相対パス参照
**問題**: `ai-works/` 内から `../heartbeat.sh`, `../lib/` への参照が必要になる可能性
**影響**: 現在は直接参照していないが、将来的な拡張で問題となる可能性
**対策**: パス参照の標準化とドキュメント化

#### 課題4: 既存環境の移行複雑性
**問題**: 既存の `ai-works/` に重要なデータが存在する場合の移行手順
**影響**: データ損失のリスク
**対策**: バックアップ機能と段階的移行手順の実装

## 実装タスク（詳細版）

### Phase 1: テンプレート環境の構築
- [x] `ai-works-lib/` ディレクトリの作成（空ディレクトリは除外）
- [x] `GEMINI.md` を `ai-works-lib/GEMINI.md` に移動
- [x] `ai-docs/` を `ai-works-lib/ai-docs/` に移動
- [x] `.gemini/settings.json` を `ai-works-lib/.gemini/settings.json` に移動・調整
  - [x] MCPサーバーパスを `../mcp/ai-heartbeat-mcp/dist/index.js` に修正
  - [x] AI活動用の設定として最適化
- [x] 必要な空ディレクトリ構造の設計（setup.shで動的作成）
  - [x] `artifacts/theme_histories/`
  - [x] `themebox/`
  - [x] `feedbackbox/`
  - [x] `projects/`
  - [x] `stats/cooldown/`
  - [x] `stats/lock/`
  - [x] `stats/extended_processing/`
- [x] `.gitignore` の更新
  - [x] `ai-works-lib/` を追跡対象として自然に管理
  - [x] `ai-works/` の除外は維持

### Phase 2: 初期化処理の実装
- [ ] `setup.sh` にライブラリコピー機能を追加
  - [ ] `initialize_ai_workspace()` 関数の実装（ai-works-libからコピー）
  - [ ] 既存 `ai-works/` の検出とバックアップ機能
  - [ ] ai-works-libからのファイルコピー処理
  - [ ] 必要な空ディレクトリの動的作成
    - [ ] `artifacts/theme_histories/`
    - [ ] `themebox/`
    - [ ] `feedbackbox/`
    - [ ] `projects/`
    - [ ] `stats/cooldown/`
    - [ ] `stats/lock/`
    - [ ] `stats/extended_processing/`
- [ ] 初期化オプションの実装
  - [ ] `--fresh`: 既存環境を削除して再初期化
  - [ ] `--update-docs`: ドキュメントのみ更新
  - [ ] `--backup`: 既存環境のバックアップ作成

### Phase 3: 作業ディレクトリ変更
- [x] `setup.sh` の修正
  - [x] L209: tmux起動時に `-c "ai-works"` オプション追加
  - [x] エージェント起動前の `cd ai-works` 削除（tmuxオプションで代替）※現在のコードには存在せず
- [x] Gemini CLI設定ファイル検索の動作確認
  - [x] `ai-works/.gemini/settings.json` が正しく読み込まれることを確認
  - [x] MCPサーバーの相対パス解決の確認（`../mcp/ai-heartbeat-mcp/dist/index.js`が正常にアクセス可能）

### Phase 4: システムスクリプトのパス修正（Phase 3完了後）
- [ ] `heartbeat.sh` の修正
  - [ ] 作業ディレクトリが`ai-works/`になった場合の`ai-works/`参照を`.`に変更
  - [ ] ディレクトリ作成処理の調整
- [ ] `lib/health_check_core.sh` の修正
  - [ ] 作業ディレクトリが`ai-works/`になった場合の`ai-works/`参照を`.`に変更
  - [ ] find コマンドのパス調整

### Phase 5: ドキュメント参照の確認・更新
- [ ] **ai-works-lib内ドキュメント** の動作確認
  - [ ] コピー後のパス参照が正しく動作することを確認
  - [ ] 必要に応じて相対パス調整
- [ ] **ルート版ドキュメント** の更新
  - [ ] `SYSTEM_OVERVIEW.md`: 新しい構造の説明に更新
  - [ ] 必要に応じて他のドキュメントの構造説明を更新
  - [ ] `.kiro/steering/project_overview.md`: パス参照修正不要（ルート基準のまま）
- [ ] テンプレート更新機能の実装
  - [ ] システム更新時の通知機能
  - [ ] 差分確認機能
  - [ ] 選択的更新機能

### Phase 6: テスト・検証
- [ ] 新規環境での動作確認
  - [ ] `setup.sh` での初期化テスト
  - [ ] Gemini CLI の作業ディレクトリ確認
  - [ ] MCPツールの動作確認
- [ ] 既存環境からの移行テスト
  - [ ] バックアップ機能のテスト
  - [ ] データ移行の確認
  - [ ] 設定ファイルの整合性確認
- [ ] 機能回帰テスト
  - [ ] ハートビート機能の動作確認
  - [ ] 異常検知機能の動作確認
  - [ ] テーマ管理機能の動作確認
  - [ ] フィードバック機能の動作確認

## 検証すべき重要事項

### 1. **Gemini CLIの設定ファイル検索動作**
```bash
# 作業ディレクトリの .gemini/settings.json が優先されるかの確認
cd ai-works
gemini --help  # 設定ファイルの読み込み順序を確認
```

### 2. **MCPサーバーの相対パス解決**
```bash
# ai-works/ から ../mcp/ へのパスが正しく解決されるかの確認
cd ai-works
node ../mcp/ai-heartbeat-mcp/dist/index.js  # パス解決テスト
```

### 3. **設定ファイルの分離動作**
- システム開発時: ルートの `.gemini/settings.json` 使用
- AI活動時: `ai-works/.gemini/settings.json` 使用
- 両設定が競合しないことの確認

## 移行時の注意点

### 既存環境への影響
- 現在の `.gemini/settings.json` をシステム開発用として保持
- AI活動用設定はテンプレートから新規作成
- 段階的移行により既存環境への影響を最小化

## 完了基準

1. **機能要件**
   - `setup.sh`実行時に`ai-works-lib/`から`ai-works/`が正しく生成される
   - Gemini CLIが`ai-works/.gemini/settings.json`を正しく読み込む
   - 全てのMCPツールが新しい環境で正常動作する
   - システムスクリプトが新しい構造で正常動作する

2. **品質要件**
   - 既存の機能に影響を与えない
   - git管理が適切に分離されている
   - ドキュメントと設定の整合性が保たれている
   - システム開発用とAI活動用の設定が適切に分離されている

3. **運用要件**
   - 初期化・更新手順が明確に文書化されている
   - トラブルシューティング手順が整備されている

## リスクと対策

### リスク1: 既存環境の互換性
- **対策**: 段階的移行とフォールバック機能の実装

### リスク2: MCPツールの動作不良
- **対策**: 事前の動作確認とパス修正

### リスク3: ドキュメント同期の複雑化
- **対策**: 自動化ツールの実装と明確な更新手順

## 注意点

- 既存の`ai-works/`がある環境での移行手順を慎重に設計する
- システム開発者とAI活動の両方の利便性を考慮する
- 将来的な拡張性を保持する設計にする

## 追加で発見された重要な課題

### 課題A: MCPサーバー設定の相対パス問題 ✅ 解決済み
**詳細**: `.gemini/settings.json` の `ai-heartbeat-mcp` が `./mcp/` を参照しているが、作業ディレクトリが `ai-works/` になると `../mcp/` への変更が必要

**採用した解決策**: `.gemini/settings.json` をテンプレートに含める
- **利点**: 設定の一元管理、環境の完全分離、カスタマイズの柔軟性
- **実装**: `ai-works-lib/.gemini/settings.json` として管理
- **パス**: `../mcp/ai-heartbeat-mcp/dist/index.js` に調整済み

### 課題B: システムスクリプトの大幅修正 ✅ 回避済み
**新しいアプローチ**: システムスクリプトは現状維持、Gemini CLIのみ作業ディレクトリ変更

**修正範囲の大幅削減**:
- `heartbeat.sh`: システム処理部分は修正不要、AIメッセージ内パス参照のみ修正（1箇所）
- `lib/health_check_core.sh`: 修正不要
- 各種find/statコマンド: 修正不要

**利点**: 既存システムの安定性維持、回帰バグリスクの大幅削減

### 課題C: ドキュメント内パス参照の大量修正
**詳細**: GEMINI.mdとai-docs配下のドキュメント内で多数のパス参照修正が必要

**修正箇所の詳細**:
- **GEMINI.md**: `ai-docs/` → `./ai-docs/` (14箇所), `heartbeat.sh` → `../heartbeat.sh` (1箇所), `./stop.sh` → `../stop.sh` (1箇所)
- **ai-docs配下**: 6ファイルで計20箇所の修正が必要
- **相対パス変更**: テンプレート内では相対パスに統一

**重要性**: AIが参照するドキュメント内のパスが正しくないと、システム動作に支障をきたす

### 課題D: 既存環境との互換性
**詳細**: 現在稼働中の環境から新しい構造への移行時のデータ保全

**考慮事項**:
- 進行中のテーマデータの保護
- 活動履歴の継続性
- 統計データの保持

## 修正工数の再見積もり（設定ファイル統合後）

### Phase 1: テンプレート環境構築 (3-4時間)
- ディレクトリ構造設計: 1時間
- ファイル移動とテンプレート作成: 2時間
- 設定ファイル調整（.gemini/settings.json）: 0.5時間
- .gitignore調整: 0.5時間

### Phase 2: 初期化処理実装 (4-5時間)
- setup.sh修正: 2時間
- バックアップ機能実装: 1.5時間
- オプション機能実装: 1時間
- エラーハンドリング: 0.5時間

### Phase 3: 作業ディレクトリ変更 (1.5-2時間) ← 削減
- tmux設定修正: 0.5時間
- Gemini CLI動作確認: 0.5時間
- システム開発用設定作成: 0.5時間

### Phase 4: AIメッセージ内パス修正 (0.5-1時間) ← 大幅削減
- heartbeat.sh内のAI向けメッセージのパス修正: 0.5時間
- 動作確認: 0.5時間

### Phase 5: ドキュメント内パス参照修正 (3-4時間)
- GEMINI.md内パス修正: 1時間
- ai-docs配下ドキュメント修正: 1.5時間
- システム管理ドキュメント修正: 0.5時間
- 更新管理機能: 1時間

### Phase 6: 総合テスト・検証 (3-4時間) ← 削減
- 新規環境テスト: 1時間
- 移行テスト: 1時間
- 機能回帰テスト: 1時間
- 問題修正: 0.5時間

**合計**: 15-19時間程度（ドキュメント内パス修正追加により約1時間増加）

## 実装優先度の提案

### 高優先度（必須）
- Phase 1: テンプレート環境構築
- Phase 2: 初期化処理実装
- Phase 4: AIメッセージ内パス修正（軽微）

### 中優先度（重要）
- Phase 3: 作業ディレクトリ変更
- Phase 6: 基本的なテスト・検証

### 低優先度（改善）
- Phase 5: 高度なドキュメント更新管理
- Phase 6: 詳細な回帰テスト