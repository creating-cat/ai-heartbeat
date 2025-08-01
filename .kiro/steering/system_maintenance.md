---
inclusion: always
---

# システム保守ガイド

## システム構造の理解

### テンプレートベースの作業環境分離

AI心臓システムは、システム管理領域とAI活動領域を分離したテンプレートベースの構造を採用しています：

- **システム管理領域**: Git管理下でシステムコードとライブラリを管理
- **AI活動環境テンプレート** (`ai-works-lib/`): AI用の設定とドキュメントのテンプレート
- **AI活動領域** (`ai-works/`): 実際のAI作業環境（テンプレートから自動生成）

この構造により、AIは自分の活動履歴と成果物に完全にアクセスでき、システム更新時もAIの作業環境を保護できます。

## ドキュメント構造の理解

### ユーザー向けドキュメント
- `README.md`: プロジェクト概要・クイックスタート
- `SYSTEM_OVERVIEW.md`: 詳細なシステム説明

### AI向けドキュメント
- `ai-works-lib/GEMINI.md`: AI動作の基本ルール（最重要）
- `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md`: システムの理念・概念の詳細
- `ai-works-lib/ai-docs/BASIC_OPERATIONS.md`: 基本操作の詳細手順
- `ai-works-lib/ai-docs/ACTIVITY_DETAILS.md`: 各活動種別の詳細ガイド
- `ai-works-lib/ai-docs/THEME_SYSTEM.md`: テーマ・サブテーマ管理
- `ai-works-lib/ai-docs/TOOL_USAGE.md`: MCPツール使用方法
- `ai-works-lib/ai-docs/ERROR_HANDLING.md`: エラー・例外処理
- `ai-works-lib/ai-docs/ADVANCED_FEATURES.md`: 高度な機能

### サンプル・テンプレート・開発ツール
- `theme_sample/`: テーマファイルのサンプル
- `mcp/ai-heartbeat-mcp/`: MCPツールのソースコード
- `ai-works-lib/`: AI活動環境テンプレート（GEMINI.md、ai-docs/、.gemini/設定等）

## 設定ファイル管理

### 主要設定ファイル
```bash
# heartbeat.conf - ハートビート設定
INTERVAL_SECONDS=60                    # ハートビート間隔
INACTIVITY_WARNING_THRESHOLD=300       # 無活動警告閾値（5分）
INACTIVITY_STOP_THRESHOLD=600          # 無活動停止閾値（10分）
INTROSPECTION_THRESHOLD=1800           # 内省不足閾値（30分）
MONITORED_DIRS=("artifacts")           # 監視対象ディレクトリ
MAX_LOG_DAYS=30                        # ログファイル最大保持日数
MAX_RECOVERY_ATTEMPTS=3                # 最大回復試行回数
MAX_RECOVERY_WAIT_CYCLES=5             # 最大回復待機サイクル数
```

### Gemini CLI設定
```json
// ai-works-lib/.gemini/settings.json - MCP設定（テンプレート）
// 実際の設定は ai-works/.gemini/settings.json にコピーされる
{
  "mcpServers": {
    "creative-ideation-mcp": {
      "command": "npx",
      "args": ["-y", "@creating-cat/creative-ideation-mcp"],
      "env": {
        "GEMINI_API_KEY": "${GEMINI_API_KEY}"
      },
      "disabled": false,
      "timeout": 300000,
      "trust": true
    },
    "gemini-image-mcp-server": {
      "command": "npx",
      "args": ["-y", "@creating-cat/gemini-image-mcp-server"],
      "env": {
        "GEMINI_API_KEY": "${GEMINI_API_KEY}"
      },
      "timeout": 300000,
      "trust": true
    },
    "mult-fetch-mcp-server": {
      "command": "npx",
      "args": ["@lmcc-dev/mult-fetch-mcp-server"],
      "env": {
        "MCP_LANG": "en"
      },
      "trust": true
    },
    "ai-heartbeat-mcp": {
      "command": "node",
      "args": ["../mcp/ai-heartbeat-mcp/dist/index.js"],
      "trust": true
    }
  }
}
```

## ログ・状態管理

### ログファイルの種類
- `logs/heartbeat_YYYYMMDDHHMMSS.log`: ハートビートログ（自動命名・クリーンアップ）
- `ai-works/stats/cooldown/`: ツールクールダウン状態管理
- `ai-works/stats/lock/`: ツールロック状態管理

