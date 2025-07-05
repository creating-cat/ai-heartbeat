#!/bin/bash

tmux send-keys -t heartbeat C-c
sleep 2
tmux send-keys -t heartbeat "./heartbeat.sh" C-m

echo "Heartbeat restarted."