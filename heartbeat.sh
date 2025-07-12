#!/bin/bash

# ライブラリの読み込み
source "lib/logging.sh"
source "lib/config.sh"
source "lib/utils.sh"
source "lib/health_check_core.sh"
source "lib/agent_io.sh"

# 設定ファイル読み込み
CONFIG_FILE="heartbeat.conf"
load_config "$CONFIG_FILE" || exit 1

# スクリプト開始時刻を記録
HEARTBEAT_START_TIME=$(date +%s)                                      # 秒形式（基準・時刻比較用）
HEARTBEAT_START_TIMESTAMP=$(date -r $HEARTBEAT_START_TIME "+%Y%m%d%H%M%S")  # 文字列形式（ログファイル名・チャットタグ用）

# statsディレクトリ作成
mkdir -p stats

# Web検索制限メッセージ用グローバル変数
WEB_RESTRICTION_MESSAGE=""

# 内省促進メッセージ用グローバル変数
INTROSPECTION_REMINDER_MESSAGE=""

# 無活動警告メッセージ用グローバル変数
INACTIVITY_WARNING_MESSAGE=""

# フィードバック通知メッセージ用グローバル変数
FEEDBACK_NOTIFICATION_MESSAGE=""

# 緊急フィードバックフラグ用グローバル変数
EMERGENCY_FEEDBACK_DETECTED=false

# デバッグモード設定（環境変数で制御）
DEBUG_MODE=${DEBUG_MODE:-false}

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

# 割り込み可能なスリープ関数
# 引数1: 待機する秒数
# 引数2: (オプション) カウントダウン中に表示するメッセージフォーマット（例: "Next check in %2d seconds..."）
interruptible_sleep() {
    local duration=$1
    local message_format=${2:-""} # Default to empty string if not provided

    for ((i=duration; i>0; i--)); do
        # 1秒ごとにシャットダウン要求を確認
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            log_notice "Shutdown requested, interrupting sleep."
            # メッセージ表示をクリア
            if [ -n "$message_format" ]; then
                printf "\r                                                               \r"
            fi
            # ループを抜けて即時に関数を終了
            return
        fi

        # メッセージが指定されていれば表示
        if [ -n "$message_format" ]; then
            printf "\r$message_format" "$i"
        fi

        sleep 1
    done

    # ループ正常終了後、メッセージ表示をクリア
    if [ -n "$message_format" ]; then
        printf "\r                                                               \r"
    fi
}

# ログファイル設定
LOG_DIR="logs"
# ログファイル名は起動時のタイムスタンプ付き（例: heartbeat_20250106143022.log）
LOG_FILE="$LOG_DIR/heartbeat_${HEARTBEAT_START_TIMESTAMP}.log"

# ログ初期化（lib/logging.shを使用）
init_logging "$LOG_DIR/heartbeat_${HEARTBEAT_START_TIMESTAMP}.log" "$LOG_DIR" "$DEBUG_MODE" "$MAX_LOG_DAYS"

# スクリプト開始時刻を記録
log_notice "Heartbeat started at $(date "+%F %T") (PID: $$)"
log_notice "Log file: $LOG_FILE"

