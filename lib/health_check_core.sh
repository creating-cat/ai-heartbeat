#!/bin/bash

# 異常検知コアライブラリ
# 純粋な判定ロジックのみを含む（副作用なし）
# 戻り値統一: 0=正常, 1=警告レベル, 2=エラーレベル
# 出力形式: "LEVEL:ANOMALY_TYPE:detail"

# DEBUG_MODE="true"

# デバッグログ関数（標準エラー出力専用、依存関係なし）
debug_log() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[DEBUG][HEALTH_CHECK] $1" >&2
    fi
}

debug_warning() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[DEBUG WARNING][HEALTH_CHECK] $1" >&2
    fi
}

# 無活動状態異常の判定
# 引数: latest_time, current_time, warning_threshold, stop_threshold, heartbeat_start_time
# 戻り値: 0=正常, 1=警告, 2=エラー
# 出力: "LEVEL:ANOMALY_TYPE:detail" 形式
check_inactivity_anomaly() {
    local latest_time="$1"
    local current_time="$2"
    local warning_threshold="$3"
    local stop_threshold="$4"
    local heartbeat_start_time="$5"
    
    debug_log "INACTIVITY check started: latest_time=$latest_time, current_time=$current_time"
    debug_log "INACTIVITY thresholds: warning=${warning_threshold}s, stop=${stop_threshold}s"
    
    # スクリプト開始時刻より前のファイルの場合、開始時刻からの経過時間で判定
    local diff
    if [ $latest_time -lt $heartbeat_start_time ]; then
        diff=$((current_time - heartbeat_start_time))
        debug_log "INACTIVITY: Using heartbeat start time as baseline (file older than heartbeat start)"
    else
        diff=$((current_time - latest_time))
        debug_log "INACTIVITY: Using file time as baseline"
    fi
    
    debug_log "INACTIVITY: Time difference = ${diff}s"
    
    if [ $diff -gt $stop_threshold ]; then
        debug_warning "INACTIVITY: Error level reached (${diff}s > ${stop_threshold}s)"
        echo "$diff"
        return 2
    elif [ $diff -gt $warning_threshold ]; then
        debug_log "INACTIVITY: Warning level reached (${diff}s > ${warning_threshold}s)"
        echo "$diff"
        return 1
    fi
    
    debug_log "INACTIVITY: Normal operation (${diff}s <= ${warning_threshold}s)"
    echo "$diff"
    return 0
}

# 同一ファイル継続更新ループ異常の判定
# 引数: current_filename, previous_filename, loop_start_time, current_time, threshold
# 戻り値: 0=正常, 2=エラー
# 出力: "LEVEL:ANOMALY_TYPE:detail" 形式
check_loop_anomaly() {
    local current_filename="$1"
    local previous_filename="$2"
    local loop_start_time="$3"
    local current_time="$4"
    local threshold="$5"
    
    debug_log "LOOP check started: current_file=$(basename "$current_filename"), previous_file=$(basename "$previous_filename")"
    debug_log "LOOP threshold: ${threshold}s"
    
    if [ "$current_filename" = "$previous_filename" ]; then
        debug_log "LOOP: Same file detected"
        if [ ! -z "$loop_start_time" ]; then
            local duration=$((current_time - loop_start_time))
            debug_log "LOOP: Duration = ${duration}s"
            if [ $duration -gt $threshold ]; then
                debug_warning "LOOP: Error level reached (${duration}s > ${threshold}s)"
                echo "$duration"
                return 2
            fi
            debug_log "LOOP: Monitoring same file (${duration}s <= ${threshold}s)"
            echo "$duration"
            return 0
        else
            debug_log "LOOP: Starting loop detection"
            echo "0"
            return 0
        fi
    else
        debug_log "LOOP: Different file detected, resetting loop detection"
        echo "0"
        return 0
    fi
}