### 自動クリーンアップ機能
```bash
# logging.shのクリーンアップ機能
cleanup_old_logs() {
    find "$LOG_DIR" -name "heartbeat_*.log" -type f -mtime +$MAX_LOG_DAYS -delete
}
```

## 異常検知システムの保守

### 検知機能の追加・修正
- `lib/health_check_core.sh`: 純粋な判定ロジック
- `lib/config.sh`: アドバイスメッセージの定数定義
- `heartbeat.sh`: 検知結果の処理とログ出力

### 新しい異常検知の追加手順
1. `health_check_core.sh`に検知関数を追加
2. `config.sh`にアドバイスメッセージを定義
3. `heartbeat.sh`の`check_agent_health()`に統合
4. 適切な戻り値コードを割り当て

## MCPツールの保守

### ビルド・デプロイ手順
```bash
cd mcp/ai-heartbeat-mcp
npm install          # 依存関係インストール
npm run build        # TypeScriptコンパイル
npm run dev          # 開発モード実行（テスト用）
```

### 新しいツールの追加
1. `src/tools/`に新しいツールファイルを作成
2. `src/index.ts`でツールを登録
3. Zodスキーマによる入力検証を実装
4. 適切なエラーハンドリングと警告メッセージを追加
5. `ai-works-lib/ai-docs/ERROR_HANDLING.md`にツール固有のエラー対応を記載

## バージョン管理・リリース

### 重要なファイルの変更管理
- **システムスクリプト**: 慎重なテストが必要
- **ai-works-lib/GEMINI.md**: AI動作に直接影響するため特に注意
- **ai-works-lib/ai-docs/**: AIの動作理解に影響
- **MCPツール**: ビルド・テストが必要

### .gitignoreの管理
```gitignore
ai-works/           # AI活動領域全体（除外）
ai-works.local/     # ローカル活動領域（除外）
ai-works.*.backup/  # バックアップ領域（除外）
logs/              # ログファイル（除外）
*.local            # ローカル設定ファイル（除外）
results/           # テスト結果（除外）
tmp_*              # 一時ファイル（除外）
```

## トラブルシューティング

### よくある問題と対処法

#### tmuxセッションの問題
```bash
# セッション確認
tmux list-sessions

# 強制終了
tmux kill-session -t agent
tmux kill-session -t heartbeat

# 再起動
./setup.sh "テーマ名"
```

#### MCPツールの問題
```bash
# ビルド確認
cd mcp/ai-heartbeat-mcp
npm run build

# 設定確認
cat .gemini/settings.json
```

#### ログ・状態ファイルの問題
```bash
# ログディレクトリ確認
ls -la logs/

# ツール制限状態の確認・クリア
ls -la ai-works/stats/cooldown/
ls -la ai-works/stats/lock/
rm -rf ai-works/stats/cooldown/*
rm -rf ai-works/stats/lock/*
```

## 性能監視・最適化

### 監視すべき指標
- ハートビート送信間隔の安定性
- 異常検知の発生頻度
- ログファイルサイズの増加率
- MCPツールの応答時間

### 最適化のポイント
- 不要なログ出力の削減
- 異常検知閾値の調整
- ファイルI/O操作の効率化
- メモリ使用量の監視

## feedbackbox機能の保守

### 通常フィードバック管理
- `XXX_title.md`: 処理対象フィードバック
- `processed.XXX_title.md`: 処理済みフィードバック
- `draft.XXX_title.md`: 編集中（AIは無視）

### 緊急フィードバック機能
- `interrupt.XXX_title.md`: 割り込みフィードバック（即座処理中断）
- `processed.interrupt.XXX_title.md`: 処理済み割り込みフィードバック
- heartbeat.shによる自動検知・即座中断処理

### feedbackbox監視機能
```bash
# heartbeat.shの監視機能
check_feedbackbox() {
    # 緊急フィードバック検知
    # 通常フィードバック検知
    # ハートビートメッセージへの通知追加
}
```

## 将来の拡張性

### アーキテクチャの拡張ポイント
- 新しい異常検知機能の追加
- MCPツールの機能拡張（テーマ分析・統計機能等）
- 複数AIエージェントの対応
- Web UI・可視化機能の追加
- feedbackbox機能の高度化（カテゴリ分類等）

### 互換性の維持
- 既存のファイル形式との互換性
- 設定ファイルの後方互換性
- AIドキュメントの一貫性
- MCPツールのAPIバージョン管理
- テーマ履歴フォーマットの後方互換性