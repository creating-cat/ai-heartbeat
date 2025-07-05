#!/bin/bash

# ハートビートの間隔（秒）
INTERVAL_SECONDS=60 # 1分

# 無活動検知の閾値（秒）
INACTIVITY_WARNING_THRESHOLD=300  # 5分
INACTIVITY_STOP_THRESHOLD=600     # 10分

# Web検索制限時間（秒）
WEB_SEARCH_RESTRICTION_TIME=600   # 10分
WEB_SEARCH_QUOTA_RESTRICTION_TIME=3600  # 1時間（クォータ制限時）

# statsディレクトリ作成
mkdir -p stats

# Web検索制限メッセージ用グローバル変数
WEB_RESTRICTION_MESSAGE=""

# 色付きログ関数
log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

# スクリプト開始時刻を記録
HEARTBEAT_START_TIME=$(date +%s)
HEARTBEAT_START_TIME_FORMATTED=$(date -r $HEARTBEAT_START_TIME "+%F %T")
log_info "Heartbeat started at $HEARTBEAT_START_TIME_FORMATTED"

# Web検索制限チェック関数
check_web_search_restriction() {
    WEB_RESTRICTION_MESSAGE=""
    current_time=$(date +%s)
    
    # クォータ制限チェック（優先）
    if [ -f "stats/quota_exceeded.txt" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            quota_time=$(stat -f %m stats/quota_exceeded.txt)
        else
            # Linux
            quota_time=$(stat -c %Y stats/quota_exceeded.txt)
        fi
        
        diff=$((current_time - quota_time))
        
        if [ $diff -lt $WEB_SEARCH_QUOTA_RESTRICTION_TIME ]; then
            # クォータ制限時間未満：Web検索禁止
            WEB_RESTRICTION_MESSAGE="🚫 このハートビートでのWeb検索は使用禁止（クォータ制限のため長時間制限中）"
            return 1
        else
            # クォータ制限時間経過：制限解除、ファイル削除
            rm stats/quota_exceeded.txt
            log_info "Web search quota restriction lifted"
            return 0
        fi
    fi
    
    # 通常制限チェック
    if [ -f "stats/last_web_search.txt" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            last_search=$(stat -f %m stats/last_web_search.txt)
        else
            # Linux
            last_search=$(stat -c %Y stats/last_web_search.txt)
        fi
        
        diff=$((current_time - last_search))
        
        if [ $diff -lt $WEB_SEARCH_RESTRICTION_TIME ]; then
            # 制限時間未満：Web検索禁止
            WEB_RESTRICTION_MESSAGE="🚫 このハートビートでのWeb検索は使用禁止（クォータ制限回避のため）"
            return 1
        else
            # 制限時間経過：制限解除、ファイル削除
            rm stats/last_web_search.txt
            log_info "Web search restriction lifted"
            return 0
        fi
    fi
    return 0
}

# artifacts配下の最新ファイル更新時刻をチェックする関数
check_recent_activity() {
    if [ ! -d "artifacts" ]; then
        return 0  # artifacts がない場合は正常とみなす
    fi
    
    # 最新ファイルの更新時刻を取得（macOS対応）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        latest_file=$(find artifacts -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -nr | head -1)
    else
        # Linux
        latest_file=$(find artifacts -type f -exec stat -c "%Y %n" {} \; 2>/dev/null | sort -nr | head -1)
    fi
    
    if [ -z "$latest_file" ]; then
        return 0  # ファイルがない場合は正常とみなす
    fi
    
    latest_time=$(echo $latest_file | cut -d' ' -f1)
    latest_filename=$(echo $latest_file | cut -d' ' -f2-)
    current_time=$(date +%s)
    diff=$((current_time - latest_time))
    
    # デバッグ情報
    echo "DEBUG: Raw find output: $latest_file"
    echo "DEBUG: Extracted time: $latest_time"
    echo "DEBUG: Extracted filename: $latest_filename"
    echo "DEBUG: Current time: $current_time"
    echo "DEBUG: Heartbeat start time: $HEARTBEAT_START_TIME"
    echo "Latest file: $latest_filename ($(date -r $latest_time "+%F %T"))"
    echo "Inactivity duration: $((diff / 60)) minutes"
    echo "Heartbeat start time: $HEARTBEAT_START_TIME_FORMATTED"
    echo "DEBUG: Comparison: $latest_time < $HEARTBEAT_START_TIME = $([ $latest_time -lt $HEARTBEAT_START_TIME ] && echo "true" || echo "false")"
    
    # スクリプト開始時刻より前のファイルの場合、開始時刻からの経過時間で判定
    if [ $latest_time -lt $HEARTBEAT_START_TIME ]; then
        log_info "Latest file is older than heartbeat start time - checking from heartbeat start"
        diff=$((current_time - HEARTBEAT_START_TIME))
        echo "Time since heartbeat start: $((diff / 60)) minutes"
    fi
    
    # ファイル名タイムスタンプチェック（思考ログ・テーマログ）
    # ただし、開始時間より後に作成されたファイルがない場合はスキップ
    if [ $latest_time -ge $HEARTBEAT_START_TIME ]; then
        filename_only=$(basename "$latest_filename")
        if [[ "$filename_only" =~ ^[0-9]{14}(_[a-zA-Z]+_.*)?\.md$ ]]; then
            # ファイル名からタイムスタンプを抽出（最初の14桁）
            file_timestamp=$(echo "$filename_only" | grep -o '^[0-9]\{14\}')
            if [ ! -z "$file_timestamp" ]; then
                # タイムスタンプを秒に変換
                file_year=${file_timestamp:0:4}
                file_month=${file_timestamp:4:2}
                file_day=${file_timestamp:6:2}
                file_hour=${file_timestamp:8:2}
                file_minute=${file_timestamp:10:2}
                file_second=${file_timestamp:12:2}
                
                # dateコマンドで秒に変換
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    file_time=$(date -j -f "%Y%m%d%H%M%S" "$file_timestamp" "+%s" 2>/dev/null)
                else
                    # Linux
                    file_time=$(date -d "${file_year}-${file_month}-${file_day} ${file_hour}:${file_minute}:${file_second}" "+%s" 2>/dev/null)
                fi
                
                if [ ! -z "$file_time" ]; then
                    timestamp_diff=$((current_time - file_time))
                    echo "File timestamp: $(date -r $file_time "+%F %T")"
                    echo "Timestamp age: $((timestamp_diff / 60)) minutes"
                    
                    # 未来のタイムスタンプの場合はスキップ
                    if [ $timestamp_diff -lt 0 ]; then
                        log_warning "File has future timestamp - skipping timestamp check"
                    # ファイル名タイムスタンプが古すぎる場合は異常検知
                    elif [ $timestamp_diff -gt $INACTIVITY_STOP_THRESHOLD ]; then
                        log_error "Agent appears to be stuck! File timestamp is too old: $((timestamp_diff / 60)) minutes."
                        log_error "This suggests the agent is continuously updating the same old file."
                        log_error "Stopping heartbeat to prevent runaway behavior..."
                        return 2  # 停止レベル
                    fi
                fi
            fi
        fi
    else
        echo "Skipping file timestamp check - latest file is older than heartbeat start"
    fi
    
    # 警告レベルチェック（ファイル更新時刻ベース）
    if [ $diff -gt $INACTIVITY_STOP_THRESHOLD ]; then
        log_error "Agent appears to be stuck! No file updates for $((diff / 60)) minutes."
        log_error "Stopping heartbeat to prevent runaway behavior..."
        return 2  # 停止レベル
    elif [ $diff -gt $INACTIVITY_WARNING_THRESHOLD ]; then
        log_warning "Agent activity is low. No file updates for $((diff / 60)) minutes."
        return 1  # 警告レベル
    fi
    
    return 0  # 正常
}

# 停止処理
stop_heartbeat() {
    log_info "Heartbeat stopping at $(date "+%F %T")"
    log_info "Reason: Agent inactivity detected"

    # 暴走してるかもしれないエージェント処理をエスケープキーで中断させる
    # 念の為２回エスケープキーを送る
    log_info "The agent process will be interrupted...."
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    log_info "Agent processing has been interrupted."
        
    exit 0
}

log_info "Heartbeat monitor started at $(date "+%F %T")"
log_info "Warning threshold: $((INACTIVITY_WARNING_THRESHOLD / 60)) minutes"
log_info "Stop threshold: $((INACTIVITY_STOP_THRESHOLD / 60)) minutes"

while true; do
    # 活動チェック
    check_recent_activity
    activity_status=$?
    
    if [ $activity_status -eq 2 ]; then
        # 停止レベル
        stop_heartbeat
    fi
    
    # カウントダウン
    for i in $(seq ${INTERVAL_SECONDS} -1 1); do
        # \r を使ってカーソルを行頭に戻し、同じ行に上書き表示する
        printf "\rNext heartbeat in %2d seconds... " "$i"
        sleep 1
    done
    # カウントダウン表示をクリア
    printf "\r                                   \r"

    echo "Sending heartbeat at $(date "+%F %T")"
    
    # Web検索制限チェック
    check_web_search_restriction
    
    # ハートビートメッセージ作成
    heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
    if [ ! -z "$WEB_RESTRICTION_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$WEB_RESTRICTION_MESSAGE"
    fi
    
    tmux send-keys -t agent "$heartbeat_msg"
    sleep 1
    tmux send-keys -t agent C-m
done
