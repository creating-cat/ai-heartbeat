---
inclusion: always
---

# 開発実践ガイド

## コードベース構造の理解

### Shell Script開発
- **メインスクリプト**: `setup.sh`, `heartbeat.sh`, `stop.sh`, `restart.sh`
- **ライブラリ分離**: 機能別に`lib/`ディレクトリで分離
- **設定外部化**: `heartbeat.conf`で設定値を管理
- **エラーハンドリング**: `set -e`による厳格なエラー処理

### ライブラリ設計パターン
```bash
# 各ライブラリの責務分離
source "lib/logging.sh"      # ログ機能
source "lib/config.sh"       # 設定管理
source "lib/utils.sh"        # ユーティリティ
source "lib/agent_io.sh"     # エージェント操作
source "lib/health_check_core.sh"  # 異常検知
```

### 設定管理
- **集中管理**: `heartbeat.conf`で閾値・間隔を定義
- **環境変数**: `DEBUG_MODE`等の実行時制御
- **OS対応**: macOS/Linux両対応の実装

## 異常検知システムの実装

### 検知機能の階層化
```bash
# health_check_core.shの戻り値体系
# 0: 正常
# 10-11: 活動ログ頻度異常（警告・エラー）
# 13: 活動ログパターン異常
# 14: 活動ログループ異常
# 16: テーマログパターン異常
# 17-18: 内省活動異常（警告・エラー）
# 19-20: タイムスタンプ異常（警告・エラー）
```

### 状態管理パターン
```bash
# heartbeat.shの状態管理
HEARTBEAT_STATE="normal"  # normal / recovery_waiting
RECOVERY_ATTEMPT_COUNT=0
RECOVERY_WAIT_CYCLES=0
```

## tmuxセッション管理

### セッション構成
```bash
# setup.shでの2セッション作成
tmux new-session -d -s agent      # AIエージェント
tmux new-session -d -s heartbeat  # ハートビート送信
```

### エージェント操作パターン
```bash
# agent_io.shの操作関数
send_message_to_agent()     # メッセージ送信
interrupt_agent()           # 処理中断（Escape×2）
compress_agent_context()    # コンテキスト圧縮
save_agent_chat_history()  # チャット履歴保存
```

## ログ管理システム

### ログレベル設計
```bash
log_error()     # エラー（常に出力・記録）
log_warning()   # 警告（常に出力・記録）
log_notice()    # 通知（常に出力・記録）
log_info()      # 情報（常に出力、DEBUG時のみ記録）
log_heartbeat() # ハートビート（専用フォーマット）
```

### ファイル管理
- **自動命名**: `heartbeat_YYYYMMDDHHMMSS.log`
- **自動クリーンアップ**: 30日以上古いログを削除
- **色付き出力**: 標準出力での視認性向上

## MCPツール開発

### TypeScript構成
```typescript
// src/index.ts - エントリーポイント
// src/lib/ - ユーティリティライブラリ
// - timeUtils.ts
// src/tools/ - 各ツールの実装
// - activityLogTool.ts (活動ログ作成・参照)
// - themeLogTool.ts (テーマ履歴管理)
// - itemProcessorTool.ts (themebox/feedbackbox処理)
// - webSearchStatsTool.ts (Web検索制限管理)
// - createThemeExpertContextTool.ts (専門家コンテキスト作成)
// - reportToolUsageTool.ts (ツール使用報告)
// - themeStatusTool.ts (テーマ状態分析)
// - themeArtifactsTool.ts (成果物一覧取得)
```

### ツール設計パターン
- **Zod**によるスキーマ検証
- **MCP SDK**による標準的な実装
- **エラーハンドリング**と**警告メッセージ**

## ファイル操作の安全性

### ファイル操作の安全性

**許可領域**: `ai-works/` ディレクトリ配下のみ
**禁止領域**: `ai-works/` 以外の全てのファイル・ディレクトリ

**主な禁止対象**:
- システムスクリプト（`*.sh`・`lib/`配下）
- 設定ファイル（`heartbeat.conf`・`ai-works-lib/.gemini/settings.json`）
- AIドキュメント（`ai-works-lib/ai-docs/`・`ai-works-lib/GEMINI.md`）
- システムファイル（`.gitignore`, `LICENSE`, `README.md`等）