# feedbackboxのチェック関数
check_feedbackbox() {
    FEEDBACK_NOTIFICATION_MESSAGE=""
    EMERGENCY_FEEDBACK_DETECTED=false  # フラグリセット
    
    # feedbackboxディレクトリが存在しない場合は作成
    if [ ! -d "feedbackbox" ]; then
        mkdir -p feedbackbox
        return 0
    fi
    
    # プレフィックスなしのmdファイル（処理対象のフィードバック）を検出
    local feedback_files=$(find feedbackbox -name "*.md" -not -name "draft.*" -not -name "processed.*" 2>/dev/null)
    local feedback_count=$(echo "$feedback_files" | grep -v "^$" | wc -l | tr -d ' ')
    
    if [ $feedback_count -gt 0 ]; then
        # 緊急フィードバックチェック
        local emergency_files=$(echo "$feedback_files" | grep "emergency\.")
        local emergency_count=$(echo "$emergency_files" | grep -v "^$" | wc -l | tr -d ' ')
        
        if [ $emergency_count -gt 0 ]; then
            EMERGENCY_FEEDBACK_DETECTED=true
            
            # 緊急フィードバックファイルのemergency.プレフィックスを削除
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local dir=$(dirname "$file")
                    local filename=$(basename "$file")
                    local new_filename=$(echo "$filename" | sed 's/^emergency\.//')
                    mv "$file" "$dir/$new_filename"
                    log_notice "Renamed emergency feedback: $filename -> $new_filename"
                fi
            done <<< "$emergency_files"
            
            FEEDBACK_NOTIFICATION_MESSAGE="📝 【緊急】feedbackboxに未処理のユーザーフィードバックが${feedback_count}件あります。内省時に確認・対応してください。"
            log_warning "Found $emergency_count emergency feedback files (total: $feedback_count)"
        else
            FEEDBACK_NOTIFICATION_MESSAGE="📝 feedbackboxに未処理のユーザーフィードバックが${feedback_count}件あります。内省時に確認・対応してください。"
            log_notice "Found $feedback_count unprocessed feedback files"
        fi
        return 1  # フィードバックあり
    fi
    
    return 0  # フィードバックなし
}

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

