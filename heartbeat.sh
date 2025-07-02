#!/bin/bash

# ハートビートの間隔（秒）
INTERVAL_SECONDS=60

while true; do
    # カウントダウン
    for i in $(seq ${INTERVAL_SECONDS} -1 1); do
        # \r を使ってカーソルを行頭に戻し、同じ行に上書き表示する
        printf "\rNext heartbeat in %2d seconds... " "$i"
        sleep 1
    done
    # カウントダウン表示をクリア
    printf "\r                                   \r"

    echo "Sending heartbeat at $(date "+%F %T")"
    tmux send-keys -t agent "Heartbeat: $(date "+%F %T")"
    sleep 1
    tmux send-keys -t agent C-m
done