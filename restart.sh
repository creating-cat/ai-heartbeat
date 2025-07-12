#!/bin/bash

tmux send-keys -t heartbeat C-c
sleep 5s
tmux send-keys -t heartbeat "./heartbeat.sh" C-m

echo "Heartbeat restarted."
