#!/bin/bash

CONFIG_FILE="heartbeat.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # echoはlog_errorの前に必要
    echo -e "\033[1;31m[ERROR]\033[0m 設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# スクリプト開始時刻を記録
HEARTBEAT_START_TIME=$(date +%s)                                      # 秒形式（基準・時刻比較用）
HEARTBEAT_START_TIMESTAMP=$(date -r $HEARTBEAT_START_TIME "+%Y%m%d%H%M%S")  # 文字列形式（ログファイル名・チャットタグ用）

# statsディレクトリ作成
mkdir -p stats

# Web検索制限メッセージ用グローバル変数
WEB_RESTRICTION_MESSAGE=""

# 内省促進メッセージ用グローバル変数
INTROSPECTION_REMINDER_MESSAGE=""

# ループ検出用変数
LOOP_DETECTION_FILE=""
LOOP_DETECTION_START_TIME=""

# 回復処理用変数
RECOVERY_MESSAGE=""
RECOVERY_ATTEMPT_COUNT=0

# ヘルスチェック詳細情報用
HEALTH_CHECK_DETAIL=""

# 状態管理用変数
HEARTBEAT_STATE="normal"  # normal / recovery_waiting
RECOVERY_WAIT_CYCLES=0

# 終了フラグ
SHUTDOWN_REQUESTED=false

# ログファイル設定
LOG_DIR="logs"
# ログファイル名は起動時のタイムスタンプ付き（例: heartbeat_20250106143022.log）
LOG_FILE="$LOG_DIR/heartbeat_${HEARTBEAT_START_TIMESTAMP}.log"

# 古いログファイルのクリーンアップ関数
cleanup_old_logs() {
    if [ -d "$LOG_DIR" ]; then
        # 30日以上古いheartbeatログファイルを削除
        find "$LOG_DIR" -name "heartbeat_*.log" -type f -mtime +$MAX_LOG_DAYS -delete 2>/dev/null
    fi
}

# ログ初期化
setup_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    cleanup_old_logs
}

