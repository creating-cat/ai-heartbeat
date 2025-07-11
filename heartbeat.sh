#!/bin/bash

# ライブラリの読み込み
source "lib/logging.sh"
source "lib/config.sh"
source "lib/utils.sh"
source "lib/health_check_core.sh"

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

# 内省活動をチェックする関数
_check_introspection_activity() {
    local current_time=$(date +%s)
    
    # 内省を含むファイルから最新のタイムスタンプを取得
    local latest_timestamp=$(grep -ril "内省" artifacts/*/histories/* 2>/dev/null | \
        sed 's|.*/||' | \
        grep -o '^[0-9]\{14\}' | \
        sort -r | \
        head -1)
    
    local introspection_diff
    
    # 内省活動が見つからない場合、またはHEARTBEAT_START_TIMEより前の場合の処理
    if [ -z "$latest_timestamp" ]; then
        # ハートビート起動からの経過時間で判定
        introspection_diff=$((current_time - HEARTBEAT_START_TIME))
        log_info "No introspection found: $((introspection_diff / 60)) minutes since heartbeat start"
    else
        # タイムスタンプを秒に変換
        local file_time=$(convert_timestamp_to_seconds "$latest_timestamp")
        
        if [ -z "$file_time" ] || [ $file_time -lt $HEARTBEAT_START_TIME ]; then
            # 変換失敗またはハートビート起動前の場合、起動時刻を基軸とする
            introspection_diff=$((current_time - HEARTBEAT_START_TIME))
            log_info "Introspection before heartbeat start: $((introspection_diff / 60)) minutes since heartbeat start"
        else
            # 通常の判定（ハートビート起動後の内省活動）
            introspection_diff=$((current_time - file_time))
            log_info "Last introspection: $((introspection_diff / 60)) minutes ago"
        fi
    fi
    
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


# エージェントの健全性をチェックするコア関数
# 戻り値: 0=正常, 1=警告レベル, 2=エラーレベル
# 新しいhealth_check_core.shを使用した統一処理
check_agent_health() {
    local latest_file_info=$(_get_latest_file_info)
    [ $? -ne 0 ] || [ -z "$latest_file_info" ] && return 0 # 監視対象がない/ファイルがない場合は正常とみなす

    local latest_time=$(echo "$latest_file_info" | cut -d' ' -f1)
    local latest_filename=$(echo "$latest_file_info" | cut -d' ' -f2-)
    local current_time=$(date +%s)
    
    # 1. 無活動異常検知
    local inactivity_result=$(check_inactivity_anomaly "$latest_time" "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local inactivity_status=$?
    if [ $inactivity_status -ne 0 ]; then
        HEALTH_CHECK_DETAIL="$inactivity_result"
        # 戻り値で直接判定
        if [ $inactivity_status -eq 1 ]; then
            log_warning "[CHECK] Inactivity warning detected (code 1): $inactivity_result seconds"
            return 1 # 無活動警告
        else
            log_warning "[CHECK] Inactivity error detected (code 3): $inactivity_result seconds"
            return 3 # 無活動エラー
        fi
    fi

    # 2. 同一ファイルループ検知
    local loop_result=$(check_loop_anomaly "$latest_filename" "$LOOP_DETECTION_FILE" "$LOOP_DETECTION_START_TIME" "$current_time" "$INACTIVITY_STOP_THRESHOLD")
    local loop_status=$?
    
    # 戻り値のみで判定
    if [ $loop_status -eq 2 ]; then
        # エラー時
        HEALTH_CHECK_DETAIL="$loop_result"
        log_warning "[CHECK] Loop anomaly detected (code 4): $loop_result"
        return 4 # ループエラー
    elif [ "$latest_filename" != "$LOOP_DETECTION_FILE" ]; then
        # 新しいファイル検出時
        LOOP_DETECTION_FILE="$latest_filename"
        LOOP_DETECTION_START_TIME="$current_time"
        log_info "Loop detection reset for new file: $latest_filename"
    elif [ -z "$LOOP_DETECTION_START_TIME" ]; then
        # ループ検出開始時
        LOOP_DETECTION_START_TIME="$current_time"
        log_info "Loop detection started for file: $latest_filename"
    fi

    # 3. ファイル名タイムスタンプチェック
    local timestamp_result=$(check_timestamp_anomaly "$latest_filename" "$current_time" "$TIMESTAMP_ANOMALY_THRESHOLD" "$HEARTBEAT_START_TIME")
    local timestamp_status=$?
    if [ $timestamp_status -ne 0 ]; then
        HEALTH_CHECK_DETAIL="$timestamp_result"
        log_warning "[CHECK] Timestamp anomaly detected (code 5): $timestamp_result"
        return 5 # タイムスタンプ異常
    fi
    
    # 4. 内省活動不足検知
    _check_introspection_activity
    introspection_status=$?
    if [ $introspection_status -eq 1 ]; then
        log_warning "[CHECK] Introspection deficiency detected (code 6): $HEALTH_CHECK_DETAIL"
        return 6 # 内省不足 (HEALTH_CHECK_DETAIL is set by _check_introspection_activity)
    elif [ $introspection_status -eq 2 ]; then
        log_warning "[CHECK] Introspection warning detected (code 2): $HEALTH_CHECK_DETAIL"
        return 2 # 内省警告
    fi

    # 5. 思考ログ重複作成異常検知（新機能）
    local duplicate_result=$(check_thinking_log_duplicate "artifacts" "$current_time")
    local duplicate_status=$?
    if [ $duplicate_status -ne 0 ]; then
        HEALTH_CHECK_DETAIL="$duplicate_result"
        log_warning "[CHECK] Thinking log duplicate detected (code 7): $duplicate_result files"
        return 7 # 思考ログ重複作成異常
    fi

    # 6. 思考ログ繰り返し更新異常検知（新機能）
    local repeat_result=$(check_thinking_log_repeat "artifacts" "$current_time")
    local repeat_status=$?
    if [ $repeat_status -ne 0 ]; then
        HEALTH_CHECK_DETAIL="$repeat_result"
        log_warning "[CHECK] Thinking log repeat detected (code 8): $repeat_result files"
        return 8 # 思考ログ繰り返し更新異常
    fi

    # 7. テーマログ異常検知（新機能）
    local theme_result=$(check_theme_log_anomaly "artifacts" "$current_time")
    local theme_status=$?
    if [ $theme_status -ne 0 ]; then
        HEALTH_CHECK_DETAIL="$theme_result"
        log_warning "[CHECK] Theme log anomaly detected (code 9): $theme_result files"
        return 9 # テーマログ異常
    fi

    # 8. 思考ログ頻度異常検知（新機能 - v2）
    local thinking_freq_result=$(check_thinking_log_frequency_anomaly "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local thinking_freq_code=$(echo "$thinking_freq_result" | cut -d':' -f1)
    local thinking_freq_detail=$(echo "$thinking_freq_result" | cut -d':' -f2)
    
    if [ "$thinking_freq_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$thinking_freq_detail"
        if [ "$thinking_freq_code" = "10" ]; then
            log_warning "[CHECK] Thinking log frequency warning detected (code 10): $thinking_freq_detail seconds"
            return 10 # 思考ログ頻度警告
        elif [ "$thinking_freq_code" = "11" ]; then
            log_warning "[CHECK] Thinking log frequency error detected (code 11): $thinking_freq_detail seconds"
            return 11 # 思考ログ頻度エラー
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
        1) # 無活動警告
            log_warning "Agent activity is low. No file updates for $((detail / 60)) minutes."
            INACTIVITY_WARNING_MESSAGE="⚠️ 無活動警告: $((detail / 60))分間ファイル更新がありません。

$ADVICE_INACTIVITY"
            return 0 ;;
        2) # 内省警告
            log_warning "Introspection activity has not been performed for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="⚠️ 内省不足警告: $((detail / 60))分間内省活動が行われていません。

$ADVICE_INTROSPECTION"
            return 0 ;;
        3) 
            handle_failure "Agent appears to be stuck! No file updates for $((detail / 60)) minutes." "無活動状態" ;;
        4) 
            handle_failure "Agent appears to be stuck! Same file updated continuously for $((detail / 60)) minutes: $latest_filename" "同一ファイル継続更新ループ" ;;
        5) 
            handle_failure "Agent appears to be stuck! File timestamp is too old ($((detail / 60)) minutes): $latest_filename" "最新ファイル名タイムスタンプ異常" ;;
        6) 
            handle_failure "Agent appears to be stuck! No introspection activity for $((detail / 60)) minutes." "内省活動不足" ;;
        7) # 思考ログ重複作成異常（新機能）
            handle_failure "Agent appears to be stuck! Thinking log duplicate creation detected ($detail files)" "思考ログ重複作成異常" ;;
        8) # 思考ログ繰り返し更新異常（新機能）
            handle_failure "Agent appears to be stuck! Thinking log repeat update detected ($detail files)" "思考ログ繰り返し更新異常" ;;
        9) # テーマログ異常（新機能）
            handle_failure "Agent appears to be stuck! Theme log anomaly detected ($detail files)" "テーマログ異常" ;;
        10) # 思考ログ頻度警告（新機能 - v2）
            log_warning "Thinking log frequency warning: No thinking log updates for $((detail / 60)) minutes."
            INACTIVITY_WARNING_MESSAGE="⚠️ 思考ログ頻度警告: $((detail / 60))分間思考ログの更新がありません。