# エージェントの健全性をチェックするコア関数
# 戻り値: 0=正常, 1=警告レベル, 2=エラーレベル
# 新しいhealth_check_core.shを使用した統一処理
check_agent_health() {
    local current_time=$(date +%s)
    
    # 8. 思考ログ頻度異常検知（新機能 - v2）
    local thinking_freq_result=$(check_thinking_log_frequency_anomaly "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local thinking_freq_code=$(echo "$thinking_freq_result" | cut -d':' -f1)
    local thinking_freq_detail=$(echo "$thinking_freq_result" | cut -d':' -f2)
    
    if [ "$thinking_freq_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$thinking_freq_detail"
        if [ "$thinking_freq_code" = "1" ]; then
            log_warning "[CHECK] Thinking log frequency warning detected (code 10): $thinking_freq_detail seconds"
            return 10 # 思考ログ頻度警告
        elif [ "$thinking_freq_code" = "2" ]; then
            log_warning "[CHECK] Thinking log frequency error detected (code 11): $thinking_freq_detail seconds"
            return 11 # 思考ログ頻度エラー
        fi
    fi

    # 9. 思考ログパターン異常検知（新機能 - v2）
    local thinking_pattern_result=$(check_thinking_log_pattern_anomaly "$current_time")
    local thinking_pattern_code=$(echo "$thinking_pattern_result" | cut -d':' -f1)
    local thinking_pattern_detail=$(echo "$thinking_pattern_result" | cut -d':' -f2)
    
    if [ "$thinking_pattern_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$thinking_pattern_detail"
        if [ "$thinking_pattern_code" = "2" ]; then
            log_warning "[CHECK] Thinking log pattern error detected (code 13): $thinking_pattern_detail files"
            return 13 # 思考ログパターンエラー
        fi
    fi

    # 10. テーマログパターン異常検知（新機能 - v2）
    local theme_pattern_result=$(check_theme_log_pattern_anomaly "$current_time")
    local theme_pattern_code=$(echo "$theme_pattern_result" | cut -d':' -f1)
    local theme_pattern_detail=$(echo "$theme_pattern_result" | cut -d':' -f2)
    
    if [ "$theme_pattern_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$theme_pattern_detail"
        if [ "$theme_pattern_code" = "2" ]; then
            log_warning "[CHECK] Theme log pattern error detected (code 16): $theme_pattern_detail files"
            return 16 # テーマログパターンエラー
        fi
    fi

    # 11. 思考ログループ異常検知（新機能 - v2）
    local thinking_loop_result=$(check_thinking_log_loop_anomaly "$current_time")
    local thinking_loop_code=$(echo "$thinking_loop_result" | cut -d':' -f1)
    local thinking_loop_detail=$(echo "$thinking_loop_result" | cut -d':' -f2)
    
    if [ "$thinking_loop_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$thinking_loop_detail"
        if [ "$thinking_loop_code" = "2" ]; then
            log_warning "[CHECK] Thinking log loop error detected (code 14): $thinking_loop_detail loops"
            return 14 # 思考ログループエラー
        fi
    fi

    # 12. 内省活動異常検知（新機能 - v2）
    local introspection_result=$(check_introspection_activity_anomaly "$current_time" "$INTROSPECTION_THRESHOLD" "$HEARTBEAT_START_TIME")
    local introspection_code=$(echo "$introspection_result" | cut -d':' -f1)
    local introspection_detail=$(echo "$introspection_result" | cut -d':' -f2)
    
    if [ "$introspection_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$introspection_detail"
        if [ "$introspection_code" = "1" ]; then
            log_warning "[CHECK] Introspection activity warning detected (code 17): $introspection_detail seconds"
            return 17 # 内省活動警告
        elif [ "$introspection_code" = "2" ]; then
            log_warning "[CHECK] Introspection activity error detected (code 18): $introspection_detail seconds"
            return 18 # 内省活動エラー
        fi
    fi

    # 13. 思考ログタイムスタンプ乖離異常検知（新機能 - v2復活）
    local timestamp_result=$(check_thinking_log_timestamp_anomaly "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local timestamp_code=$(echo "$timestamp_result" | cut -d':' -f1)
    local timestamp_detail=$(echo "$timestamp_result" | cut -d':' -f2)

    if [ "$timestamp_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$timestamp_detail"
        if [ "$timestamp_code" = "1" ]; then
            log_warning "[CHECK] Thinking log timestamp warning detected (code 19): $timestamp_detail seconds"
            return 19 # 思考ログタイムスタンプ警告
        elif [ "$timestamp_code" = "2" ]; then
            log_warning "[CHECK] Thinking log timestamp error detected (code 20): $timestamp_detail seconds"
            return 20 # 思考ログタイムスタンプエラー
        fi
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
        10) # 思考ログ頻度警告（新機能 - v2）
            log_warning "Thinking log frequency warning: No thinking log updates for $((detail / 60)) minutes."
            INACTIVITY_WARNING_MESSAGE="⚠️ 思考ログ頻度警告: $((detail / 60))分間思考ログの更新がありません。

$ADVICE_THINKING_LOG_FREQUENCY"
            return 0 ;;
        11) # 思考ログ頻度エラー（新機能 - v2）
            handle_failure "Thinking log frequency error: No thinking log updates for $((detail / 60)) minutes." "思考ログ頻度異常" ;;
        13) # 思考ログパターンエラー（新機能 - v2）
            handle_failure "Thinking log pattern error: $detail files with same timestamp detected." "思考ログパターン異常" ;;
        14) # 思考ログループエラー（新機能 - v2）
            handle_failure "Thinking log loop error: Same thinking log edited $detail times consecutively." "思考ログループ異常" ;;
        16) # テーマログパターンエラー（新機能 - v2）
            handle_failure "Theme log pattern error: $detail files with same timestamp detected." "テーマログパターン異常" ;;
        17) # 内省活動警告（新機能 - v2）
            log_warning "Introspection activity warning: No introspection activity for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="⚠️ 内省不足警告: $((detail / 60))分間内省活動が行われていません。

$ADVICE_INTROSPECTION"
            return 0 ;;
        18) # 内省活動エラー（新機能 - v2）
            handle_failure "Introspection activity error: No introspection activity for $((detail / 60)) minutes." "内省活動不足" ;;
        19) # 思考ログタイムスタンプ警告（新機能 - v2復活）
            log_warning "Thinking log timestamp warning: Timestamp is $((detail / 60)) minutes old."
            INACTIVITY_WARNING_MESSAGE="⚠️ 思考ログタイムスタンプ警告: 最新の思考ログのタイムスタンプが$((detail / 60))分以上古いです。
ハートビートで渡される最新のタイムスタンプを使用してください。"
            return 0 ;;
        20) # 思考ログタイムスタンプエラー（新機能 - v2復活）
            handle_failure "Thinking log timestamp error: Timestamp is $((detail / 60)) minutes old." "思考ログタイムスタンプ異常" ;;
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
    log_notice "Interrupting agent process..."
    interrupt_agent
    if [ "$SHUTDOWN_REQUESTED" = true ]; then return; fi
    log_notice "Agent processing has been interrupted."


    # コンテキスト圧縮を実行
    log_notice "Sending context compression command..."
    compress_agent_context
    if [ "$SHUTDOWN_REQUESTED" = true ]; then return; fi
    interruptible_sleep 30  # 圧縮処理の完了を待機
    log_notice "Context compression completed."
    
    # チャット保存を実行
    local save_timestamp=$(date "+%Y%m%d%H%M%S")
    local chat_tag="HEARTBEAT_${HEARTBEAT_START_TIMESTAMP}_${save_timestamp}"
    log_notice "Saving chat with tag: $chat_tag"
    save_agent_chat_history "$chat_tag"
    if [ "$SHUTDOWN_REQUESTED" = true ]; then return; fi
    interruptible_sleep 30  # チャット保存処理の完了を待機
    log_notice "Chat saved with tag: $chat_tag"
    
    # 異常種別に応じたアドバイスメッセージを設定
    local advice_message=""
    case "$detection_type" in
        "内省活動不足")
            advice_message="$ADVICE_INTROSPECTION"
            ;;
        "思考ログ頻度異常")
            advice_message="$ADVICE_THINKING_LOG_FREQUENCY"
            ;;
        "思考ログパターン異常")
            advice_message="$ADVICE_THINKING_LOG_PATTERN"
            ;;
        "思考ログループ異常")
            advice_message="$ADVICE_THINKING_LOG_LOOP"
            ;;
        "テーマログパターン異常")
            advice_message="$ADVICE_THEME_LOG_PATTERN"
            ;;
        "思考ログタイムスタンプ異常")
            advice_message="$ADVICE_THINKING_LOG_TIMESTAMP"
            ;;
        *)
            advice_message=""
            ;;
    esac
    
    # 回復メッセージを設定し、回復待機状態に移行
    RECOVERY_MESSAGE="異常検知による回復処理: ${detection_type}を検知したため中断処理を行いました。
