#!/bin/bash

# ハートビートの間隔（秒）
INTERVAL_SECONDS=60

# 無活動検知の閾値（秒）
INACTIVITY_WARNING_THRESHOLD=300  # 5分
INACTIVITY_STOP_THRESHOLD=600     # 10分

# Web検索制限時間（秒）
WEB_SEARCH_RESTRICTION_TIME=600   # 10分

# statsディレクトリ作成
mkdir -p stats

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

# Web検索制限チェック関数
check_web_search_restriction() {
    if [ -f "stats/last_web_search.txt" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            last_search=$(stat -f %m stats/last_web_search.txt)
        else
            # Linux
            last_search=$(stat -c %Y stats/last_web_search.txt)
        fi
        
        current_time=$(date +%s)
        diff=$((current_time - last_search))
        
        if [ $diff -lt $WEB_SEARCH_RESTRICTION_TIME ]; then
            # 制限時間未満：Web検索禁止
            remaining_minutes=$(((WEB_SEARCH_RESTRICTION_TIME - diff + 59) / 60))  # 切り上げ
            echo "🚫 Web検索は現在制限中（あと約${remaining_minutes}分待機）"
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
    echo "Latest file: $latest_filename ($(date -r $latest_time "+%F %T"))"
    echo "Inactivity duration: $((diff / 60)) minutes"
    
    # 警告レベルチェック
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
    web_restriction_msg=$(check_web_search_restriction)
    
    # ハートビートメッセージ作成
    heartbeat_msg="Heartbeat: $(date "+%F %T")"
    if [ ! -z "$web_restriction_msg" ]; then
        heartbeat_msg="$heartbeat_msg

$web_restriction_msg"
    fi
    
    tmux send-keys -t agent "$heartbeat_msg"
    sleep 1
    tmux send-keys -t agent C-m
done