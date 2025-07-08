#!/bin/bash

set -e  # エラー時に停止

# AIエージェント起動コマンド
AGENT_COMMAND="gemini -y"

# 使用方法表示
usage() {
    echo "使用方法: $0 [オプション] <テーマ文字列>"
    echo "オプション:"
    echo "  -f, --file <ファイル>   指定したファイルから初期テーマを読み込む"
    echo "  -d, --dirs-only        必要なディレクトリのみを作成して終了（tmuxセッションやエージェントは起動しない）"
    echo "  -s, --sessions-only    tmuxセッションのみを起動（geminiおよびheartbeatの起動なし）"
    echo "  -h, --help             このヘルプメッセージを表示"
    exit 1
}

# 引数解析
INIT_PROMPT=""
FILE_INPUT=""
DIRS_ONLY=false
SESSIONS_ONLY=false

# 引数がない場合はヘルプを表示
if [ $# -eq 0 ]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "エラー: -f/--file オプションにはファイル名が必要です"
                usage
            fi
            FILE_INPUT="$2"
            shift 2
            ;;
        -d|--dirs-only)
            DIRS_ONLY=true
            shift
            ;;
        -s|--sessions-only)
            SESSIONS_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            INIT_PROMPT="$1"
            shift
            ;;
    esac
done

# テーマ取得
if [ -n "$FILE_INPUT" ]; then
    if [ ! -f "$FILE_INPUT" ]; then
        echo "エラー: ファイル '$FILE_INPUT' が見つかりません"
        exit 1
    fi
    # ファイルからテーマを読み込む
    INIT_PROMPT=$(cat "$FILE_INPUT")
    echo "ファイル '$FILE_INPUT' からテーマを読み込みました"
fi

# テーマが空の場合はエラー（ディレクトリ作成のみ・セッションのみの場合は除く）
if [ -z "$INIT_PROMPT" ] && [ "$DIRS_ONLY" = false ] && [ "$SESSIONS_ONLY" = false ]; then
    echo "エラー: テーマが指定されていません"
    usage
fi

mkdir -p artifacts
mkdir -p themebox
mkdir -p projects

# ディレクトリ作成のみのオプションが指定された場合はここで終了
if [ "$DIRS_ONLY" = true ]; then
    echo -e "\033[1;32m[INFO]\033[0m 必要なディレクトリを作成しました:"
    echo "  - artifacts/"
    echo "  - themebox/"
    echo "  - projects/"
    echo "セットアップを終了します。"
    exit 0
fi

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

# STEP 1: 既存セッションクリーンアップ
log_info "🧹 既存セッションクリーンアップ開始..."

tmux kill-session -t agent 2>/dev/null && log_info "agentセッション削除完了" || log_info "agentセッションは存在しませんでした"
tmux kill-session -t heartbeat 2>/dev/null && log_info "heartbeatセッション削除完了" || log_info "heartbeatセッションは存在しませんでした"

# STEP 2: agentセッション作成
log_info "📺 agentセッション作成開始..."

# agentセッション作成
tmux new-session -d -s agent

log_success "✅ agentセッション作成完了"
echo ""

# STEP 3: heartbeatセッション作成（1ペイン）
log_info "👑 heartbeatセッション作成開始..."

tmux new-session -d -s heartbeat

log_success "✅ heartbeatセッション作成完了"
echo ""

# STEP 4: 環境確認・表示
log_info "🔍 環境確認中..."

echo ""
echo "📊 セットアップ結果:"
echo "==================="

# tmuxセッション確認
echo "📺 Tmux Sessions:"
tmux list-sessions
echo ""

# セッションのみモードの場合はここで終了
if [ "$SESSIONS_ONLY" = true ]; then
    echo ""
    log_info "🔧 セッションのみモード: tmuxセッションのみを起動しました"
    echo ""
    echo "📋 手動復帰の手順:"
    echo "==================="
    echo "1. エージェントセッションに接続: tmux attach-session -t agent"
    echo "2. Gemini CLIを手動起動: gemini -y"
    echo "3. 必要に応じて初期テーマの送信や/chat resumeなどを実行"
    echo "4. ハートビートを手動起動: ./restart.sh"
    echo ""
    log_success "✅ セッション起動完了（手動復帰モード）"
    exit 0
fi

# STEP 5: エージェント起動
log_info "🚀 エージェント起動中..."
tmux send-keys -t agent "$AGENT_COMMAND" C-m
sleep 10  # gemini-cliの起動を待機
log_success "✅ エージェントプロセス起動コマンド送信完了"
echo ""

# STEP 6: エージェントの初期プロンプト実行
log_info "💬 エージェントの初期プロンプト実行中..."
TIMESTAMP=$(date "+%Y%m%d%H%M%S")
INIT_PROMPT_WITH_TIMESTAMP="Initial Theme (${TIMESTAMP}): ${INIT_PROMPT}"
tmux send-keys -t agent "$INIT_PROMPT_WITH_TIMESTAMP"
sleep 1
tmux send-keys -t agent C-m
log_success "✅ エージェントの初期プロンプト実行完了"
echo ""

# STEP 7: ハートビート起動
log_info "❤️ ハートビート起動中..."
tmux send-keys -t heartbeat "./heartbeat.sh" C-m 
log_success "✅ ハートビート起動完了"
                                                      
