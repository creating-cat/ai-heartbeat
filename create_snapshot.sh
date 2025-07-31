#!/bin/bash

set -e  # エラー時に停止

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# スナップショット作成関数
create_snapshot() {
    local snapshot_name="$1"
    local snapshot_dir="snapshots/$snapshot_name"
    
    log_info "📸 スナップショット作成を開始します..."
    
    # 必要なディレクトリの確認
    if [ ! -d "ai-works" ]; then
        log_error "ai-works ディレクトリが見つかりません。"
        exit 1
    fi
    
    # スナップショットディレクトリの作成
    log_info "📁 スナップショットディレクトリを作成中..."
    mkdir -p "$snapshot_dir"
    
    # チャット履歴の保存
    log_info "💬 チャット履歴を保存中..."
    if tmux list-sessions | grep -q "agent"; then
        tmux send-keys -t agent "/chat save $snapshot_name"
        sleep 1
        tmux send-keys -t agent C-m
        sleep 3  # 保存処理の待機
        log_success "✅ チャット履歴保存完了"
    else
        log_error "agentセッションが見つかりません。"
        exit 1
    fi
    
    # ai-worksディレクトリのアーカイブ作成
    log_info "📦 ai-worksディレクトリをアーカイブ中..."
    tar -czf "$snapshot_dir/ai_works.tar.gz" ai-works/
    
    if [ -f "$snapshot_dir/ai_works.tar.gz" ]; then
        log_success "✅ アーカイブ作成完了: $snapshot_dir/ai_works.tar.gz"
    else
        log_error "アーカイブの作成に失敗しました。"
        exit 1
    fi
    
    # 実行済みフラグの作成
    log_info "🏁 実行済みフラグを作成中..."
    mkdir -p "ai-works/stats"
    touch "ai-works/stats/snapshot_created.flag"
    log_success "✅ 実行済みフラグ作成完了"
    
    # スナップショット情報の表示
    local archive_size=$(du -h "$snapshot_dir/ai_works.tar.gz" | cut -f1)
    
    echo ""
    log_success "🎉 スナップショット作成完了！"
    echo ""
    echo "📊 スナップショット情報:"
    echo "==================="
    echo "名前: $snapshot_name"
    echo "場所: $snapshot_dir/"
    echo "アーカイブサイズ: $archive_size"
    echo "作成日時: $(date)"
    echo ""
    echo "📋 使用方法:"
    echo "新しい環境で以下のコマンドを実行してください："
    echo "  ./setup.sh --snapshot"
    echo ""
}

# メイン処理
main() {
    echo "🚀 AI心臓システム スナップショット作成ツール"
    echo "============================================="
    echo ""
    
    # 引数チェック
    if [ $# -ne 1 ]; then
        log_error "スナップショット名を指定してください。"
        echo ""
        echo "使用方法: $0 <スナップショット名>"
        echo ""
        echo "例:"
        echo "  $0 tutorial-completed"
        echo "  $0 development-v1.0"
        echo "  $0 before-major-update"
        exit 1
    fi
    
    local snapshot_name="$1"
    local snapshot_dir="snapshots/$snapshot_name"
    
    # 既存スナップショットチェック
    if [ -d "$snapshot_dir" ]; then
        log_error "スナップショット '$snapshot_name' は既に存在します。"
        log_info "既存のスナップショット: $snapshot_dir/"
        log_info "別の名前を指定するか、既存のスナップショットを削除してください。"
        exit 1
    fi
    
    create_snapshot "$snapshot_name"
}

# スクリプト実行
main "$@"