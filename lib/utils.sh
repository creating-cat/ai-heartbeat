#!/bin/bash

# ユーティリティライブラリ
# heartbeat.shから分離されたユーティリティ関数とシステム処理

# 監視対象ディレクトリから最新ファイルの情報を取得する関数
_get_latest_file_info() {
    local latest_info

    # 監視対象ディレクトリの存在確認
    local existing_dirs=()
    for dir in "${MONITORED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            existing_dirs+=("$dir")
        fi
    done
    
    if [ ${#existing_dirs[@]} -eq 0 ]; then
        echo "" # No info to return
        return 1
    fi
    
    # 複数ディレクトリから最新ファイルの更新時刻を取得（macOS対応）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        latest_info=$(find "${existing_dirs[@]}" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -1)
    else
        # Linux
        latest_info=$(find "${existing_dirs[@]}" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -1)
    fi

    echo "$latest_info"
    [ -n "$latest_info" ]
}

# OS判定関数
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# 時間差を分単位で表示する関数
format_duration_minutes() {
    local seconds="$1"
    echo "$((seconds / 60))"
}

# タイムスタンプを秒に変換する関数（OS対応）
convert_timestamp_to_seconds() {
    local timestamp="$1"
    
    if is_macos; then
        # macOS
        date -j -f "%Y%m%d%H%M%S" "$timestamp" "+%s" 2>/dev/null
    else
        # Linux
        local year=${timestamp:0:4}
        local month=${timestamp:4:2}
        local day=${timestamp:6:2}
        local hour=${timestamp:8:2}
        local minute=${timestamp:10:2}
        local second=${timestamp:12:2}
        date -d "${year}-${month}-${day} ${hour}:${minute}:${second}" "+%s" 2>/dev/null
    fi
}

# ファイルの更新時刻を取得する関数（OS対応）
get_file_modification_time() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        return 1
    fi
    
    if is_macos; then
        # macOS
        stat -f %m "$file_path" 2>/dev/null
    else
        # Linux
        stat -c %Y "$file_path" 2>/dev/null
    fi
}

# シグナルを捕捉して安全に終了するための関数
handle_shutdown() {
    log_warning "Shutdown signal received. Finishing current cycle and exiting gracefully..."
    SHUTDOWN_REQUESTED=true
}

# 終了処理
graceful_shutdown() {
    log_notice "Heartbeat stopped gracefully at $(date "+%F %T")"
    exit 0
}