$ADVICE_INACTIVITY"
            return 0 ;;
        11) # 思考ログ頻度エラー（新機能 - v2）
            handle_failure "Thinking log frequency error: No thinking log updates for $((detail / 60)) minutes." "思考ログ頻度異常" ;;
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
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    sleep 1
    log_notice "Agent processing has been interrupted."


    # コンテキスト圧縮を実行
    log_notice "Sending context compression command..."
    tmux send-keys -t agent "/compress"
    sleep 1
    tmux send-keys -t agent C-m
    sleep 5  # 圧縮処理の完了を待機
    log_notice "Context compression completed."
    
    # チャット保存を実行
    local save_timestamp=$(date "+%Y%m%d%H%M%S")
    local chat_tag="HEARTBEAT_${HEARTBEAT_START_TIMESTAMP}_${save_timestamp}"
    log_notice "Saving chat with tag: $chat_tag"
    tmux send-keys -t agent "/chat save $chat_tag"
    sleep 1
    tmux send-keys -t agent C-m
    sleep 5  # チャット保存処理の完了を待機
    log_notice "Chat saved with tag: $chat_tag"
    
    # 異常種別に応じたアドバイスメッセージを設定
    local advice_message=""
    case "$detection_type" in
        "無活動状態")
            advice_message="$ADVICE_INACTIVITY"
            ;;
        "内省活動不足")
            advice_message="$ADVICE_INTROSPECTION"
            ;;
        "同一ファイル継続更新ループ")
            advice_message="$ADVICE_LOOP"
            ;;
        "最新ファイル名タイムスタンプ異常")
            advice_message="$ADVICE_TIMESTAMP"
            ;;
        "思考ログ重複作成異常")
            advice_message="