コンテキストを圧縮してクリアな状態にリセットしました。
チャット履歴をタグ「${chat_tag}」で保存しました。

以下のドキュメントからシステム仕様を再ロードし、**あなた自身の動作ルールを再設定してください**：
1. GEMINI.md - AI心臓システムでの基本的な動作ルール
2. ai-docs/OPERATION_DETAILS.md - 運用詳細ガイド（思考ログ記録、ファイル操作等）
3. ai-docs/TROUBLESHOOTING_GUIDE.md - 異常状況への対処方法
4. ai-docs/GUIDELINES.md - 運用ガイドライン

システム仕様の再ロード完了後、artifacts/theme_historiesの最新の履歴および最新の思考ログを確認し、
直前の活動内容を再確認してください。

その後、適切な内省活動を行い、正常な処理を再開してください。
"

    # アドバイスメッセージがある場合は追加
    if [ ! -z "$advice_message" ]; then
        RECOVERY_MESSAGE="$RECOVERY_MESSAGE

【アドバイス】
$advice_message"
    fi
    HEARTBEAT_STATE="recovery_waiting"
    RECOVERY_WAIT_CYCLES=0
    
    log_notice "Context compression and recovery message prepared, entering recovery waiting state."
}

# 回復状況確認
check_recovery_status() {
    log_info "Checking agent health for recovery confirmation..."
    check_agent_health
    local status=$?
    if [ $status -eq 0 ]; then
        log_notice "Agent health check passed. Recovery confirmed."
        return 0 # 回復成功
    else
        log_warning "Agent health check failed with status $status. Recovery not yet confirmed."
        return 1 # 回復失敗
    fi
}

