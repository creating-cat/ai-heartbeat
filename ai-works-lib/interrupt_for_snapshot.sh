#!/bin/bash

# gemini cli側がスリープするまで待つ
sleep 30

# gemini cliの処理の割り込みを行い停止させる。
tmux send-keys -t agent Escape
sleep 1
tmux send-keys -t agent Escape
sleep 1

echo "Agent interrupted successfully."

# スナップショット作成スクリプトの実行
cd ../

./create_snapshot.sh "snapshot_$(date +%Y%m%d_%H%M%S)"

echo "Create snapshot successfully."

# ハートビートの再起動
./restart.sh

echo "Restarted successfully."