思考ログの作成に異常が検知されました。
同じタイムスタンプで3つ以上の思考ログファイルが作成されています。
一回のハートビートでは、適切なタイミングで思考ログを保存し、次のハートビートに備えることを推奨します。
適切な範囲で処理を区切って小さく積み重ねていくことが、エージェントの思考を整理し、次の行動に活かすために重要です。
"
            ;;
        "思考ログ繰り返し更新異常")
            advice_message="
思考ログの作成に異常が検知されました。
同じタイムスタンプの思考ログファイルが繰り返し更新されています（連番ファイルの存在）。
一回のハートビートでは、適切なタイミングで思考ログを保存し、次のハートビートに備えることを推奨します。
適切な範囲で処理を区切って小さく積み重ねていくことが、エージェントの思考を整理し、次の行動に活かすために重要です。
"
            ;;
        "テーマログ異常")
            advice_message="
テーマログの作成に異常が検知されました。
同じタイムスタンプで複数のテーマログファイルが作成されている可能性があります。
テーマの選択や変更は慎重に行い、一つのテーマに集中して取り組むことを推奨します。
複数のテーマを同時に扱う場合は、異なるハートビートサイクルで分けて処理することが重要です。
"
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
    log_error "Maximum recovery attempts ($MAX_RECOVERY_ATTEMPTS) exceeded or critical error detected"
    log_notice "Heartbeat stopping at $(date "+%F %T")"

    # 最終的なエージェント処理中断
    log_notice "Final agent process interruption..."
    tmux send-keys -t agent Escape
    sleep 1
    tmux send-keys -t agent Escape
    log_notice "Agent processing has been interrupted."
        
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
            # カウントダウンのみ実行
            for i in $(seq ${INTERVAL_SECONDS} -1 1); do
                printf "\r[RECOVERY WAIT] Next check in %2d seconds... " "$i"
                sleep 1
            done
            printf "\r                                           \r"
            continue
        fi
    fi
    
    # 2. カウントダウン（通常状態のみ）
    if [ "$HEARTBEAT_STATE" = "normal" ]; then
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
        tmux send-keys -t agent Escape
        sleep 1
        tmux send-keys -t agent Escape
        sleep 1
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
    
    tmux send-keys -t agent "$heartbeat_msg"
    sleep 1
    tmux send-keys -t agent C-m

    log_heartbeat "Heartbeat sent to agent session"
done

# ループを抜けた後に最終処理を実行
graceful_shutdown
