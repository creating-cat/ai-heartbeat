#!/bin/bash

# 🚀 Multi-Agent Communication Demo 環境構築
# 参考: setup_full_environment.sh

set -e  # エラー時に停止

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

echo "🤖 Multi-Agent Communication Demo 環境構築"
echo "==========================================="
echo ""

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

# STEP 5: 起動
tmux send-keys -t agent "gemini -y" C-m
tmux send-keys -t heartbeat "./heartbeat.sh" C-m                                                        