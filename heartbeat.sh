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

 # statsディレクトリ作成（cooldownとlockサブディレクトリも）
mkdir -p ai-works/stats/cooldown ai-works/stats/lock

# Web検索制限メッセージ用グローバル変数
WEB_RESTRICTION_MESSAGE=""

# 内省促進メッセージ用グローバル変数
INTROSPECTION_REMINDER_MESSAGE=""

# 無活動警告メッセージ用グローバル変数
INACTIVITY_WARNING_MESSAGE=""

# フィードバック通知メッセージ用グローバル変数
FEEDBACK_NOTIFICATION_MESSAGE=""

# 割り込みフィードバックフラグ用グローバル変数
INTERRUPT_FEEDBACK_DETECTED=false

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

# ツールクールダウン設定用連想配列
declare -A TOOL_COOLDOWNS
declare -A TOOL_LOCKS

# 終了フラグ
SHUTDOWN_REQUESTED=false

# ハートビートIDファイル書き込み関数
write_heartbeat_id() {
    local heartbeat_id="$1"
    local output_file="ai-works/stats/current_heartbeat_id.txt"
    
    # 入力検証
    if [ -z "$heartbeat_id" ]; then
        log_error "write_heartbeat_id: heartbeat_id is required"
        return 1
    fi
    
    # 原子的書き込み実行
    if write_file_atomic "$heartbeat_id" "$output_file"; then
        if [ "$DEBUG_MODE" = "true" ]; then
            log_info "Heartbeat ID written to file: $heartbeat_id"
        fi
        return 0
    else
        log_warning "Failed to write heartbeat ID to file: $heartbeat_id"
        return 1
    fi
}

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
# ログファイル名は起動時のハートビートID付き（例: heartbeat_20250106143022.log）
LOG_FILE="$LOG_DIR/heartbeat_${HEARTBEAT_START_TIMESTAMP}.log"

# ログ初期化（lib/logging.shを使用）
init_logging "$LOG_DIR/heartbeat_${HEARTBEAT_START_TIMESTAMP}.log" "$LOG_DIR" "$DEBUG_MODE" "$MAX_LOG_DAYS"

# スクリプト開始時刻を記録
log_notice "Heartbeat started at $(date "+%F %T") (PID: $$)"
log_notice "Log file: $LOG_FILE"

# feedbackboxのチェック関数
check_feedbackbox() {
    FEEDBACK_NOTIFICATION_MESSAGE=""
    INTERRUPT_FEEDBACK_DETECTED=false  # フラグリセット
    
    # feedbackboxディレクトリが存在しない場合は作成
    if [ ! -d "ai-works/feedbackbox" ]; then
        mkdir -p ai-works/feedbackbox
        return 0
    fi
    
    # プレフィックスなしのmdファイル（処理対象のフィードバック）を検出
    local feedback_files=$(find ai-works/feedbackbox -name "*.md" -not -name "draft.*" -not -name "processed.*" 2>/dev/null)
    local feedback_count=$(echo "$feedback_files" | grep -v "^$" | wc -l | tr -d ' ')
    
    if [ $feedback_count -gt 0 ]; then
        # 割り込みフィードバックチェック
        local interrupt_files=$(echo "$feedback_files" | grep "interrupt\.")
        local interrupt_count=$(echo "$interrupt_files" | grep -v "^$" | wc -l | tr -d ' ')
        
        if [ $interrupt_count -gt 0 ]; then
            INTERRUPT_FEEDBACK_DETECTED=true
            
            # 割り込みフィードバックファイルのinterrupt.プレフィックスを削除
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local dir=$(dirname "$file")
                    local filename=$(basename "$file")
                    local new_filename=$(echo "$filename" | sed 's/^interrupt\.//')
                    mv "$file" "$dir/$new_filename"
                    log_notice "Renamed interrupt feedback: $filename -> $new_filename"
                fi
            done <<< "$interrupt_files"
            
            FEEDBACK_NOTIFICATION_MESSAGE="【割り込み】feedbackboxに未処理のユーザーフィードバックが${feedback_count}件あります。今すぐ内省活動に入り、確認・対応してください。"
            log_warning "Found $interrupt_count interrupt feedback files (total: $feedback_count)"
        else
            FEEDBACK_NOTIFICATION_MESSAGE="feedbackboxに未処理のユーザーフィードバックが${feedback_count}件あります。内省時に確認・対応してください。"
            log_notice "Found $feedback_count unprocessed feedback files"
        fi
        return 1  # フィードバックあり
    fi
    
    return 0  # フィードバックなし
}