# ファイル名タイムスタンプ異常の判定
# 引数: filename, current_time, threshold, heartbeat_start_time
# 戻り値: 0=正常, 2=エラー
# 出力: "LEVEL:ANOMALY_TYPE:detail" 形式
check_timestamp_anomaly() {
    local filename="$1"
    local current_time="$2"
    local threshold="$3"
    local heartbeat_start_time="$4"
    
    local filename_only=$(basename "$filename")
    debug_log "TIMESTAMP check started: file=$filename_only, threshold=${threshold}s"
    
    # ファイル名がタイムスタンプ形式かチェック
    if [[ ! "$filename_only" =~ ^[0-9]{14}(_[a-zA-Z]+_.*)?\.md$ ]]; then
        debug_log "TIMESTAMP: File does not match timestamp pattern"
        echo "OK:TIMESTAMP:0"
        return 0
    fi
    
    # ファイル名からタイムスタンプを抽出（最初の14桁）
    local file_timestamp=$(echo "$filename_only" | grep -o '^[0-9]\{14\}')
    if [ -z "$file_timestamp" ]; then
        debug_log "TIMESTAMP: Could not extract timestamp from filename"
        echo "OK:TIMESTAMP:0"
        return 0
    fi
    
    debug_log "TIMESTAMP: Extracted timestamp = $file_timestamp"
    
    # タイムスタンプを秒に変換
    local file_time=$(convert_timestamp_to_seconds "$file_timestamp")
    if [ -z "$file_time" ]; then
        debug_log "TIMESTAMP: Could not convert timestamp to seconds"
        echo "OK:TIMESTAMP:0"
        return 0
    fi
    
    debug_log "TIMESTAMP: File time = $file_time, heartbeat start = $heartbeat_start_time"
    
    # ファイル名タイムスタンプがハートビート起動前の場合、起動時刻を基軸とする
    local timestamp_diff
    if [ $file_time -lt $heartbeat_start_time ]; then
        timestamp_diff=$((current_time - heartbeat_start_time))
        debug_log "TIMESTAMP: Using heartbeat start time as baseline (file older than heartbeat start)"
    else
        timestamp_diff=$((current_time - file_time))
        debug_log "TIMESTAMP: Using file time as baseline"
    fi
    
    debug_log "TIMESTAMP: Time difference = ${timestamp_diff}s"
    
    # 未来のタイムスタンプの場合はスキップ
    if [ $timestamp_diff -lt 0 ]; then
        debug_log "TIMESTAMP: Future timestamp detected, skipping"
        echo "0"
        return 0
    elif [ $timestamp_diff -gt $threshold ]; then
        debug_warning "TIMESTAMP: Error level reached (${timestamp_diff}s > ${threshold}s)"
        echo "$timestamp_diff"
        return 2
    fi
    
    debug_log "TIMESTAMP: Normal operation (${timestamp_diff}s <= ${threshold}s)"
    echo "$timestamp_diff"
    return 0
}

# 内省活動不足異常の判定
# 引数: latest_introspection_timestamp, current_time, introspection_threshold, heartbeat_start_time
# 戻り値: 0=正常, 1=警告, 2=エラー
# 出力: "LEVEL:ANOMALY_TYPE:detail" 形式
check_introspection_anomaly() {
    local latest_introspection_timestamp="$1"
    local current_time="$2"
    local introspection_threshold="$3"
    local heartbeat_start_time="$4"
    
    debug_log "INTROSPECTION check started: latest_timestamp=$latest_introspection_timestamp, threshold=${introspection_threshold}s"
    
    local introspection_diff
    
    # 内省活動が見つからない場合、またはハートビート起動前の場合の処理
    if [ -z "$latest_introspection_timestamp" ]; then
        # ハートビート起動からの経過時間で判定
        introspection_diff=$((current_time - heartbeat_start_time))
        debug_log "INTROSPECTION: No introspection found, using heartbeat start time"
    else
        # タイムスタンプを秒に変換
        local file_time=$(convert_timestamp_to_seconds "$latest_introspection_timestamp")
        debug_log "INTROSPECTION: Latest timestamp = $latest_introspection_timestamp, converted = $file_time"
        
        if [ -z "$file_time" ] || [ $file_time -lt $heartbeat_start_time ]; then
            # 変換失敗またはハートビート起動前の場合、起動時刻を基軸とする
            introspection_diff=$((current_time - heartbeat_start_time))
            debug_log "INTROSPECTION: Using heartbeat start time as baseline (conversion failed or file older)"
        else
            # 通常の判定（ハートビート起動後の内省活動）
            introspection_diff=$((current_time - file_time))
            debug_log "INTROSPECTION: Using file time as baseline"
        fi
    fi
    
    # 警告閾値（内省閾値の2/3）を設定
    local introspection_warning_threshold=$((introspection_threshold * 2 / 3))
    debug_log "INTROSPECTION: Time difference = ${introspection_diff}s, warning_threshold = ${introspection_warning_threshold}s"
    
    if [ $introspection_diff -gt $introspection_threshold ]; then
        debug_warning "INTROSPECTION: Error level reached (${introspection_diff}s > ${introspection_threshold}s)"
        echo "$introspection_diff"
        return 2
    elif [ $introspection_diff -gt $introspection_warning_threshold ]; then
        debug_log "INTROSPECTION: Warning level reached (${introspection_diff}s > ${introspection_warning_threshold}s)"
        echo "$introspection_diff"
        return 1
    fi
    
    debug_log "INTROSPECTION: Normal operation (${introspection_diff}s <= ${introspection_warning_threshold}s)"
    echo "$introspection_diff"
    return 0
}

