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

# 最新の内省活動があった思考ログ情報を取得するヘルパー関数
_get_latest_introspection_info() {
    # "内省"という単語を含む思考ログファイルのリストを取得し、その中から最新のものを探す
    # `grep -l`でファイルリストを取得し、`xargs`で`stat`に渡す
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find artifacts -path "*/histories/*.md" -type f -exec grep -l "内省" {} + 2>/dev/null | xargs -I {} stat -f "%m %N" {} 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find artifacts -path "*/histories/*.md" -type f -exec grep -l "内省" {} + 2>/dev/null | xargs stat -c "%Y %n" 2>/dev/null | sort -nr | head -n 1
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
    
    # 最新の内省関連ファイル情報を取得
    local latest_introspection_info=$(_get_latest_introspection_info)
    
    local introspection_diff
    
    if [ -z "$latest_introspection_info" ]; then
        # 「内省」を含む思考ログが見つからない場合、ハートビート開始からの経過時間で判定
        introspection_diff=$((current_time - heartbeat_start_time))
        debug_log "INTROSPECTION_ACTIVITY: No thinking logs with '内省' found, using heartbeat start time (${introspection_diff}s elapsed)"
    else
        # 最新の内省活動があった思考ログの更新時刻を取得
        local latest_introspection_time=$(echo "$latest_introspection_info" | cut -d' ' -f1)
        local latest_introspection_file=$(echo "$latest_introspection_info" | cut -d' ' -f2-)

        debug_log "INTROSPECTION_ACTIVITY: Latest introspection in: $(basename "$latest_introspection_file") at $latest_introspection_time"

        if [ $latest_introspection_time -lt $heartbeat_start_time ]; then
            introspection_diff=$((current_time - heartbeat_start_time))
            debug_log "INTROSPECTION_ACTIVITY: Using heartbeat start time as baseline (introspection log older than heartbeat start)"
        else
            introspection_diff=$((current_time - latest_introspection_time))
            debug_log "INTROSPECTION_ACTIVITY: Using introspection log time as baseline"
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

# 思考ログタイムスタンプ乖離異常の判定（新機能 - v2復活）
# 最新思考ログのファイル名に含まれるタイムスタンプが現在時刻から乖離していないかチェック
# 引数: current_time, warning_threshold, error_threshold, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:diff=正常, 1:diff=警告, 2:diff=エラー）
check_thinking_log_timestamp_anomaly() {
    local current_time="$1"
    local warning_threshold="$2"
    local error_threshold="$3"
    local heartbeat_start_time="$4"

    debug_log "THINKING_LOG_TIMESTAMP check started: current_time=$current_time"
    debug_log "THINKING_LOG_TIMESTAMP thresholds: warning=${warning_threshold}s, error=${error_threshold}s"

    # 最新思考ログファイル情報を取得
    local latest_thinking_log_info=$(_get_latest_thinking_log_info)

    if [ -z "$latest_thinking_log_info" ]; then
        debug_log "THINKING_LOG_TIMESTAMP: No thinking log files found"
        echo "0:0"
        return 0
    fi

    # 最新思考ログのファイル名を取得
    local latest_thinking_log_file=$(echo "$latest_thinking_log_info" | cut -d' ' -f2-)
    local latest_filename=$(basename "$latest_thinking_log_file")

    # ファイル名からタイムスタンプ部分を抽出（YYYYMMDDHHMMSS）
    local timestamp_pattern=""
    if [[ "$latest_filename" =~ ^([0-9]{14}) ]]; then
        timestamp_pattern="${BASH_REMATCH[1]}"
    else
        debug_log "THINKING_LOG_TIMESTAMP: Could not extract timestamp from filename: $latest_filename"
        echo "0:0"
        return 0
    fi

    debug_log "THINKING_LOG_TIMESTAMP: Extracted timestamp = $timestamp_pattern"

    # タイムスタンプを秒に変換
    local file_time=$(convert_timestamp_to_seconds "$timestamp_pattern")
    if [ -z "$file_time" ]; then
        debug_log "THINKING_LOG_TIMESTAMP: Could not convert timestamp to seconds"
        echo "0:0"
        return 0
    fi

    # 現在時刻とファイル名タイムスタンプの差を計算
    local timestamp_diff
    if [ $file_time -lt $heartbeat_start_time ]; then
        # ファイル名タイムスタンプがハートビート起動前の場合、起動時刻を基軸とする
        timestamp_diff=$((current_time - heartbeat_start_time))
        debug_log "THINKING_LOG_TIMESTAMP: Using heartbeat start time as baseline (file timestamp older than heartbeat start)"
    else
        timestamp_diff=$((current_time - file_time))
    fi
    debug_log "THINKING_LOG_TIMESTAMP: Time difference = ${timestamp_diff}s"

    # 未来のタイムスタンプは異常としない
    if [ $timestamp_diff -lt 0 ]; then
        debug_log "THINKING_LOG_TIMESTAMP: Future timestamp detected, skipping"
        echo "0:$timestamp_diff"
        return 0
    fi

    # エラーコード付きで出力
    if [ $timestamp_diff -gt $error_threshold ]; then
        debug_warning "THINKING_LOG_TIMESTAMP: Error level reached (${timestamp_diff}s > ${error_threshold}s)"
        echo "2:$timestamp_diff"
        return 0
    elif [ $timestamp_diff -gt $warning_threshold ]; then
        debug_log "THINKING_LOG_TIMESTAMP: Warning level reached (${timestamp_diff}s > ${warning_threshold}s)"
        echo "1:$timestamp_diff"
        return 0
    fi

    debug_log "THINKING_LOG_TIMESTAMP: Normal operation (${timestamp_diff}s <= ${warning_threshold}s)"
    echo "0:$timestamp_diff"
    return 0
}