## OS互換性の実装

### macOS/Linux対応パターン
```bash
# utils.shのOS判定
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# ファイル時刻取得の分岐
if is_macos; then
    stat -f %m "$file"  # macOS
else
    stat -c %Y "$file"  # Linux
fi
```

## エラー処理のベストプラクティス

### 段階的回復処理
1. **異常検知**: 複数の検知機能による早期発見
2. **処理中断**: Escapeキーによる安全な中断
3. **コンテキスト圧縮**: メモリ使用量の最適化
4. **チャット保存**: 履歴の保全
5. **回復待機**: 5サイクル（5分）の回復期間
6. **状態確認**: 回復成功の検証

### 連続エラー対応
- **最大試行回数**: 3回まで
- **試行間隔**: 5サイクル待機
- **最終手段**: システム停止

## 開発時の注意点

### スクリプト修正時
- **ライブラリ分離**: 機能追加は適切なライブラリに
- **設定外部化**: ハードコード値は`heartbeat.conf`に
- **エラーハンドリング**: 想定外の状況への対応

### 開発サーバー実行時

#### 基本方法: timeout実行（推奨）
```bash
# 基本的な使用方法（30秒間実行）
timeout 30s npm run dev

# 出力も保存したい場合（オプション）
timeout 30s npm run dev 2>&1 | tee artifacts/current_theme/server_output.log
```

**利点**:
- **確実な終了**: timeoutにより30秒で確実に終了
- **直接出力**: サーバーの出力が直接表示され、リアルタイムで確認可能
- **無活動回避**: 長時間プロセスによる異常検知を防ぐ
- **継続監視**: 次のハートビートで再実行・監視が可能
- **シンプル**: 複雑なファイル操作が不要

#### 並行作業が必要な場合: バックグラウンド実行
```bash
# サーバーをバックグラウンドで起動（プロセスIDを記録）
npm run dev &
SERVER_PID=$!
echo $SERVER_PID > /tmp/dev_server_$$.pid

# 並行作業の例
curl http://localhost:3000/api/test
cat logs/server.log
# その他の確認作業...

# 作業完了後、確実にサーバーを終了
kill $SERVER_PID 2>/dev/null || true
rm -f /tmp/dev_server_$$.pid
```

**バックグラウンド実行時の注意点**:
- **プロセス管理**: 必ずプロセスIDを記録し、作業完了後に終了する
- **時間制限**: 長時間の並行作業は避け、適度な間隔でハートビートを受信できるようにする
- **リソース管理**: プロセスの残存を防ぐため、確実な終了処理を実行する
- **用途限定**: 並行して確認作業が必要な場合のみ使用し、基本はtimeout実行を優先する

**使い分けの判断基準**:
- **シンプルな動作確認**: timeout実行
- **APIテスト + ログ確認**: バックグラウンド実行
- **設定変更 + 動作確認**: バックグラウンド実行
- **複数エンドポイントのテスト**: バックグラウンド実行

**実践例**:
```bash
# 例1: MCPサーバーの動作確認とテスト
npm run dev &
SERVER_PID=$!
echo $SERVER_PID > /tmp/mcp_server_$$.pid

# MCPツールのテスト実行
echo "Testing MCP tools..."
# 実際のテストコマンドを実行

# サーバー終了
kill $SERVER_PID 2>/dev/null || true
rm -f /tmp/mcp_server_$$.pid

# 例2: Webサーバーの起動とAPIテスト
python -m http.server 8000 &
WEB_PID=$!
echo $WEB_PID > /tmp/web_server_$$.pid

# APIエンドポイントのテスト
curl http://localhost:8000/api/status
curl http://localhost:8000/api/health

# サーバー終了
kill $WEB_PID 2>/dev/null || true
rm -f /tmp/web_server_$$.pid
```

### MCPツール開発時
- **型安全性**: TypeScript + Zodによる厳密な型チェック
- **エラーメッセージ**: ユーザーフレンドリーな警告・エラー
- **後方互換性**: 既存機能への影響を最小化
- **警告システム**: `ai-works-lib/ai-docs/MCP_WARNING_GUIDE.md`との連携
- **ツール制限**: クールダウン・ロック機能の実装