---
inclusion: always
---

# システム保守ガイド

## ドキュメント構造の理解

### ユーザー向けドキュメント
- `README.md`: プロジェクト概要・クイックスタート
- `SYSTEM_OVERVIEW.md`: 詳細なシステム説明
- `IDEA_NOTES.md`: 将来の改善アイデア
- `GEMINI.md`: AI向けシステム仕様（最重要）

### AI向け詳細ドキュメント (`ai-docs/`)
- `GUIDELINES.md`: 運用ガイドライン
- `OPERATION_DETAILS.md`: 運用詳細手順
- `THEME_MANAGEMENT_GUIDE.md`: テーマ管理完全ガイド
- `TROUBLESHOOTING_GUIDE.md`: トラブルシューティング
- `MCP_WARNING_GUIDE.md`: MCPツール警告対応
- `THEME_CONCEPT_GUIDE.md`: テーマ概念説明
- `THEME_CONTEXT_IMPLEMENTATION.md`: テーマ専門家コンテキスト

### サンプル・テンプレート
- `theme_sample/`: テーマファイルのサンプル
- `mcp/ai-heartbeat-mcp/`: MCPツールのソースコード

## 設定ファイル管理

### 主要設定ファイル
```bash
# heartbeat.conf - ハートビート設定
INTERVAL_SECONDS=60                    # ハートビート間隔
INACTIVITY_WARNING_THRESHOLD=300       # 無活動警告閾値（5分）
INACTIVITY_STOP_THRESHOLD=600          # 無活動停止閾値（10分）
TIMESTAMP_ANOMALY_THRESHOLD=900        # タイムスタンプ異常検知閾値（15分）
INTROSPECTION_THRESHOLD=1800           # 内省不足閾値（30分）
MAX_RECOVERY_ATTEMPTS=3                # 最大回復試行回数
MAX_RECOVERY_WAIT_CYCLES=5             # 最大回復待機サイクル数
```

### Gemini CLI設定
```json
// .gemini/settings.json - MCP設定
{
  "mcpServers": {
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
      "args": ["./mcp/ai-heartbeat-mcp/dist/index.js"],
      "trust": true
    }
  }
}
```

## ログ・状態管理

### ログファイルの種類
- `logs/heartbeat_YYYYMMDDHHMMSS.log`: ハートビートログ
- `stats/last_web_search.txt`: Web検索制限管理
- `stats/quota_exceeded.txt`: クォータ制限管理

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
4. 適切なエラーハンドリングを追加

## バージョン管理・リリース

### 重要なファイルの変更管理
- **システムスクリプト**: 慎重なテストが必要
- **GEMINI.md**: AI動作に直接影響するため特に注意
- **ai-docs/**: AIの動作理解に影響
- **MCPツール**: ビルド・テストが必要

### .gitignoreの管理
```gitignore
artifacts/          # AI生成物（除外）
stats/             # システム状態（除外）
logs/              # ログファイル（除外）
*.local            # ローカル設定ファイル（除外）
projects/          # 開発プロジェクト（除外）
results/           # テスト結果（除外）
feedbackbox/       # フィードバック（除外）
themebox/*         # テーマファイル（除外）
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

# 状態ファイル確認・クリア
rm stats/last_web_search.txt
rm stats/quota_exceeded.txt
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

## 将来の拡張性

### アーキテクチャの拡張ポイント
- 新しい異常検知機能の追加
- MCPツールの機能拡張
- 複数AIエージェントの対応
- Web UI・可視化機能の追加

### 互換性の維持
- 既存のファイル形式との互換性
- 設定ファイルの後方互換性
- AIドキュメントの一貫性
- MCPツールのAPIバージョン管理