# ツールクールダウン設定を読み込む
load_tool_cooldown_config() {
    local config_file="tool_cooldowns.conf"
    if [ ! -f "$config_file" ]; then
        log_warning "Tool cooldown config file not found: $config_file"
        return
    fi
    while IFS=':' read -r tool_id cooldown_sec lock_sec || [[ -n "$tool_id" ]]; do
        # コメント行と空行をスキップ
        tool_id=$(echo "$tool_id" | xargs) # trim whitespace
        [[ "$tool_id" =~ ^\s*# ]] && continue
        [[ -z "$tool_id" ]] && continue

        TOOL_COOLDOWNS["$tool_id"]=${cooldown_sec:-0}
        TOOL_LOCKS["$tool_id"]=${lock_sec:-0}
        log_info "Loaded cooldown for '$tool_id': ${cooldown_sec}s (cooldown), ${lock_sec}s (lock)"
    done < "$config_file"
}

# 汎用的なツール利用制限チェック関数
check_tool_restrictions() {
    TOOL_RESTRICTION_MESSAGES=""
    local current_time=$(date +%s)

    # 1. ロックされたツールをチェック (ai-works/stats/lock/)
    for lockfile in ai-works/stats/lock/*; do
        [ -f "$lockfile" ] || continue
        local tool_id=$(basename "$lockfile")
        local lock_time=$(get_file_time "$lockfile")
        local lock_duration=${TOOL_LOCKS[$tool_id]:-3600} # Default 1 hour
        local diff=$((current_time - lock_time))

        if [ $diff -lt $lock_duration ]; then
            local remaining=$((lock_duration - diff))
            TOOL_RESTRICTION_MESSAGES+="ツール[${tool_id}]はロック中です (クォータ超過のため、残り約$((remaining / 60))分)\n"
        else
            rm "$lockfile" && log_info "Tool lock for [$tool_id] has been lifted."
        fi
    done

    # 2. クールダウン中のツールをチェック (ai-works/stats/cooldown/)
    for cooldownfile in ai-works/stats/cooldown/*; do
        [ -f "$cooldownfile" ] || continue
        local tool_id=$(basename "$cooldownfile")
        # すでにロックされていないか確認
        if [[ $TOOL_RESTRICTION_MESSAGES != *"$tool_id"* ]]; then
            local cooldown_time=$(get_file_time "$cooldownfile")
            local cooldown_duration=${TOOL_COOLDOWNS[$tool_id]:-600} # Default 10 mins
            local diff=$((current_time - cooldown_time))

            if [ $diff -lt $cooldown_duration ]; then
                local remaining=$((cooldown_duration - diff))
                TOOL_RESTRICTION_MESSAGES+="ツール[${tool_id}]はクールダウン中です (残り約$((remaining / 60))分)\n"
            else
                rm "$cooldownfile" && log_info "Tool cooldown for [$tool_id] has ended."
            fi
        fi
    done

    # メッセージがあれば制限あり
    if [ -n "$TOOL_RESTRICTION_MESSAGES" ]; then
        TOOL_RESTRICTION_MESSAGES=$(echo -e "${TOOL_RESTRICTION_MESSAGES}" | sed '/^$/d')
        return 1
    fi
    
    return 0
}

# エージェントの健全性をチェックするコア関数
# 戻り値: 0=正常, 1=警告レベル, 2=エラーレベル
# 新しいhealth_check_core.shを使用した統一処理
check_agent_health() {
    local current_time=$(date +%s)
    
    # 深い作業完了の検知（内省義務化のため）- 削除済み
    # detect_deep_work_completion
    
    # 内省義務違反チェック（新機能）- 削除済み
    # local introspection_obligation_result=$(check_introspection_obligation_violation "$current_time")
    # local introspection_obligation_code=$(echo "$introspection_obligation_result" | cut -d':' -f1)
    # local introspection_obligation_detail=$(echo "$introspection_obligation_result" | cut -d':' -f2)
    
    # if [ "$introspection_obligation_code" != "0" ]; then
    #     HEALTH_CHECK_DETAIL="内省義務違反: ハートビートID $introspection_obligation_detail"
    #     log_warning "[CHECK] Introspection obligation violation detected: $introspection_obligation_detail"
    #     return 22 # 内省義務違反（新しいエラーコード）
    # fi
    
    # flexibleモードでのチェックポイント必須チェック（新機能）
    local flexible_checkpoint_result=$(check_flexible_mode_checkpoint_requirement "$current_time")
    local flexible_checkpoint_code=$(echo "$flexible_checkpoint_result" | cut -d':' -f1)
    local flexible_checkpoint_detail=$(echo "$flexible_checkpoint_result" | cut -d':' -f2)
    
    if [ "$flexible_checkpoint_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="flexibleモードチェックポイント不足: $flexible_checkpoint_detail 分経過"
        if [ "$flexible_checkpoint_code" = "1" ]; then
            log_warning "[CHECK] Flexible mode checkpoint requirement warning: $flexible_checkpoint_detail minutes elapsed"
            return 23 # flexibleモードチェックポイント不足警告（新しいエラーコード）
        fi
    fi
    
    # 8. 活動ログ頻度異常検知（新機能 - v2）
    local activity_freq_result=$(check_activity_log_frequency_anomaly "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local activity_freq_code=$(echo "$activity_freq_result" | cut -d':' -f1)
    local activity_freq_detail=$(echo "$activity_freq_result" | cut -d':' -f2)
    
    if [ "$activity_freq_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$activity_freq_detail"
        if [ "$activity_freq_code" = "1" ]; then
            log_warning "[CHECK] Activity log frequency warning detected (code 10): $activity_freq_detail seconds"
            return 10 # 活動ログ頻度警告
        elif [ "$activity_freq_code" = "2" ]; then
            log_warning "[CHECK] Activity log frequency error detected (code 11): $activity_freq_detail seconds"
            return 11 # 活動ログ頻度エラー
        fi
    fi

    # 9. テーマログパターン異常検知（新機能 - v2）
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

    # 10. 活動ログループ異常検知（復活 - 手動編集による問題行動検知のため）
    local activity_loop_result=$(check_activity_log_loop_anomaly "$current_time" "$HEARTBEAT_START_TIME")
    local activity_loop_code=$(echo "$activity_loop_result" | cut -d':' -f1)
    local activity_loop_detail=$(echo "$activity_loop_result" | cut -d':' -f2)
    
    if [ "$activity_loop_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$activity_loop_detail"
        if [ "$activity_loop_code" = "2" ]; then
            log_warning "[CHECK] Activity log loop error detected (code 14): $activity_loop_detail loops"
            return 14 # 活動ログループエラー
        fi
    fi

    # 11. 内省活動異常検知（新機能 - v2）
    local introspection_result=$(check_introspection_activity_anomaly "$current_time" "$INTROSPECTION_THRESHOLD" "$HEARTBEAT_START_TIME")
    local introspection_code=$(echo "$introspection_result" | cut -d':' -f1)
    local introspection_detail=$(echo "$introspection_result" | cut -d':' -f2)
    
    if [ "$introspection_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$introspection_detail"
        if [ "$introspection_code" = "3" ]; then
            log_notice "[CHECK] Introspection activity notification detected (code 21): $introspection_detail seconds"
            return 21 # 内省活動通知
        elif [ "$introspection_code" = "1" ]; then
            log_warning "[CHECK] Introspection activity warning detected (code 17): $introspection_detail seconds"
            return 17 # 内省活動警告
        elif [ "$introspection_code" = "2" ]; then
            log_warning "[CHECK] Introspection activity error detected (code 18): $introspection_detail seconds"
            return 18 # 内省活動エラー
        fi
    fi

    # 12. 活動ログタイムスタンプ乖離異常検知（新機能 - v2復活）
    local timestamp_result=$(check_activity_log_timestamp_anomaly "$current_time" "$INACTIVITY_WARNING_THRESHOLD" "$INACTIVITY_STOP_THRESHOLD" "$HEARTBEAT_START_TIME")
    local timestamp_code=$(echo "$timestamp_result" | cut -d':' -f1)
    local timestamp_detail=$(echo "$timestamp_result" | cut -d':' -f2)

    if [ "$timestamp_code" != "0" ]; then
        HEALTH_CHECK_DETAIL="$timestamp_detail"
        if [ "$timestamp_code" = "1" ]; then
            log_warning "[CHECK] Activity log timestamp warning detected (code 19): $timestamp_detail seconds"
            return 19 # 活動ログタイムスタンプ警告
        elif [ "$timestamp_code" = "2" ]; then
            log_warning "[CHECK] Activity log timestamp error detected (code 20): $timestamp_detail seconds"
            return 20 # 活動ログタイムスタンプエラー
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
        10) # 活動ログ頻度警告（新機能 - v2）
            log_warning "Activity log frequency warning: No activity log updates for $((detail / 60)) minutes."
            INACTIVITY_WARNING_MESSAGE="活動ログ頻度警告: $((detail / 60))分間活動ログの更新がありません。

$ADVICE_ACTIVITY_LOG_FREQUENCY"
            return 0 ;;
        11) # 活動ログ頻度エラー（新機能 - v2）
            handle_failure "Activity log frequency error: No activity log updates for $((detail / 60)) minutes." "活動ログ頻度異常" ;;
        14) # 活動ログループエラー（復活 - 手動編集による問題行動検知のため）
            handle_failure "Activity log loop error: Same activity log edited $detail times consecutively." "活動ログループ異常" ;;
        16) # テーマログパターンエラー（新機能 - v2）
            handle_failure "Theme log pattern error: $detail files with same timestamp detected." "テーマログパターン異常" ;;
        17) # 内省活動警告（新機能 - v2）
            log_warning "Introspection activity warning: No introspection activity for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="内省不足警告: $((detail / 60))分間内省活動が行われていません。

$ADVICE_INTROSPECTION"
            return 0 ;;
        18) # 内省活動警告（重度）（新機能 - v2）
            log_warning "Introspection activity warning (severe): No introspection activity for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="内省不足警告（重度）: $((detail / 60))分間内省活動が行われていません。

$ADVICE_INTROSPECTION"
            return 0 ;;
        19) # 活動ログタイムスタンプ警告（新機能 - v2復活）
            log_warning "Activity log timestamp warning: Timestamp is $((detail / 60)) minutes old."
            INACTIVITY_WARNING_MESSAGE="活動ログタイムスタンプ警告: 最新の活動ログのハートビートIDが$((detail / 60))分以上古いです。
活動ログはハートビート毎に毎回新しく作成する必要があります。
このハートビートの活動の終わりに必ず新しい活動ログを作成してください。"
            return 0 ;;
        20) # 活動ログタイムスタンプエラー（新機能 - v2復活）
            handle_failure "Activity log timestamp error: Timestamp is $((detail / 60)) minutes old." "活動ログタイムスタンプ異常" ;;
        21) # 内省活動通知（新機能 - v2）
            log_notice "Introspection activity notification: No introspection activity for $((detail / 60)) minutes."
            INTROSPECTION_REMINDER_MESSAGE="内省活動通知: $((detail / 60))分間内省活動が行われていません。

$ADVICE_INTROSPECTION"
            return 0 ;;
        # 22) # 内省義務違反（削除済み）
        #     handle_failure "Introspection obligation violation: Deep work completed but next activity log is not introspection (ハートビートID: $detail)." "内省義務違反" ;;
        23) # flexibleモードチェックポイント不足警告（新機能）
            log_warning "Flexible mode checkpoint requirement warning: No checkpoints for $detail minutes."
            INACTIVITY_WARNING_MESSAGE="flexibleモード警告: $detail 分間チェックポイントログが作成されていません。

flexibleモードでは定期的なチェックポイントログの作成が推奨されます。
checkpointツールを使用して現在の活動状況を記録してください。"
            return 0 ;;
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
        "活動ログ内省不足")
            advice_message="$ADVICE_INTROSPECTION"
            ;;
        "活動ログ頻度異常")
            advice_message="$ADVICE_ACTIVITY_LOG_FREQUENCY"
            ;;
        "活動ログループ異常")
            advice_message="$ADVICE_ACTIVITY_LOG_LOOP"
            ;;
        "テーマログパターン異常")
            advice_message="$ADVICE_THEME_LOG_PATTERN"
            ;;
        "活動ログタイムスタンプ異常")
            advice_message="$ADVICE_ACTIVITY_LOG_TIMESTAMP"
            ;;
        # "内省義務違反") # 削除済み
        #     advice_message="$ADVICE_INTROSPECTION_OBLIGATION"
        #     ;;
        *)
            advice_message=""
            ;;
    esac
    
    # 異常種別に応じた特定ドキュメントを決定
    local specific_docs=""
    case "$detection_type" in
        "活動ログ内省不足"|"活動ログ頻度異常"|"活動ログループ異常"|"活動ログタイムスタンプ異常")
            specific_docs="4. ai-docs/BASIC_OPERATIONS.md - 基本操作の詳細手順"
            ;;
        "テーマログパターン異常")
            specific_docs="4. ai-docs/THEME_SYSTEM.md - テーマシステム詳細ガイド"
            ;;
        # "内省義務違反") # 削除済み
        #     specific_docs="4. ai-docs/ACTIVITY_DETAILS.md - 各活動種別の詳細ガイド"
        #     ;;
        *)
            specific_docs="4. ai-docs/ERROR_HANDLING.md - エラー・例外処理完全版"
            ;;
    esac

    # 回復メッセージを設定し、回復待機状態に移行
    RECOVERY_MESSAGE="**異常検知による回復処理**: ${detection_type}を検知したため緊急回復処理を実行しました。

**実行した緊急回復のための処理:**
- エージェント処理の安全な中断
- コンテキスト圧縮によるメモリクリア
- チャット履歴の保存（タグ: ${chat_tag}）

**回復手順:**
以下のドキュメントを再ロードして、**あなた自身の動作ルールを再設定してください**

1. **GEMINI.md**: 基本的な動作ルールを再確認してください。
2. **ai-docs/SYSTEM_PHILOSOPHY.md**: なぜそのルールが存在するのか、システムの根本的な思想を再確認してください。
3. **ai-docs/ERROR_HANDLING.md**: この異常状況への具体的対処法を確認してください。
4. ${specific_docs}

**次のステップ:**
1. 上記ドキュメントで動作ルールと対処法を再確認
2. artifacts/theme_historiesで直前の活動履歴を確認
3. 最新の活動ログで中断前の状況を把握
4. 適切な内省活動を実行して、このハートビートの活動を終了し、次のハートビートから活動を再開
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

# ツールクールダウン設定を読み込む
load_tool_cooldown_config

# 初回ハートビート送信（起動直後）
log_notice "Sending initial heartbeat immediately after startup..."

# Initial startup check for first heartbeat
initial_heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
if [ ! -d ai-works/artifacts/* ] 2>/dev/null || [ -z "$(find ai-works/artifacts -maxdepth 1 -type d ! -name artifacts ! -name theme_histories 2>/dev/null)" ]; then
    initial_heartbeat_msg="$initial_heartbeat_msg
**システム初回起動**: 現在テーマが設定されていません。
ai-docs/THEME_SYSTEM.md の「1. テーマ開始活動の詳細」を参照し
必ずテーマ開始活動を実行してください。"
    log_info "Initial startup detected: No theme directories found"
fi

send_message_to_agent "$initial_heartbeat_msg"

# 初回ハートビートID書き込み（エラーが発生してもシステム継続）
initial_heartbeat_id=$(echo "$initial_heartbeat_msg" | grep "^Heartbeat:" | cut -d' ' -f2)
if [ ! -z "$initial_heartbeat_id" ]; then
    write_heartbeat_id "$initial_heartbeat_id"
fi

log_heartbeat "Initial heartbeat sent to agent session"
log_heartbeat "Heartbeat sent to agent session"

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
        # 深い作業宣言の状況をログに記録
        if check_extended_processing_deadline; then
            local extended_info=$(get_extended_processing_info)
            if [ $? -eq 0 ]; then
                local heartbeat_id=$(echo "$extended_info" | cut -d':' -f1)
                local planned_minutes=$(echo "$extended_info" | cut -d':' -f2)
                local remaining_minutes=$(echo "$extended_info" | cut -d':' -f3)
                local reason=$(echo "$extended_info" | cut -d':' -f4)
                
                if [ "$planned_minutes" = "0" ]; then
                    # flexible モード
                    if [ -n "$reason" ]; then
                        log_notice "Activity monitoring disabled: Deep work declared (flexible mode, reason: $reason)"
                    else
                        log_notice "Activity monitoring disabled: Deep work declared (flexible mode)"
                    fi
                else
                    # strict モード
                    if [ -n "$reason" ]; then
                        log_notice "Activity monitoring disabled: Deep work declared (remaining: ${remaining_minutes}min, reason: $reason)"
                    else
                        log_notice "Activity monitoring disabled: Deep work declared (remaining: ${remaining_minutes}min)"
                    fi
                fi
            fi
        fi
        
        check_recent_activity
    fi

    # 4. ツール利用制限チェック
    check_tool_restrictions
    
    # 4.5 feedbackboxチェック
    check_feedbackbox

    # 4.6 割り込みフィードバック処理（ハートビート送信前）
    if [ "$INTERRUPT_FEEDBACK_DETECTED" = true ]; then
        log_warning "Interrupt feedback detected. Interrupting agent process..."
        interrupt_agent
        log_notice "Agent processing interrupted for interrupt feedback."
        # 処理完了後にフラグをリセット（防御的プログラミング）
        INTERRUPT_FEEDBACK_DETECTED=false
    fi

    # 5. ハートビート送信（常に実行）

    # ハートビートメッセージ作成
    heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
    
    # ツール利用制限メッセージ追加
    if [ ! -z "$TOOL_RESTRICTION_MESSAGES" ]; then
        heartbeat_msg="$heartbeat_msg

$TOOL_RESTRICTION_MESSAGES"
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

    # ハートビートID書き込み（エラーが発生してもシステム継続）
    heartbeat_id=$(echo "$heartbeat_msg" | grep "^Heartbeat:" | cut -d' ' -f2)
    if [ ! -z "$heartbeat_id" ]; then
        write_heartbeat_id "$heartbeat_id"
    fi

    log_heartbeat "Heartbeat sent to agent session"
done

# ループを抜けた後に最終処理を実行
graceful_shutdown
