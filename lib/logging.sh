#!/bin/bash

# ログ管理ライブラリ
# heartbeat.shから分離されたログ機能

# インクルードガード
if [ -n "$_LOGGING_SH_INCLUDED" ]; then
    return 0
fi
_LOGGING_SH_INCLUDED=1

# ログ設定変数（外部から設定）
LOG_FILE=""
LOG_DIR=""
DEBUG_MODE=false
MAX_LOG_DAYS=30

# ログシステムの初期化
init_logging() {
    local log_file="$1"
    local log_dir="$2"
    local debug_mode="${3:-false}"
    local max_log_days="${4:-30}"
    
    LOG_FILE="$log_file"
    LOG_DIR="$log_dir"
    DEBUG_MODE="$debug_mode"
    MAX_LOG_DAYS="$max_log_days"
    
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    cleanup_old_logs
}

# 古いログファイルのクリーンアップ関数
cleanup_old_logs() {
    if [ -d "$LOG_DIR" ] && [ ! -z "$MAX_LOG_DAYS" ]; then
        # MAX_LOG_DAYS日以上古いheartbeatログファイルを削除
        find "$LOG_DIR" -name "heartbeat_*.log" -type f -mtime +$MAX_LOG_DAYS -delete 2>/dev/null
    fi
}

# 色付きログ関数（ファイル出力機能付き）
log_warning() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;33m[WARNING]\033[0m $message"
    if [ ! -z "$LOG_FILE" ]; then
        echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;31m[ERROR]\033[0m $message"
    if [ ! -z "$LOG_FILE" ]; then
        echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
    fi
}

log_info() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;32m[INFO]\033[0m $message"  # 常に標準出力
    
    # デバッグモードの時のみログファイルに記録
    if [ "$DEBUG_MODE" = "true" ] && [ ! -z "$LOG_FILE" ]; then
        echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
    fi
}

log_notice() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;36m[NOTICE]\033[0m $message"  # 常に標準出力（シアン色）
    if [ ! -z "$LOG_FILE" ]; then
        echo "[$timestamp] [NOTICE] $message" >> "$LOG_FILE"  # 常にログファイルに記録
    fi
}

log_heartbeat() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "Sending heartbeat at $(date "+%F %T")"
    if [ ! -z "$LOG_FILE" ]; then
        echo "[$timestamp] [HEARTBEAT] $message" >> "$LOG_FILE"
    fi
}