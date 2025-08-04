# AI心臓システム ユーザーガイド

このガイドでは、AI心臓システムの各種機能と高度な使用方法について説明します。

**初回利用の方は**: まず [GETTING_STARTED.md](GETTING_STARTED.md) で基本的な使い方を確認してください。

## 目次

- [起動オプション詳細](#起動オプション詳細)
- [高度な機能](#高度な機能)
- [システム制御](#システム制御)
- [カスタマイズ](#カスタマイズ)
- [トラブルシューティング](#トラブルシューティング)

## 起動オプション詳細

### 推奨セットアップ手順

初回利用時は [GETTING_STARTED.md](GETTING_STARTED.md) の手順に従うことを推奨しますが、以下の手順でも開始できます：

```bash
# チュートリアルテーマをコピー
cp ai-works-sample/themebox/000_ai_heartbeat_tutorial.md ai-works/themebox/

# 本テーマを事前準備
echo "テーマ: あなたの探求したいテーマ" > ai-works/themebox/001_your_main_theme.md

# themeboxのテーマで起動
./setup.sh -t
```

AIがシステムを理解してから本格的なタスクを開始するため、より安定した動作が期待できます。

### 基本的な起動方法

```bash
./setup.sh [オプション] <テーマ文字列>
```

#### 1. 直接テーマ指定
```bash
./setup.sh "AIエージェントの自己改善について"
```

最もシンプルな起動方法です。指定したテーマでAIが活動を開始します。

#### 2. ファイルからテーマ読み込み（`-f, --file`）
```bash
# 任意のマークダウンファイルから読み込み
./setup.sh -f my_custom_theme.md

# themeboxからテーマファイルを読み込み
./setup.sh -f ai-works/themebox/001_creative_writing.md
```

**用途例**:
- 事前に準備したテーマファイルの使用
- 複雑で長いテーマ指示の管理
- テーマの再利用とバージョン管理

#### 3. themebox準備済みテーマで起動（`-t, --use-themebox`）
```bash
./setup.sh -t
```

themeboxに準備済みのテーマで起動します（テーマ指定は不要）。

**動作詳細**:
- `draft.*`と`processed.*`を除く有効なテーマファイルの存在を自動検証
- 有効なテーマが見つかった場合、システムを起動
- AIが自動的にthemebox内の有効なテーマを選択・実行

**用途例**:
- 事前に複数のテーマを準備してからシステム起動
- テーマ内容を事前に検討・準備してから実行
- 定期的な運用での標準的な起動方法

##### 複数テーマの事前準備

```bash
# 複数のテーマを事前準備
echo "テーマ: 機械学習の最新動向" > ai-works/themebox/001_ml_trends.md
echo "テーマ: Web開発のベストプラクティス" > ai-works/themebox/002_web_dev.md
echo "テーマ: データ分析手法の比較" > ai-works/themebox/003_data_analysis.md

# 順次実行される
./setup.sh -t
```

#### 4. ディレクトリのみ作成（`-d, --dirs-only`）
```bash
./setup.sh -d
```

必要なディレクトリのみを作成して終了します（tmuxセッションやエージェントは起動しません）。

**用途例**:
- 初回セットアップ時のディレクトリ準備
- CI/CDパイプラインでの環境準備
- 手動でのシステム構築前の準備

#### 5. セッションのみ起動（`-s, --sessions-only`）
```bash
./setup.sh -s
```

tmuxセッションのみを起動します（geminiおよびheartbeatの起動なし）。

**用途例**:
- システム復旧時の段階的起動
- デバッグやメンテナンス作業
- 手動でのプロセス制御が必要な場合

## 高度な機能

### themeboxシステム

新しいテーマを事前に準備しておくためのシステムです。

#### 基本的な使用方法

```bash
# ディレクトリを初期化する
./setup.sh -d

# テーマファイルを準備
echo "テーマ: 量子コンピューティングの未来について" > ai-works/themebox/001_quantum_computing.md

# themeboxの準備済みテーマで起動
./setup.sh -t

# 起動後も追加可能
echo "テーマ: 汎用人工知能の未来について" > ai-works/themebox/002_agi_future.md
```

#### ファイル管理

- `001_theme.md` → **処理対象**（AIが選択・実行）
- `draft.001_theme.md` → **無視**（編集中のドラフト）
- `processed.001_theme.md` → **無視**（使用済みテーマ）

### feedbackboxシステム

AIに対して非同期でフィードバックを提供するシステムです。

#### 基本的な使用方法

```bash
# シンプルなフィードバック
echo "もう少し具体的な例を含めて分析してください" > ai-works/feedbackbox/001_feedback.md
```

#### 通常フィードバック（詳細）

```bash
# 1. ドラフトとして作成（AIは無視）
echo "サイトの画像がうまく表示されてないみたいなので、確認してください。" > ai-works/feedbackbox/draft.001_image_issue.md

# 2. draft.プレフィックスを削除して有効化
mv ai-works/feedbackbox/draft.001_image_issue.md ai-works/feedbackbox/001_image_issue.md

# 3. AIが自動的に確認・対応し、processed.001_image_issue.mdにリネーム
```

#### 割り込みフィードバック

処理を中断してでも即座に確認してほしい内容がある場合：

```bash
# 即座に処理を中断して確認
echo "README.mdの3行目にタイポがあります。今すぐ修正してください" > ai-works/feedbackbox/interrupt.001_typo_fix.md
```

**動作フロー**:
1. `interrupt.`プレフィックスのファイルを検出
2. **即座にAIの処理を中断**
3. 割り込みフィードバックとして通知
4. 処理後は`processed.interrupt.001_typo_fix.md`にリネーム

### スナップショット機能

現在のシステム状態を保存し、後で同じ状態から活動を再開できます。

#### スナップショット作成

* 事前に./stop.shを実行して、動作中のAIエージェントの完了を待ってから、ハートビートとAIエージェントが確実に停止している状態での実行を推奨します。

```bash
./create_snapshot.sh my-project-v1.0
./create_snapshot.sh before-experiment  
./create_snapshot.sh stable-state
./create_snapshot.sh tutorial-completed
```

#### スナップショットからの復元

```bash
# 1. 指定したスナップショットから環境を復元
./setup.sh --snapshot my-project-v1.0

# 2. 必要に応じてthemeboxにテーマを追加
echo "テーマ: 新しい探求テーマ" > ai-works/themebox/101_new_theme.md

# 3. 準備完了後、活動を開始
./restart.sh
```

**主な用途**:
- **開発環境の保存**: 特定の開発段階の状態を保存
- **実験の基準点**: 実験前の安定した状態を保存  
- **バックアップ**: 重要な成果物がある状態を保存
- **環境の複製**: 同じ状態を複数の環境で再現
- **チュートリアルスキップ**: 初期セットアップの高速化



## システム制御

### 停止

```bash
# ハートビートを停止（推奨）
./stop.sh

# または、アタッチしたセッションでCtrl-C
tmux attach-session -t heartbeat
# Ctrl-C で停止
```

### 再起動

```bash
# ハートビートのみ再起動（AIエージェントは継続）
./restart.sh
```

### 完全な再起動

```bash
# システム全体を停止
./stop.sh

# ディレクトリの初期化
./setup.sh -d

# 新しいテーマで再起動
./setup.sh "新しいテーマ"

# または、themeboxのテーマで再起動
./setup.sh -t
```

## カスタマイズ

### 設定ファイルの調整


#### MCP設定の追加
```json
// ai-works/.gemini/settings.json
{
  "mcpServers": {
    "your-custom-mcp": {
      "command": "npx",
      "args": ["your-mcp-package"],
      "trust": true
    }
  }
}
```

### 開発プロジェクトとの連携

```bash
# 既存プロジェクトをクローン
cd ai-works/projects/
git clone https://github.com/example/project.git

# プロジェクト分析のテーマを準備
echo "テーマ: projects/project の分析と改善提案" > ai-works/themebox/001_project_analysis.md
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. 起動時のエラー

**症状**: `./setup.sh`実行時にエラーが発生する

```bash
# 既存セッションの確認・削除
tmux list-sessions
tmux kill-session -t agent 2>/dev/null
tmux kill-session -t heartbeat 2>/dev/null

# 依存関係の確認
gemini --version
tmux -V
node --version

# 再起動
./setup.sh -t
```

#### 2. MCPツールの問題

**症状**: MCPツールのビルドに失敗する、または動作しない

```bash
# Node.jsバージョン確認（18.0以上が必要）
node --version

# 依存関係の再インストール
cd mcp/ai-heartbeat-mcp
rm -rf node_modules package-lock.json
npm install
npm run build

# 設定確認
cat ai-works-lib/.gemini/settings.json
```

**注意**: MCPツールはオプション機能です。ビルドに失敗してもシステムの基本機能は利用できます。

#### 3. ハートビートの停止

**症状**: ハートビートが送信されなくなる

```bash
# ログ確認
tail -f logs/heartbeat_*.log

# 異常検知の確認
grep -E "(WARNING|ERROR)" logs/heartbeat_*.log | tail -10

# 手動再起動
./restart.sh
```

#### 4. AIが応答しない・無限ループ

**症状**: AIが応答しない、または同じ処理を繰り返す

```bash
# エージェントセッションに接続
tmux attach-session -t agent

# Gemini CLIの状態確認・リセット
# エスケープキーを押すなどして処理を中断する

# ハートビート再起動
./restart.sh
```

#### 5. 成果物が生成されない

**症状**: 活動ログは作成されるが、成果物ファイルが生成されない

**原因と対処**:
- **テーマが抽象的すぎる場合**: より具体的なテーマを指定
- **ディスク容量不足**: 容量を確認し、不要なファイルを削除

```bash
# ディスク容量確認
df -h .

# 古いファイルの削除
find logs/ -name "heartbeat_*.log" -mtime +30 -delete
ls -la ai-works/artifacts/  # 古いテーマディレクトリの確認
```

#### 7. Gemini CLIの認証問題

**症状**: 認証エラーが発生する

```bash
# 認証状態確認
gemini auth status

# 再認証
gemini auth login

# APIキーの確認（環境変数使用の場合）
echo $GEMINI_API_KEY
```

### ログの見方と診断

#### 正常な動作パターン
```
[HEARTBEAT] Heartbeat sent to agent session
[INFO] Agent activity detected
[INFO] Activity log created: 20250104143000.md
```

#### 異常検知パターン
```
[WARNING] Abnormal activity detected: 無活動状態 (attempt 1/3)
[INFO] Attempting recovery...
[INFO] Recovery message sent to agent
```

#### 回復成功パターン
```
[INFO] Agent recovery confirmed. Returning to normal state.
[INFO] Resuming normal heartbeat cycle
```

#### エラーパターン
```
[ERROR] Maximum recovery attempts reached (3/3)
[ERROR] System will stop to prevent further issues
```

### デバッグモード

詳細な診断情報が必要な場合：

```bash
# デバッグモードでハートビート起動
DEBUG_MODE=true ./restart.sh

# 詳細ログの確認
tail -f logs/heartbeat_*.log
```


### 問題報告時の情報収集

サポートが必要な場合は、以下の情報を収集してください：

```bash
# システム情報
uname -a
tmux -V
gemini --version
node --version

# セッション状態
tmux list-sessions

# 最新ログ（エラー部分）
grep -E "(ERROR|WARNING)" logs/heartbeat_*.log | tail -20

# ディレクトリ状態
ls -la ai-works/
ls -la ai-works/artifacts/

# MCPツール状態（該当する場合）
cd mcp/ai-heartbeat-mcp && npm run build
```

## 参考情報

### 出力ファイルの構造

```
ai-works/
├── artifacts/                  # AI生成物保存
│   ├── theme_histories/        # テーマ履歴記録
│   ├── 20250101120000_theme_name/  # テーマディレクトリ
│   │   ├── histories/          # 活動ログ
│   │   └── *.md, *.html, *.js  # 成果物
├── themebox/                   # テーマ事前準備
├── feedbackbox/                # ユーザーフィードバック
├── projects/                   # 開発プロジェクト
└── stats/                      # システム状態管理
```

### 主要な出力ファイル

- **活動ログ**: `ai-works/artifacts/*/histories/*.md`
- **成果物**: `ai-works/artifacts/*/` 配下の各種ファイル
- **テーマ履歴**: `ai-works/artifacts/theme_histories/*.md`
- **システムログ**: `logs/heartbeat_*.log`

## さらに詳しく

- **[GETTING_STARTED.md](GETTING_STARTED.md)**: 初回利用時の基本的な使い方
- **[SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md)**: システムの技術的詳細

このガイドを参考に、AI心臓システムを効果的に活用してください。