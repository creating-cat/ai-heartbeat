#!/bin/bash

set -e  # エラー時に停止

# --- 依存コマンドチェック ---
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "\033[1;31m[ERROR]\033[0m コマンドが見つかりません: $1"
        echo "README.mdのシステム要件に従ってインストールしてください。"
        exit 1
    fi
}
check_command "tmux"
check_command "gemini"

# AIエージェント起動コマンド
AGENT_COMMAND="gemini -y"

# 使用方法表示
usage() {
    echo "使用方法: $0 [オプション] <テーマ文字列>"
    echo "  テーマ指定オプション (いずれか1つを選択):"
    echo "    <テーマ文字列>          指定した文字列を初期テーマとして起動します。"
    echo "    -f, --file <ファイル>   指定したファイルから初期テーマを読み込んで起動します。"
    echo "    -t, --use-themebox      themeboxに準備済みのテーマで起動します（テーマ指定は不要）。"
    echo "  その他のオプション:"
    echo "    -d, --dirs-only         必要なディレクトリのみを作成して終了します。"
    echo "    -s, --sessions-only     tmuxセッションのみを起動します。"
    echo "    -h, --help              このヘルプメッセージを表示します。"
    echo ""
    exit 1
}

# 引数解析
INIT_PROMPT=""
FILE_INPUT=""
DIRS_ONLY=false
SESSIONS_ONLY=false
USE_THEMEBOX=false

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
        -t|--use-themebox)
            USE_THEMEBOX=true
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

# オプションの排他チェック
theme_options_count=0
[ -n "$INIT_PROMPT" ] && ((theme_options_count++))
[ -n "$FILE_INPUT" ] && ((theme_options_count++))
[ "$USE_THEMEBOX" = true ] && ((theme_options_count++))

if [ "$theme_options_count" -gt 1 ]; then
    echo "エラー: テーマ指定オプション（テーマ文字列, -f, -t）は1つしか指定できません。"
    usage
fi

# DIRS_ONLY, SESSIONS_ONLY以外の場合、テーマ指定は必須
if [ "$theme_options_count" -eq 0 ] && [ "$DIRS_ONLY" = false ] && [ "$SESSIONS_ONLY" = false ]; then
    echo "エラー: 起動するテーマが指定されていません。"
    usage
fi

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

mkdir -p artifacts
mkdir -p themebox
mkdir -p feedbackbox
mkdir -p projects

# ディレクトリ作成のみのオプションが指定された場合はここで終了
if [ "$DIRS_ONLY" = true ]; then
    echo -e "\033[1;32m[INFO]\033[0m 必要なディレクトリを作成しました:"
    echo "  - artifacts/"
    echo "  - themebox/"
    echo "  - feedbackbox/"
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
    echo "3. 必要に応じて/chat resumeなどを実行"
    echo "4. ハートビートを手動起動: ./restart.sh"
    echo ""
    log_success "✅ セッション起動完了（手動復帰モード）"
    exit 0
fi

# STEP 5: テーマ投入/確認

# themeboxに有効なテーマファイルがあるかチェックする関数
has_active_themes() {
    # find ... -print -quit を使うと、1つでも見つかったらすぐに終了するので効率的
    if [ -n "$(find themebox -maxdepth 1 -name "*.md" -not -name "draft.*" -not -name "processed.*" -print -quit)" ]; then
        return 0 # true
    else
        return 1 # false
    fi
}

if [ "$USE_THEMEBOX" = true ]; then
    log_info "🔍 themebox内のテーマで起動します..."
    if has_active_themes; then
        log_success "✅ themeboxに有効なテーマが見つかりました。システムを起動します。"
    else
        echo "エラー: -t オプションが指定されましたが、themeboxに実行可能なテーマがありません。"
        exit 1
    fi
elif [ -n "$INIT_PROMPT" ]; then
    log_info "📝 新しい初期テーマを投入します..."
    if has_active_themes; then
        echo "エラー: 新しいテーマを投入しようとしましたが、themeboxに未処理のテーマが存在します。"
        echo "       -t オプションを使用するか、themebox内のファイルを整理してください。"
        exit 1
    else
        TIMESTAMP=$(date "+%Y%m%d%H%M%S")
        THEME_FILE="themebox/000_initial_theme_${TIMESTAMP}.md"
        cat > "$THEME_FILE" << EOF
# 初期テーマ

$INIT_PROMPT
EOF
        log_success "✅ 初期テーマをthemeboxに投入しました: $THEME_FILE"
        log_info "ℹ️ テーマは最初のハートビートで自動的に開始されます"
    fi
fi

echo ""

# STEP 6: エージェント起動
log_info "🚀 エージェント起動中..."
tmux send-keys -t agent "$AGENT_COMMAND" C-m
sleep 10  # gemini-cliの起動を待機
log_success "✅ エージェントプロセス起動コマンド送信完了"
echo ""

# STEP 7: ハートビート起動
log_info "❤️ ハートビート起動中..."
tmux send-keys -t heartbeat "./heartbeat.sh" C-m 
log_success "✅ ハートビート起動完了"
                                                      