# 色付きログ関数（ファイル出力機能付き）
log_warning() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;33m[WARNING]\033[0m $message"
    echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;31m[ERROR]\033[0m $message"
    echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
}

log_info() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\033[1;32m[INFO]\033[0m $message"
    echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
}

log_heartbeat() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "Sending heartbeat at $(date "+%F %T")"
    echo "[$timestamp] [HEARTBEAT] $message" >> "$LOG_FILE"
}

# ログ初期化
setup_logging

# スクリプト開始時刻を記録
log_info "Heartbeat started at $(date "+%F %T") (PID: $$)"
log_info "Log file: $LOG_FILE"

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

# 内省活動をチェックする関数
_check_introspection_activity() {
    local current_time=$(date +%s)
    
    # 内省を含むファイルから最新のタイムスタンプを取得
    local latest_timestamp=$(grep -ril "内省" artifacts/*/histories/* 2>/dev/null | \
        sed 's|.*/||' | \
        grep -o '^[0-9]\{14\}' | \
        sort -r | \
        head -1)
    
    # 内省活動が見つからない場合は初回起動とみなして正常とする
    if [ -z "$latest_timestamp" ]; then
        return 0
    fi
    
    # タイムスタンプを秒に変換（1回のみ）
    local file_time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        file_time=$(date -j -f "%Y%m%d%H%M%S" "$latest_timestamp" "+%s" 2>/dev/null)
    else
        # Linux
        file_time=$(date -d "${latest_timestamp:0:8} ${latest_timestamp:8:2}:${latest_timestamp:10:2}:${latest_timestamp:12:2}" "+%s" 2>/dev/null)
    fi
    
    if [ -z "$file_time" ]; then
        return 0  # タイムスタンプ変換失敗時は正常とみなす
    fi
    
    # 内省活動チェック
    local introspection_diff=$((current_time - file_time))
    echo "Last introspection: $((introspection_diff / 60)) minutes ago"
    
    # 警告閾値（内省閾値の2/3）を設定
    local introspection_warning_threshold=$((INTROSPECTION_THRESHOLD * 2 / 3))
    
    if [ $introspection_diff -gt $INTROSPECTION_THRESHOLD ]; then
        HEALTH_CHECK_DETAIL=$introspection_diff
        return 1  # 内省活動不足（エラーレベル）
    elif [ $introspection_diff -gt $introspection_warning_threshold ]; then
        HEALTH_CHECK_DETAIL=$introspection_diff
        return 2  # 内省活動警告（警告レベル）
    fi
    
    return 0  # 正常
}

# 監視対象ディレクトリから最新ファイルの情報を取得する内部関数
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
        latest_info=$(find "${existing_dirs[@]}" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -nr | head -1)
    else
        # Linux
        latest_info=$(find "${existing_dirs[@]}" -type f -exec stat -c "%Y %n" {} \; 2>/dev/null | sort -nr | head -1)
    fi

    echo "$latest_info"
    [ -n "$latest_info" ]
}

# エージェントの健全性をチェックするコア関数
# 戻り値: 0=正常, 1=無活動警告, 2=内省警告, 3=無活動, 4=ループ, 5=タイムスタンプ異常, 6=内省不足
check_agent_health() {
    local latest_file_info=$(_get_latest_file_info)
    [ $? -ne 0 ] || [ -z "$latest_file_info" ] && return 0 # 監視対象がない/ファイルがない場合は正常とみなす

    local latest_time=$(echo "$latest_file_info" | cut -d' ' -f1)
    local latest_filename=$(echo "$latest_file_info" | cut -d' ' -f2-)
    current_time=$(date +%s)
    
    # スクリプト開始時刻より前のファイルの場合、開始時刻からの経過時間で判定
    local diff
    if [ $latest_time -lt $HEARTBEAT_START_TIME ]; then
        log_info "Latest file is older than heartbeat start time - checking from heartbeat start"
        diff=$((current_time - HEARTBEAT_START_TIME))
        echo "Time since heartbeat start: $((diff / 60)) minutes"
    else
        diff=$((current_time - latest_time))
    fi

    # 1. 無活動検知
    if [ "$diff" -gt "$INACTIVITY_STOP_THRESHOLD" ]; then
        HEALTH_CHECK_DETAIL=$diff
        return 3 # 無活動検知
    elif [ "$diff" -gt "$INACTIVITY_WARNING_THRESHOLD" ]; then
        HEALTH_CHECK_DETAIL=$diff
        return 1 # 警告レベル
    fi

    # 2. 同一ファイルループ検知
    if [ "$latest_filename" = "$LOOP_DETECTION_FILE" ]; then
        if [ ! -z "$LOOP_DETECTION_START_TIME" ]; then
            local loop_duration=$((current_time - LOOP_DETECTION_START_TIME))
            if [ "$loop_duration" -gt "$INACTIVITY_STOP_THRESHOLD" ]; then
                HEALTH_CHECK_DETAIL=$loop_duration
                return 4 # ループ検知
            fi
        fi
    else
        # 異なるファイルなのでループ検出記録をリセット
        LOOP_DETECTION_FILE="$latest_filename"
        LOOP_DETECTION_START_TIME="$current_time"
        echo "Loop detection reset for new file: $latest_filename"
    fi

    # 3. ファイル名タイムスタンプチェック
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
                        : # no-op
                    elif [ $timestamp_diff -gt $INACTIVITY_STOP_THRESHOLD ]; then
                        HEALTH_CHECK_DETAIL=$timestamp_diff
                        return 5 # タイムスタンプ異常
                    fi
                fi
            fi
        fi
    else
        echo "Skipping file timestamp check - latest file is older than heartbeat start"
    fi
    
    # 4. 内省活動不足検知
    _check_introspection_activity
    introspection_status=$?
    if [ $introspection_status -eq 1 ]; then
        return 6 # 内省不足 (HEALTH_CHECK_DETAIL is set by _check_introspection_activity)
    elif [ $introspection_status -eq 2 ]; then
        return 2 # 内省警告
    fi

    return 0  # 正常
}

# check_agent_healthの結果に基づき、ログ出力や回復処理を行う関数
check_recent_activity() {
    check_agent_health
    local status=$?
    local detail=$HEALTH_CHECK_DETAIL # 詳細情報をローカル変数にキャプチャ
    local latest_file_info=$(_get_latest_file_info) # for logging
    local latest_filename=$(echo "$latest_file_info" | cut -d' ' -f2-)

    # 異常検知時の共通処理
    handle_failure() {
        local error_message="$1"
        local error_code="$2"
        if [ $RECOVERY_ATTEMPT_COUNT -lt $MAX_RECOVERY_ATTEMPTS ]; then
            log_warning "$error_message"
            attempt_recovery "$error_code"
        else
            log_error "$error_message"
            log_error "Maximum recovery attempts exceeded. Stopping heartbeat..."
            stop_heartbeat
        fi
    }

    case $status in
        0) # 正常
            return 0 ;;
        1) # 無活動警告
            log_warning "Agent activity is low. No file updates for $((detail / 60)) minutes."
            return 0 ;;
        2) # 内省警告
            log_warning "Introspection activity has not been performed for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="最近内省活動が行われていないようです。可能であればこれまでの振り返りを行い、内省してみてください。"
            return 0 ;;
        3) 
            handle_failure "Agent appears to be stuck! No file updates for $((detail / 60)) minutes." "無活動状態" ;;
        4) 
            handle_failure "Agent appears to be stuck! Same file updated continuously for $((detail / 60)) minutes: $latest_filename" "同一ファイル継続更新ループ" ;;
        5) 
            handle_failure "Agent appears to be stuck! File timestamp is too old ($((detail / 60)) minutes): $latest_filename" "最新ファイル名タイムスタンプ異常" ;;
        6) 
            handle_failure "Agent appears to be stuck! No introspection activity for $((detail / 60)) minutes." "内省活動不足" ;;
        *) # 未知のエラー
            log_error "Unknown health check status: $status" ;;
    esac

    return $status # Propagate failure status
}

