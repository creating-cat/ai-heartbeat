#!/bin/bash

# AIエージェントIOライブラリ
# tmux経由でのエージェントへのコマンド送信をカプセル化する

# エージェントにメッセージを送信し、Enterキーを押す
# 引数1: 送信するメッセージ
send_message_to_agent() {
    local message="$1"
    tmux send-keys -t agent "$message"
    sleep 1
    tmux send-keys -t agent C-m
}

# エージェントの現在の処理を中断させる（Escapeキーを2回送信）
interrupt_agent() {
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    sleep 1
}

# エージェントにコンテキスト圧縮コマンドを送信する
compress_agent_context() {
    tmux send-keys -t agent "/compress"
    sleep 1
    tmux send-keys -t agent C-m
}

# エージェントにチャット履歴保存コマンドを送信する
# 引数1: 保存用のタグ
save_agent_chat_history() {
    local tag="$1"
    if [ -z "$tag" ]; then
        echo "Error: Chat save tag is required." >&2
        return 1
    fi
    tmux send-keys -t agent "/chat save $tag"
    sleep 1
    tmux send-keys -t agent C-m
}

# エージェントに単一のコマンドを送信する（Enterなし）
# 主に特殊キー（C-mなど）の送信に使用
send_raw_command_to_agent() {
    local command="$1"
    tmux send-keys -t agent "$command"
}