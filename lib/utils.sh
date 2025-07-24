#!/bin/bash

# ユーティリティライブラリ
# heartbeat.shから分離されたユーティリティ関数とシステム処理

# インクルードガード
if [ -n "$_UTILS_SH_INCLUDED" ]; then
    return 0
fi
_UTILS_SH_INCLUDED=1

# 依存関係の読み込み（条件付き）
if [ -z "$_LOGGING_SH_INCLUDED" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

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

# 原子的ファイル書き込み関数
# 引数1: 書き込み内容
# 引数2: 出力ファイルパス
# 引数3: (オプション) ディレクトリ作成フラグ (true/false, デフォルト: true)
write_file_atomic() {
    local content="$1"
    local output_file="$2"
    local create_dir="${3:-true}"
    
    # 入力検証
    if [ -z "$output_file" ]; then
        log_error "write_file_atomic: output_file is required"
        return 1
    fi
    
    # ディレクトリ作成（オプション）
    if [ "$create_dir" = "true" ]; then
        local dir_path=$(dirname "$output_file")
        if [ ! -d "$dir_path" ]; then
            if ! mkdir -p "$dir_path" 2>/dev/null; then
                log_error "write_file_atomic: Failed to create directory: $dir_path"
                return 1
            fi
        fi
    fi
    
    # 一時ファイル作成（同じディレクトリ内）
    local temp_file="${output_file}.tmp.$$"
    
    # 原子的書き込み実行
    if echo "$content" > "$temp_file" 2>/dev/null; then
        if mv "$temp_file" "$output_file" 2>/dev/null; then
            return 0
        else
            log_error "write_file_atomic: Failed to move temp file to final location: $output_file"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    else
        log_error "write_file_atomic: Failed to write to temp file: $temp_file"
        rm -f "$temp_file" 2>/dev/null
        return 1
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