# 回復処理
attempt_recovery() {
    local detection_type=$1
    RECOVERY_ATTEMPT_COUNT=$((RECOVERY_ATTEMPT_COUNT + 1))
    
    log_warning "Abnormal activity detected: $detection_type (attempt $RECOVERY_ATTEMPT_COUNT/$MAX_RECOVERY_ATTEMPTS)"
    
    # エージェント処理を中断
    log_info "Interrupting agent process..."
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    sleep 1
    log_info "Agent processing has been interrupted."


    # コンテキスト圧縮を実行
    log_info "Sending context compression command..."
    tmux send-keys -t agent "/compress"
    sleep 1
    tmux send-keys -t agent C-m
    sleep 5  # 圧縮処理の完了を待機
    log_info "Context compression completed."
    
    # チャット保存を実行
    local save_timestamp=$(date "+%Y%m%d%H%M%S")
    local chat_tag="HEARTBEAT_${HEARTBEAT_START_TIMESTAMP}_${save_timestamp}"
    log_info "Saving chat with tag: $chat_tag"
    tmux send-keys -t agent "/chat save $chat_tag"
    sleep 1
    tmux send-keys -t agent C-m
    sleep 5  # チャット保存処理の完了を待機
    log_info "Chat saved with tag: $chat_tag"
    
    # 回復メッセージを設定し、回復待機状態に移行
    RECOVERY_MESSAGE="異常検知による回復処理: ${detection_type}を検知したため中断処理を行いました。
コンテキストを圧縮してクリアな状態にリセットしました。
チャット履歴をタグ「${chat_tag}」で保存しました。

以下のドキュメントからシステム仕様を再ロードし、**あなた自身の動作ルールを再設定してください**：
1. GEMINI.md - AI心臓システムでの基本的な動作ルール
2. ai-docs/OPERATION_DETAILS.md - 運用詳細ガイド（思考ログ記録、ファイル操作等）
3. ai-docs/TROUBLESHOOTING_GUIDE.md - 異常状況への対処方法
4. ai-docs/GUIDELINES.md - 運用ガイドライン

システム仕様の再ロード完了後、適切な内省活動を行い、正常な処理を再開してください。
また、異常検知に長期の活動による影響が考えられる場合、新規テーマ移行(自己を見直すテーマなど)を検討してみてもいいかもしれません。"
    HEARTBEAT_STATE="recovery_waiting"
    RECOVERY_WAIT_CYCLES=0
    
    log_info "Context compression and recovery message prepared, entering recovery waiting state."
}

# 回復状況確認
check_recovery_status() {
    log_info "Checking agent health for recovery confirmation..."
    check_agent_health
    local status=$?
    if [ $status -eq 0 ]; then
        log_info "Agent health check passed. Recovery confirmed."
        return 0 # 回復成功
    else
        log_warning "Agent health check failed with status $status. Recovery not yet confirmed."
        return 1 # 回復失敗
    fi
}

# 停止処理
stop_heartbeat() {
    log_error "Maximum recovery attempts ($MAX_RECOVERY_ATTEMPTS) exceeded or critical error detected"
    log_info "Heartbeat stopping at $(date "+%F %T")"

    # 最終的なエージェント処理中断
    log_info "Final agent process interruption..."
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    log_info "Agent processing has been interrupted."
        
    exit 0
}

# シグナルを捕捉して安全に終了するための関数
handle_shutdown() {
    log_warning "Shutdown signal received. Finishing current cycle and exiting gracefully..."
    SHUTDOWN_REQUESTED=true
}

# SIGINT (Ctrl-C) と SIGTERM を捕捉
trap handle_shutdown SIGINT SIGTERM