# 思考ログ重複作成異常の判定（3つ以上のファイル）
# 引数: artifacts_dir, current_time
# 戻り値: 0=正常, 2=エラー
# 出力: "LEVEL:THINKING_LOG:detail" 形式
check_thinking_log_duplicate() {
    local artifacts_dir="$1"
    local current_time="$2"
    
    debug_log "THINKING_LOG_DUPLICATE check started: artifacts_dir=$artifacts_dir"
    
    # 思考ログファイルを検索（artifacts/*/histories/YYYYMMDDHHMMSS*.md）
    local thinking_log_files=$(find "$artifacts_dir" -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f 2>/dev/null)
    
    if [ -z "$thinking_log_files" ]; then
        debug_log "THINKING_LOG_DUPLICATE: No thinking log files found in */histories/ directories"
        echo "0"
        return 0
    fi
    
    # 最新タイムスタンプを取得
    local latest_timestamp=$(echo "$thinking_log_files" | \
        sed 's|.*/||' | \
        grep -o '^[0-9]\{14\}' | \
        sort -r | \
        head -1)
    
    if [ -z "$latest_timestamp" ]; then
        debug_log "THINKING_LOG_DUPLICATE: No valid timestamp found in thinking log files"
        echo "0"
        return 0
    fi
    
    debug_log "THINKING_LOG_DUPLICATE: Latest timestamp = $latest_timestamp"
    
    # 同じタイムスタンプの思考ログファイル数をカウント
    local same_timestamp_count=$(find "$artifacts_dir" -path "*/histories/${latest_timestamp}*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    debug_log "THINKING_LOG_DUPLICATE: Same timestamp file count = $same_timestamp_count"
    
    # 同じタイムスタンプで3つ以上のファイルがある場合は重複作成異常
    if [ $same_timestamp_count -ge 3 ]; then
        debug_warning "THINKING_LOG_DUPLICATE: Error detected ($same_timestamp_count files >= 3)"
        echo "$same_timestamp_count"
        return 2
    fi
    
    debug_log "THINKING_LOG_DUPLICATE: Normal operation ($same_timestamp_count file < 3)"
    echo "$same_timestamp_count"
    return 0
}

# 思考ログ繰り返し更新異常の判定（2つのファイル）
# 引数: artifacts_dir, current_time
# 戻り値: 0=正常, 2=エラー
# 出力: "LEVEL:THINKING_LOG:detail" 形式
check_thinking_log_repeat() {
    local artifacts_dir="$1"
    local current_time="$2"
    
    debug_log "THINKING_LOG_REPEAT check started: artifacts_dir=$artifacts_dir"
    
    # 思考ログファイルを検索（artifacts/*/histories/YYYYMMDDHHMMSS*.md）
    local thinking_log_files=$(find "$artifacts_dir" -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f 2>/dev/null)
    
    if [ -z "$thinking_log_files" ]; then
        debug_log "THINKING_LOG_REPEAT: No thinking log files found in */histories/ directories"
        echo "0"
        return 0
    fi
    
    # 最新タイムスタンプを取得
    local latest_timestamp=$(echo "$thinking_log_files" | \
        sed 's|.*/||' | \
        grep -o '^[0-9]\{14\}' | \
        sort -r | \
        head -1)
    
    if [ -z "$latest_timestamp" ]; then
        debug_log "THINKING_LOG_REPEAT: No valid timestamp found in thinking log files"
        echo "0"
        return 0
    fi
    
    debug_log "THINKING_LOG_REPEAT: Latest timestamp = $latest_timestamp"
    
    # 同じタイムスタンプの思考ログファイル数をカウント
    local same_timestamp_count=$(find "$artifacts_dir" -path "*/histories/${latest_timestamp}*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    debug_log "THINKING_LOG_REPEAT: Same timestamp file count = $same_timestamp_count"
    
    # 同じタイムスタンプで2つのファイルがある場合は繰り返し更新異常
    # 連番ファイル（YYYYMMDDHHMMSS_01.md等）の存在を検知
    if [ $same_timestamp_count -eq 2 ]; then
        debug_warning "THINKING_LOG_REPEAT: Error detected ($same_timestamp_count files = 2)"
        echo "$same_timestamp_count"
        return 2
    fi
    
    debug_log "THINKING_LOG_REPEAT: Normal operation ($same_timestamp_count file != 2)"
    echo "$same_timestamp_count"
    return 0
}

# テーマログ異常の判定（新機能）
# 引数: artifacts_dir, current_time
# 戻り値: 0=正常, 2=エラー
# 出力: "LEVEL:ANOMALY_TYPE:detail" 形式
check_theme_log_anomaly() {
    local artifacts_dir="$1"
    local current_time="$2"
    
    debug_log "THEME_LOG check started: artifacts_dir=$artifacts_dir"
    
    # テーマ履歴ファイルを検索（artifacts/theme_histories/YYYYMMDDHHMMSS_start_*.md, YYYYMMDDHHMMSS_end_*.md）
    local theme_log_files=$(find "$artifacts_dir/theme_histories" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*.md" -type f 2>/dev/null)
    
    if [ -z "$theme_log_files" ]; then
        debug_log "THEME_LOG: No theme log files found in theme_histories/ directory"
        echo "0"
        return 0
    fi
    
    # 最新タイムスタンプを取得
    local latest_timestamp=$(echo "$theme_log_files" | \
        sed 's|.*/||' | \
        grep -o '^[0-9]\{14\}' | \
        sort -r | \
        head -1)
    
    if [ -z "$latest_timestamp" ]; then
        debug_log "THEME_LOG: No valid timestamp found in theme log files"
        echo "0"
        return 0
    fi
    
    debug_log "THEME_LOG: Latest timestamp = $latest_timestamp"
    
    # 同じタイムスタンプのテーマログファイル数をカウント
    local same_timestamp_count=$(find "$artifacts_dir/theme_histories" -name "${latest_timestamp}_*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    debug_log "THEME_LOG: Same timestamp file count = $same_timestamp_count"
    
    # 同じタイムスタンプで2つ以上のファイルがある場合は重複作成異常
    # 通常は1つのタイムスタンプで1つのテーマログ（start または end）のみ
    if [ $same_timestamp_count -ge 2 ]; then
        debug_warning "THEME_LOG: Duplicate creation detected ($same_timestamp_count files >= 2)"
        echo "$same_timestamp_count"
        return 2
    fi
    
    debug_log "THEME_LOG: Normal operation ($same_timestamp_count file)"
    echo "$same_timestamp_count"
    return 0
}

# 最新思考ログファイル情報を取得するヘルパー関数
_get_latest_thinking_log_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find artifacts -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find artifacts -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -n 1
    fi
}

# 思考ログ作成頻度異常の判定（新機能 - v2）
# 思考ログファイルの最新更新時刻をチェックして頻度異常を検知
# 引数: current_time, warning_threshold, stop_threshold, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:diff=正常, 1:diff=警告, 2:diff=エラー）
check_thinking_log_frequency_anomaly() {
    local current_time="$1"
    local warning_threshold="$2"
    local stop_threshold="$3"
    local heartbeat_start_time="$4"
    
    debug_log "THINKING_LOG_FREQUENCY check started: current_time=$current_time"
    debug_log "THINKING_LOG_FREQUENCY thresholds: warning=${warning_threshold}s, stop=${stop_threshold}s"
    
    # 最新思考ログファイル情報を取得
    local latest_thinking_log_info=$(_get_latest_thinking_log_info)
    
    # check_inactivity_anomalyと同じスコープでdiff変数を宣言
    local diff
    
    # 思考ログファイルが存在しない場合の処理
    if [ -z "$latest_thinking_log_info" ]; then
        debug_log "THINKING_LOG_FREQUENCY: No thinking log files found, using heartbeat start time"
        diff=$((current_time - heartbeat_start_time))
    else
        # 最新思考ログの時刻を取得
        local latest_thinking_log_time=$(echo "$latest_thinking_log_info" | cut -d' ' -f1)
        local latest_thinking_log_file=$(echo "$latest_thinking_log_info" | cut -d' ' -f2-)
        
        debug_log "THINKING_LOG_FREQUENCY: Latest thinking log: $(basename "$latest_thinking_log_file") at $latest_thinking_log_time"
        
        # 既存のcheck_inactivity_anomalyと同じロジックを適用
        if [ $latest_thinking_log_time -lt $heartbeat_start_time ]; then
            diff=$((current_time - heartbeat_start_time))
            debug_log "THINKING_LOG_FREQUENCY: Using heartbeat start time as baseline (thinking log older than heartbeat start)"
        else
            diff=$((current_time - latest_thinking_log_time))
            debug_log "THINKING_LOG_FREQUENCY: Using thinking log time as baseline"
        fi
    fi
    
    debug_log "THINKING_LOG_FREQUENCY: Time difference = ${diff}s"
    
    # エラーコード付きで出力（誤使用防止のためreturnは常に0）
    if [ $diff -gt $stop_threshold ]; then
        debug_warning "THINKING_LOG_FREQUENCY: Error level reached (${diff}s > ${stop_threshold}s)"
        echo "2:$diff"
        return 0
    elif [ $diff -gt $warning_threshold ]; then
        debug_log "THINKING_LOG_FREQUENCY: Warning level reached (${diff}s > ${warning_threshold}s)"
        echo "1:$diff"
        return 0
    fi
    
    debug_log "THINKING_LOG_FREQUENCY: Normal operation (${diff}s <= ${warning_threshold}s)"
    echo "0:$diff"
    return 0
}

# 思考ログパターン異常の判定（新機能 - v2）
# 最新思考ログと同じタイムスタンプの思考ログファイル数をチェックして重複作成異常を検知
# 引数: current_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:count=正常, 1:count=警告, 2:count=エラー）
check_thinking_log_pattern_anomaly() {
    local current_time="$1"
    
    debug_log "THINKING_LOG_PATTERN check started: current_time=$current_time"
    
    # 最新思考ログファイル情報を取得
    local latest_thinking_log_info=$(_get_latest_thinking_log_info)
    
    if [ -z "$latest_thinking_log_info" ]; then
        debug_log "THINKING_LOG_PATTERN: No thinking log files found"
        echo "0:0"
        return 0
    fi
    
    # 最新思考ログのファイル名からタイムスタンプを抽出
    local latest_thinking_log_file=$(echo "$latest_thinking_log_info" | cut -d' ' -f2-)
    local latest_filename=$(basename "$latest_thinking_log_file")
    
    # ファイル名からタイムスタンプ部分を抽出（YYYYMMDDHHMMSS）
    local timestamp_pattern=""
    if [[ "$latest_filename" =~ ^([0-9]{14}) ]]; then
        timestamp_pattern="${BASH_REMATCH[1]}"
    else
        debug_log "THINKING_LOG_PATTERN: Could not extract timestamp from filename: $latest_filename"
        echo "0:1"
        return 0
    fi
    
    debug_log "THINKING_LOG_PATTERN: Latest thinking log timestamp: $timestamp_pattern"
    
    # 同じタイムスタンプの思考ログファイル数を取得
    local same_timestamp_count=$(find artifacts -path "*/histories/*.md" -name "${timestamp_pattern}*.md" -type f 2>/dev/null | wc -l)
    
    debug_log "THINKING_LOG_PATTERN: Same timestamp file count: $same_timestamp_count"
    
    # パターン異常の判定
    if [ $same_timestamp_count -ge 3 ]; then
        debug_warning "THINKING_LOG_PATTERN: Error level reached ($same_timestamp_count files with same timestamp)"
        echo "2:$same_timestamp_count"
        return 0
    elif [ $same_timestamp_count -ge 2 ]; then
        debug_log "THINKING_LOG_PATTERN: Warning level reached ($same_timestamp_count files with same timestamp)"
        echo "1:$same_timestamp_count"
        return 0
    fi
    
    debug_log "THINKING_LOG_PATTERN: Normal operation ($same_timestamp_count file with timestamp)"
    echo "0:$same_timestamp_count"
    return 0
}

# 最新テーマログファイル情報を取得するヘルパー関数
_get_latest_theme_log_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find artifacts/theme_histories -name "*.md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find artifacts/theme_histories -name "*.md" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -n 1
    fi
}

# テーマログパターン異常の判定（新機能 - v2）
# 最新テーマログと同じタイムスタンプのテーマログファイル数をチェックして重複作成異常を検知
# 引数: current_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:count=正常, 1:count=警告, 2:count=エラー）
check_theme_log_pattern_anomaly() {
    local current_time="$1"
    
    debug_log "THEME_LOG_PATTERN check started: current_time=$current_time"
    
    # 最新テーマログファイル情報を取得
    local latest_theme_log_info=$(_get_latest_theme_log_info)
    
    if [ -z "$latest_theme_log_info" ]; then
        debug_log "THEME_LOG_PATTERN: No theme log files found"
        echo "0:0"
        return 0
    fi
    
    # 最新テーマログのファイル名からタイムスタンプを抽出
    local latest_theme_log_file=$(echo "$latest_theme_log_info" | cut -d' ' -f2-)
    local latest_filename=$(basename "$latest_theme_log_file")
    
    # ファイル名からタイムスタンプ部分を抽出（YYYYMMDDHHMMSS）
    local timestamp_pattern=""
    if [[ "$latest_filename" =~ ^([0-9]{14}) ]]; then
        timestamp_pattern="${BASH_REMATCH[1]}"
    else
        debug_log "THEME_LOG_PATTERN: Could not extract timestamp from filename: $latest_filename"
        echo "0:1"
        return 0
    fi
    
    debug_log "THEME_LOG_PATTERN: Latest theme log timestamp: $timestamp_pattern"
    
    # 同じタイムスタンプのテーマログファイル数を取得
    local same_timestamp_count=$(find artifacts/theme_histories -name "${timestamp_pattern}*.md" -type f 2>/dev/null | wc -l)
    
    debug_log "THEME_LOG_PATTERN: Same timestamp file count: $same_timestamp_count"
    
    # パターン異常の判定
    if [ $same_timestamp_count -ge 3 ]; then
        debug_warning "THEME_LOG_PATTERN: Error level reached ($same_timestamp_count files with same timestamp)"
        echo "2:$same_timestamp_count"
        return 0
    elif [ $same_timestamp_count -ge 2 ]; then
        debug_log "THEME_LOG_PATTERN: Warning level reached ($same_timestamp_count files with same timestamp)"
        echo "1:$same_timestamp_count"
        return 0
    fi
    
    debug_log "THEME_LOG_PATTERN: Normal operation ($same_timestamp_count file with timestamp)"
    echo "0:$same_timestamp_count"
    return 0
}

# 思考ログループ状態管理用のグローバル変数
THINKING_LOG_LOOP_LAST_FILE=""
THINKING_LOG_LOOP_LAST_MTIME=""
THINKING_LOG_LOOP_COUNT=0

# 思考ログループ異常の判定（新機能 - v2）
# 同一思考ログファイルの継続編集を検知してループ異常を判定
# 引数: current_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:count=正常, 2:count=エラー）
check_thinking_log_loop_anomaly() {
    local current_time="$1"
    
    debug_log "THINKING_LOG_LOOP check started: current_time=$current_time"
    debug_log "THINKING_LOG_LOOP previous state: file=$THINKING_LOG_LOOP_LAST_FILE, mtime=$THINKING_LOG_LOOP_LAST_MTIME, count=$THINKING_LOG_LOOP_COUNT"
    
    # 最新思考ログファイル情報を取得
    local latest_thinking_log_info=$(_get_latest_thinking_log_info)
    
    if [ -z "$latest_thinking_log_info" ]; then
        debug_log "THINKING_LOG_LOOP: No thinking log files found, clearing loop state"
        THINKING_LOG_LOOP_LAST_FILE=""
        THINKING_LOG_LOOP_LAST_MTIME=""
        THINKING_LOG_LOOP_COUNT=0
        echo "0:0"
        return 0
    fi
    
    # 最新思考ログの時刻とファイル名を分離
    local latest_thinking_log_mtime=$(echo "$latest_thinking_log_info" | cut -d' ' -f1)
    local latest_thinking_log_file=$(echo "$latest_thinking_log_info" | cut -d' ' -f2-)
    
    debug_log "THINKING_LOG_LOOP: Current latest file: $latest_thinking_log_file (mtime: $latest_thinking_log_mtime)"
    
    # 前回と同じファイルかチェック
    if [ "$latest_thinking_log_file" = "$THINKING_LOG_LOOP_LAST_FILE" ]; then
        # 同じファイルの場合、更新時刻が変わったかチェック
        if [ "$latest_thinking_log_mtime" != "$THINKING_LOG_LOOP_LAST_MTIME" ]; then
            # 更新時刻が変わった場合、ループカウントをインクリメント
            THINKING_LOG_LOOP_COUNT=$((THINKING_LOG_LOOP_COUNT + 1))
            debug_log "THINKING_LOG_LOOP: Same file updated, loop count incremented to $THINKING_LOG_LOOP_COUNT"
            
            # 更新時刻を保存
            THINKING_LOG_LOOP_LAST_MTIME="$latest_thinking_log_mtime"
            
            # ループカウントが2以上でエラー
            if [ $THINKING_LOG_LOOP_COUNT -ge 2 ]; then
                debug_warning "THINKING_LOG_LOOP: Error level reached (loop count: $THINKING_LOG_LOOP_COUNT)"
                echo "2:$THINKING_LOG_LOOP_COUNT"
                return 0
            fi
        else
            # 更新時刻が同じ場合は何もしない
            debug_log "THINKING_LOG_LOOP: Same file, same mtime, no change"
        fi
    else
        # 異なるファイルの場合、ループ状態をクリア
        debug_log "THINKING_LOG_LOOP: Different file detected, clearing loop state"
        THINKING_LOG_LOOP_LAST_FILE="$latest_thinking_log_file"
        THINKING_LOG_LOOP_LAST_MTIME="$latest_thinking_log_mtime"
        THINKING_LOG_LOOP_COUNT=0
    fi
    
    debug_log "THINKING_LOG_LOOP: Updated state: file=$THINKING_LOG_LOOP_LAST_FILE, mtime=$THINKING_LOG_LOOP_LAST_MTIME, count=$THINKING_LOG_LOOP_COUNT"
    debug_log "THINKING_LOG_LOOP: Normal operation (loop count: $THINKING_LOG_LOOP_COUNT)"
    echo "0:$THINKING_LOG_LOOP_COUNT"
    return 0
}

# タイムスタンプをUnix秒に変換するヘルパー関数
convert_timestamp_to_seconds() {
    local timestamp="$1"
    if [[ "$timestamp" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        local hour="${BASH_REMATCH[4]}"
        local minute="${BASH_REMATCH[5]}"
        local second="${BASH_REMATCH[6]}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            date -j -f "%Y%m%d%H%M%S" "$timestamp" "+%s" 2>/dev/null
        else
            # Linux
            date -d "${year}-${month}-${day} ${hour}:${minute}:${second}" "+%s" 2>/dev/null
        fi
    fi
}

# 内省活動異常の判定（新機能 - v2）
# 内省ファイルの最新更新時刻をチェックして内省活動不足を検知
# 引数: current_time, introspection_threshold, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:diff=正常, 1:diff=警告, 2:diff=エラー）
check_introspection_activity_anomaly() {
    local current_time="$1"
    local introspection_threshold="$2"
    local heartbeat_start_time="$3"
    
    debug_log "INTROSPECTION_ACTIVITY check started: current_time=$current_time"
    debug_log "INTROSPECTION_ACTIVITY threshold: ${introspection_threshold}s"
    
    # 内省ファイルを検索（*introspection*パターン）
    local latest_introspection_file=$(find artifacts -name "*introspection*" -type f 2>/dev/null | head -1)
    
    local introspection_diff
    
    if [ -z "$latest_introspection_file" ]; then
        # 内省ファイルが見つからない場合、ハートビート開始からの経過時間で判定
        introspection_diff=$((current_time - heartbeat_start_time))
        debug_log "INTROSPECTION_ACTIVITY: No introspection files found, using heartbeat start time (${introspection_diff}s elapsed)"
    else
        # 最新内省ファイルのファイル名からタイムスタンプを抽出
        local latest_filename=$(basename "$latest_introspection_file")
        local timestamp_pattern=""
        
        if [[ "$latest_filename" =~ ([0-9]{14}) ]]; then
            timestamp_pattern="${BASH_REMATCH[1]}"
            debug_log "INTROSPECTION_ACTIVITY: Extracted timestamp: $timestamp_pattern from $latest_filename"
            
            # タイムスタンプを秒に変換
            local file_time=$(convert_timestamp_to_seconds "$timestamp_pattern")
            
            if [ -z "$file_time" ] || [ $file_time -lt $heartbeat_start_time ]; then
                # 変換失敗またはハートビート起動前の場合、起動時刻を基軸とする
                introspection_diff=$((current_time - heartbeat_start_time))
                debug_log "INTROSPECTION_ACTIVITY: Using heartbeat start time as baseline (conversion failed or file older)"
            else
                # 通常の判定（ハートビート起動後の内省活動）
                introspection_diff=$((current_time - file_time))
                debug_log "INTROSPECTION_ACTIVITY: Using file time as baseline"
            fi
        else
            # タイムスタンプ抽出失敗の場合、ハートビート開始時刻で判定
            introspection_diff=$((current_time - heartbeat_start_time))
            debug_log "INTROSPECTION_ACTIVITY: Could not extract timestamp from filename: $latest_filename"
        fi
    fi
    
    # 警告閾値（内省閾値の2/3）を設定
    local introspection_warning_threshold=$((introspection_threshold * 2 / 3))
    debug_log "INTROSPECTION_ACTIVITY: Time difference = ${introspection_diff}s, warning_threshold = ${introspection_warning_threshold}s"
    
    # エラーコード付きで出力（誤使用防止のためreturnは常に0）
    if [ $introspection_diff -gt $introspection_threshold ]; then
        debug_warning "INTROSPECTION_ACTIVITY: Error level reached (${introspection_diff}s > ${introspection_threshold}s)"
        echo "2:$introspection_diff"
        return 0
    elif [ $introspection_diff -gt $introspection_warning_threshold ]; then
        debug_log "INTROSPECTION_ACTIVITY: Warning level reached (${introspection_diff}s > ${introspection_warning_threshold}s)"
        echo "1:$introspection_diff"
        return 0
    fi
    
    debug_log "INTROSPECTION_ACTIVITY: Normal operation (${introspection_diff}s <= ${introspection_warning_threshold}s)"
    echo "0:$introspection_diff"
    return 0
}