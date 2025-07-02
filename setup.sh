#!/bin/bash

set -e  # エラー時に停止

# AIエージェント起動コマンド
AGENT_COMMAND="gemini -y"

# 初期プロンプト
INIT_PROMPT=$1

if [ -z "$INIT_PROMPT" ]; then
    echo "初期プロンプトを引数として指定してください。"
    exit 1
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

# STEP 5: エージェント起動
log_info "🚀 エージェント起動中..."
tmux send-keys -t agent "$AGENT_COMMAND" C-m
sleep 10  # 少し待機してから次のコマンドを送信
log_success

# STEP 6: エージェントの初期プロンプト実行
log_info "💬 エージェントの初期プロンプト実行中..."
tmux send-keys -t agent "$INIT_PROMPT"
sleep 1  # 少し待機してから次のコマンドを送信
tmux send-keys -t agent C-m
log_success "✅ エージェントの初期プロンプト実行完了"

# STEP 7: ハートビート起動
log_info
tmux send-keys -t heartbeat "./heartbeat.sh" C-m 
log_success "✅ ハートビート起動完了"
                                                      