# 終了処理
graceful_shutdown() {
    log_info "Heartbeat stopped gracefully at $(date "+%F %T")"
    exit 0
}

log_info "Heartbeat monitor started at $(date "+%F %T")"
log_info "Monitored directories: ${MONITORED_DIRS[*]}"
log_info "Warning threshold: $((INACTIVITY_WARNING_THRESHOLD / 60)) minutes"
log_info "Stop threshold: $((INACTIVITY_STOP_THRESHOLD / 60)) minutes"

while true; do
    if [ "$HEARTBEAT_STATE" = "recovery_waiting" ]; then
        # 終了リクエストがあれば、回復待機中でもループを抜ける
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            break
        fi

        # 回復待機状態：回復確認のみ実行
        echo "Recovery waiting state (cycle $((RECOVERY_WAIT_CYCLES + 1))/$MAX_RECOVERY_WAIT_CYCLES)"
        
        check_recovery_status
        if [ $? -eq 0 ]; then
            # 回復確認
            log_info "Agent recovery confirmed. Returning to normal state."
            HEARTBEAT_STATE="normal"
            RECOVERY_WAIT_CYCLES=0
            RECOVERY_ATTEMPT_COUNT=0  # 回復成功時に試行回数をリセット
        else
            # まだ回復していない
            RECOVERY_WAIT_CYCLES=$((RECOVERY_WAIT_CYCLES + 1))
            log_info "Recovery not yet confirmed. Waiting... ($RECOVERY_WAIT_CYCLES/$MAX_RECOVERY_WAIT_CYCLES)"
            
            if [ $RECOVERY_WAIT_CYCLES -ge $MAX_RECOVERY_WAIT_CYCLES ]; then
                # 回復待機タイムアウト
                if [ $RECOVERY_ATTEMPT_COUNT -lt $MAX_RECOVERY_ATTEMPTS ]; then
                    log_warning "Recovery wait timeout. Returning to normal state for next recovery attempt..."
                    # 状態をリセットして通常状態に戻す（次のサイクルで再度異常検知→回復試行される）
                    HEARTBEAT_STATE="normal"
                    RECOVERY_WAIT_CYCLES=0
                else
                    log_error "Recovery wait timeout and maximum attempts exceeded."
                    stop_heartbeat
                fi
            fi
        fi
        
        # 回復待機中はハートビート送信をスキップ
        if [ "$HEARTBEAT_STATE" = "recovery_waiting" ]; then
            # カウントダウンのみ実行
            for i in $(seq ${INTERVAL_SECONDS} -1 1); do
                printf "\r[RECOVERY WAIT] Next check in %2d seconds... " "$i"
                sleep 1
            done
            printf "\r                                           \r"
            continue
        fi
    fi
    
    # 通常状態：通常の活動チェックとハートビート送信
    if [ "$HEARTBEAT_STATE" = "normal" ]; then
        check_recent_activity
    fi
    
    # カウントダウン
    for i in $(seq ${INTERVAL_SECONDS} -1 1); do
        # 終了リクエストがあればカウントダウンを中断
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            break 2 # 外側のwhileループも抜ける
        fi

        # \r を使ってカーソルを行頭に戻し、同じ行に上書き表示する
        printf "\rNext heartbeat in %2d seconds... " "$i"
        sleep 1
    done
    # カウントダウン表示をクリア
    printf "\r                                   \r"

    # 終了リクエストがあればハートビートを送信せずにループを終了
    if [ "$SHUTDOWN_REQUESTED" = true ]; then
        break
    fi

    log_heartbeat "Heartbeat sent to agent session"
    
    # Web検索制限チェック
    check_web_search_restriction
    
    # ハートビートメッセージ作成
    heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
    
    # Web検索制限メッセージ追加
    if [ ! -z "$WEB_RESTRICTION_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$WEB_RESTRICTION_MESSAGE"
    fi
    
    # 内省促進メッセージ追加
    if [ ! -z "$INTROSPECTION_REMINDER_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$INTROSPECTION_REMINDER_MESSAGE"
        INTROSPECTION_REMINDER_MESSAGE=""  # 一度使ったらクリア
        log_info "Introspection reminder included in heartbeat"
    fi
    
    # 回復メッセージ追加
    if [ ! -z "$RECOVERY_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$RECOVERY_MESSAGE"
        RECOVERY_MESSAGE=""  # 一度使ったらクリア
        log_info "Recovery message included in heartbeat"
    fi
    
    tmux send-keys -t agent "$heartbeat_msg"
    sleep 1
    tmux send-keys -t agent C-m
done

# ループを抜けた後に最終処理を実行
graceful_shutdown