# 停止処理
stop_heartbeat() {
    # 最終的なエージェント処理中断
    log_notice "Final agent process interruption..."
    interrupt_agent
    log_notice "Agent processing has been interrupted."

    log_notice "Heartbeat stopping at $(date "+%F %T")"
    exit 0
}

# SIGINT (Ctrl-C) と SIGTERM を捕捉
trap handle_shutdown SIGINT SIGTERM

log_notice "Heartbeat monitor started at $(date "+%F %T")"
log_notice "Monitored directories: ${MONITORED_DIRS[*]}"
log_notice "Warning threshold: $((INACTIVITY_WARNING_THRESHOLD / 60)) minutes"
log_notice "Stop threshold: $((INACTIVITY_STOP_THRESHOLD / 60)) minutes"

while true; do
    # 1. 回復待機状態の処理
    if [ "$HEARTBEAT_STATE" = "recovery_waiting" ]; then
        # 終了リクエストがあれば、回復待機中でもループを抜ける
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            break
        fi

        # 回復待機状態：回復確認のみ実行
        log_info "Recovery waiting state (cycle $((RECOVERY_WAIT_CYCLES + 1))/$MAX_RECOVERY_WAIT_CYCLES)"
        
        check_recovery_status
        if [ $? -eq 0 ]; then
            # 回復確認
            log_notice "Agent recovery confirmed. Returning to normal state."
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
            interruptible_sleep "$INTERVAL_SECONDS" "[RECOVERY WAIT] Next check in %2d seconds... "
            continue
        fi
    fi
    
    # 2. カウントダウン（通常状態のみ）
    if [ "$HEARTBEAT_STATE" = "normal" ]; then
        interruptible_sleep "$INTERVAL_SECONDS" "Next heartbeat in %2d seconds... "

        # 終了リクエストがあればハートビートを送信せずにループを終了
        if [ "$SHUTDOWN_REQUESTED" = true ]; then
            break
        fi
    fi
    
    # 3. 異常チェック（ハートビート送信直前）
    if [ "$HEARTBEAT_STATE" = "normal" ]; then
        check_recent_activity
    fi

    # 4. Web検索制限チェック
    check_web_search_restriction
    
    # 4.5 feedbackboxチェック
    check_feedbackbox

    # 4.6 緊急フィードバック処理（ハートビート送信前）
    if [ "$EMERGENCY_FEEDBACK_DETECTED" = true ]; then
        log_warning "Emergency feedback detected. Interrupting agent process..."
        interrupt_agent
        log_notice "Agent processing interrupted for emergency feedback."
        # 処理完了後にフラグをリセット（防御的プログラミング）
        EMERGENCY_FEEDBACK_DETECTED=false
    fi

    # 5. ハートビート送信（常に実行）

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
    
    # 無活動警告メッセージ追加
    if [ ! -z "$INACTIVITY_WARNING_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$INACTIVITY_WARNING_MESSAGE"
        INACTIVITY_WARNING_MESSAGE=""  # 一度使ったらクリア
        log_info "Inactivity warning included in heartbeat"
    fi
    
    # フィードバック通知メッセージ追加
    if [ ! -z "$FEEDBACK_NOTIFICATION_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$FEEDBACK_NOTIFICATION_MESSAGE"
        FEEDBACK_NOTIFICATION_MESSAGE=""  # 一度使ったらクリア
        log_notice "Feedback notification included in heartbeat"
    fi
    
    # 回復メッセージ追加
    if [ ! -z "$RECOVERY_MESSAGE" ]; then
        heartbeat_msg="$heartbeat_msg

$RECOVERY_MESSAGE"
        RECOVERY_MESSAGE=""  # 一度使ったらクリア
        log_info "Recovery message included in heartbeat"
    fi
    
    send_message_to_agent "$heartbeat_msg"

    log_heartbeat "Heartbeat sent to agent session"
done

# ループを抜けた後に最終処理を実行
graceful_shutdown
