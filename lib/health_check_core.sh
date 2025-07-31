#!/bin/bash

# 異常検知コアライブラリ
# 純粋な判定ロジックのみを含む（副作用なし）
# 戻り値統一: 0=正常, 1=警告レベル, 2=エラーレベル
# 出力形式: "LEVEL:ANOMALY_TYPE:detail"

# インクルードガード
if [ -n "$_HEALTH_CHECK_CORE_SH_INCLUDED" ]; then
    return 0
fi
_HEALTH_CHECK_CORE_SH_INCLUDED=1

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

# 深い作業宣言の期限チェック関数
# 引数: なし
# 戻り値: 0=期限内, 1=期限切れまたは宣言なし（ファイル削除済み）
check_extended_processing_deadline() {
    # アクティブな深い作業宣言ファイルを検索（.completed.txt と .expired.txt は除外）
    local active_files=$(find ai-works/stats/deep_work -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f 2>/dev/null)
    
    if [ -z "$active_files" ]; then
        debug_log "DEEP_WORK: No active declaration files found"
        return 1  # 宣言なし
    fi
    
    # 最新の宣言ファイルを取得（ハートビートID順でソート）
    local latest_declaration=$(echo "$active_files" | sort | tail -n 1)
    local heartbeat_id=$(basename "$latest_declaration" .txt)
    
    debug_log "DEEP_WORK: Checking declaration file: $latest_declaration"
    
    # 宣言ファイルから制限タイプを取得
    local restriction_type=$(grep "制限タイプ:" "$latest_declaration" 2>/dev/null | cut -d' ' -f2)
    
    if [ -z "$restriction_type" ]; then
        debug_warning "DEEP_WORK: Invalid declaration file format, removing"
        rm "$latest_declaration" 2>/dev/null
        return 1
    fi
    
    debug_log "DEEP_WORK: Restriction type: $restriction_type"
    
    if [ "$restriction_type" = "flexible" ]; then
        # flexible モードの場合は次の活動ログまで有効（時間制限なし）
        debug_log "DEEP_WORK: Flexible mode - valid until next activity log"
        return 0  # 有効
    elif [ "$restriction_type" = "strict" ]; then
        # strict モードの場合は時間制限をチェック
        local planned_minutes=$(grep "予定時間:" "$latest_declaration" 2>/dev/null | sed 's/.*: \([0-9]*\)分.*/\1/')
        
        if [ -z "$planned_minutes" ]; then
            debug_warning "DEEP_WORK: Strict mode but no planned time found, removing declaration"
            rm "$latest_declaration" 2>/dev/null
            return 1
        fi
        
        # ハートビートIDから開始時刻を算出
        local heartbeat_time=$(convert_timestamp_to_seconds "$heartbeat_id")
        if [ -z "$heartbeat_time" ]; then
            debug_warning "DEEP_WORK: Invalid heartbeat ID format, removing declaration"
            rm "$latest_declaration" 2>/dev/null
            return 1
        fi
        
        # 期限時刻を算出
        local planned_duration_seconds=$((planned_minutes * 60))
        local deadline_time=$((heartbeat_time + planned_duration_seconds))
        local current_time=$(date +%s)
        
        debug_log "DEEP_WORK: heartbeat_time=$heartbeat_time, planned_minutes=$planned_minutes, deadline_time=$deadline_time, current_time=$current_time"
        
        # 期限チェック
        if [ $current_time -gt $deadline_time ]; then
            local elapsed_minutes=$(((current_time - deadline_time) / 60))
            debug_warning "DEEP_WORK: Strict mode declaration expired ${elapsed_minutes} minutes ago, renaming to expired"
            mv "$latest_declaration" "${latest_declaration%.txt}.expired.txt" 2>/dev/null
            return 1  # 期限切れ
        else
            local remaining_minutes=$(((deadline_time - current_time) / 60))
            debug_log "DEEP_WORK: Strict mode declaration valid, ${remaining_minutes} minutes remaining"
            return 0  # 期限内
        fi
    else
        debug_warning "DEEP_WORK: Unknown restriction type: $restriction_type, removing declaration"
        rm "$latest_declaration" 2>/dev/null
        return 1
    fi
}

# 深い作業宣言の詳細情報を取得する関数
# 戻り値: 0=情報取得成功, 1=宣言ファイルなしまたは無効
# 出力: "heartbeat_id:planned_minutes:remaining_minutes:reason" 形式（flexibleモードの場合はplanned_minutes=0, remaining_minutes=0）
get_extended_processing_info() {
    # アクティブな深い作業宣言ファイルを検索
    local active_files=$(find ai-works/stats/deep_work -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f 2>/dev/null)
    
    if [ -z "$active_files" ]; then
        return 1
    fi
    
    # 最新の宣言ファイルを取得
    local latest_declaration=$(echo "$active_files" | sort | tail -n 1)
    local heartbeat_id=$(basename "$latest_declaration" .txt)
    
    # 宣言ファイルから情報を取得
    local restriction_type=$(grep "制限タイプ:" "$latest_declaration" 2>/dev/null | cut -d' ' -f2)
    local reason=$(grep "活動予定内容:" "$latest_declaration" 2>/dev/null | cut -d' ' -f2-)
    
    # バリデーション
    if [ -z "$restriction_type" ]; then
        return 1
    fi
    
    if [ "$restriction_type" = "flexible" ]; then
        # flexible モードの場合は時間制限なし
        echo "${heartbeat_id}:0:0:${reason}"
        return 0
    elif [ "$restriction_type" = "strict" ]; then
        # strict モードの場合は時間制限あり
        local planned_minutes=$(grep "予定時間:" "$latest_declaration" 2>/dev/null | sed 's/.*: \([0-9]*\)分.*/\1/')
        
        if [ -z "$planned_minutes" ]; then
            return 1
        fi
        
        # 残り時間を計算
        local heartbeat_time=$(convert_timestamp_to_seconds "$heartbeat_id")
        if [ -z "$heartbeat_time" ]; then
            return 1
        fi
        
        local planned_duration_seconds=$((planned_minutes * 60))
        local deadline_time=$((heartbeat_time + planned_duration_seconds))
        local current_time=$(date +%s)
        local remaining_minutes=$(((deadline_time - current_time) / 60))
        
        # 期限切れの場合
        if [ $current_time -gt $deadline_time ]; then
            return 1
        fi
        
        # 情報を出力
        echo "${heartbeat_id}:${planned_minutes}:${remaining_minutes}:${reason}"
        return 0
    else
        return 1
    fi
}

# 最新活動ログファイル情報を取得するヘルパー関数
_get_latest_activity_log_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find ai-works/artifacts -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find ai-works/artifacts -path "*/histories/*.md" -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*.md" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -n 1
    fi
}

# 最新チェックポイントログファイル情報を取得するヘルパー関数
_get_latest_checkpoint_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find ai-works/stats/checkpoints -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find ai-works/stats/checkpoints -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -n 1
    fi
}

# 活動ログとチェックポイントログの最新タイムスタンプを比較して新しい方を返すヘルパー関数
_get_latest_activity_or_checkpoint_info() {
    local latest_activity_info=$(_get_latest_activity_log_info)
    local latest_checkpoint_info=$(_get_latest_checkpoint_info)
    
    local latest_activity_time=0
    local latest_checkpoint_time=0
    
    if [ -n "$latest_activity_info" ]; then
        latest_activity_time=$(echo "$latest_activity_info" | cut -d' ' -f1)
    fi
    
    if [ -n "$latest_checkpoint_info" ]; then
        latest_checkpoint_time=$(echo "$latest_checkpoint_info" | cut -d' ' -f1)
    fi
    
    debug_log "ACTIVITY_OR_CHECKPOINT: activity_time=$latest_activity_time, checkpoint_time=$latest_checkpoint_time"
    
    # より新しい方を返す
    if [ $latest_activity_time -gt $latest_checkpoint_time ]; then
        debug_log "ACTIVITY_OR_CHECKPOINT: Using activity log (newer)"
        echo "$latest_activity_info"
    elif [ $latest_checkpoint_time -gt 0 ]; then
        debug_log "ACTIVITY_OR_CHECKPOINT: Using checkpoint log (newer)"
        echo "$latest_checkpoint_info"
    else
        debug_log "ACTIVITY_OR_CHECKPOINT: Using activity log (fallback)"
        echo "$latest_activity_info"
    fi
}

# 活動ログ作成頻度異常の判定（新機能 - v2）
# 意識レベル低下を検知（活動ログ・チェックポイントログの更新状況をチェック）
# 引数: current_time, warning_threshold, stop_threshold, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:diff=正常, 1:diff=警告, 2:diff=エラー）
check_consciousness_level_anomaly() {
    local current_time="$1"
    local warning_threshold="$2"
    local stop_threshold="$3"
    local heartbeat_start_time="$4"
    
    debug_log "CONSCIOUSNESS_LEVEL check started: current_time=$current_time"
    
    # 長時間処理宣言の期限チェック
    if check_extended_processing_deadline; then
        debug_log "CONSCIOUSNESS_LEVEL: Extended processing declared and valid, skipping check"
        echo "0:0"
        return 0
    fi
    debug_log "CONSCIOUSNESS_LEVEL thresholds: warning=${warning_threshold}s, stop=${stop_threshold}s"

    # 最新活動ログまたはチェックポイントログファイル情報を取得
    local latest_info=$(_get_latest_activity_or_checkpoint_info)
    
    # check_inactivity_anomalyと同じスコープでdiff変数を宣言
    local diff
    
    # 活動ログもチェックポイントログも存在しない場合の処理
    if [ -z "$latest_info" ]; then
        debug_log "CONSCIOUSNESS_LEVEL: No activity or checkpoint log files found, using heartbeat start time"
        diff=$((current_time - heartbeat_start_time))
    else
        # 最新ログの時刻とファイル名を取得
        local latest_time=$(echo "$latest_info" | cut -d' ' -f1)
        local latest_file=$(echo "$latest_info" | cut -d' ' -f2-)
        
        debug_log "CONSCIOUSNESS_LEVEL: Latest log: $(basename "$latest_file") at $latest_time"
        
        # 既存のcheck_inactivity_anomalyと同じロジックを適用
        if [ $latest_time -lt $heartbeat_start_time ]; then
            diff=$((current_time - heartbeat_start_time))
            debug_log "CONSCIOUSNESS_LEVEL: Using heartbeat start time as baseline (log older than heartbeat start)"
        else
            diff=$((current_time - latest_time))
            debug_log "CONSCIOUSNESS_LEVEL: Using log time as baseline"
        fi
    fi

    debug_log "CONSCIOUSNESS_LEVEL: Time difference = ${diff}s"

    # エラーコード付きで出力（誤使用防止のためreturnは常に0）
    if [ $diff -gt $stop_threshold ]; then
        debug_warning "CONSCIOUSNESS_LEVEL: Error level reached (${diff}s > ${stop_threshold}s)"
        echo "2:$diff"
         return 0
    elif [ $diff -gt $warning_threshold ]; then
        debug_log "CONSCIOUSNESS_LEVEL: Warning level reached (${diff}s > ${warning_threshold}s)"
        echo "1:$diff"
        return 0
    fi
    
    debug_log "CONSCIOUSNESS_LEVEL: Normal operation (${diff}s <= ${warning_threshold}s)"
    echo "0:$diff"
    return 0
}

# 最新テーマログファイル情報を取得するヘルパー関数
_get_latest_theme_log_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find ai-works/artifacts/theme_histories -name "*.md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find ai-works/artifacts/theme_histories -name "*.md" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -n 1
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
    local same_timestamp_count=$(find ai-works/artifacts/theme_histories -name "${timestamp_pattern}*.md" -type f 2>/dev/null | wc -l)
    
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

# 活動ログループ状態管理用のグローバル変数
ACTIVITY_LOG_LOOP_LAST_FILE=""
ACTIVITY_LOG_LOOP_LAST_MTIME=""
ACTIVITY_LOG_LOOP_COUNT=0

# 活動ログループ異常の判定（復活 - 手動編集による問題行動検知のため）
# 同一活動ログファイルの継続編集を検知してループ異常を判定
# 引数: current_time, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:count=正常, 2:count=エラー）
check_activity_log_loop_anomaly() {
    local current_time="$1"
    local heartbeat_start_time="$2"
    
    debug_log "ACTIVITY_LOG_LOOP check started: current_time=$current_time"
    debug_log "ACTIVITY_LOG_LOOP previous state: file=$ACTIVITY_LOG_LOOP_LAST_FILE, mtime=$ACTIVITY_LOG_LOOP_LAST_MTIME, count=$ACTIVITY_LOG_LOOP_COUNT"
    
    # 最新活動ログファイル情報を取得    
    local latest_activity_log_info=$(_get_latest_activity_log_info)
    
    if [ -z "$latest_activity_log_info" ]; then
        debug_log "ACTIVITY_LOG_LOOP: No activity log files found, clearing loop state"
        ACTIVITY_LOG_LOOP_LAST_FILE=""
        ACTIVITY_LOG_LOOP_LAST_MTIME=""
        ACTIVITY_LOG_LOOP_COUNT=0
        echo "0:0"
        return 0
    fi
    
    # ハートビート起動時刻以降に作成されたログのみを対象とする    
    local latest_log_time=$(echo "$latest_activity_log_info" | cut -d' ' -f1)
    if [ $latest_log_time -lt $heartbeat_start_time ]; then
        debug_log "ACTIVITY_LOG_LOOP: Latest log older than heartbeat start, clearing loop state"
        ACTIVITY_LOG_LOOP_LAST_FILE=""
        ACTIVITY_LOG_LOOP_LAST_MTIME=""
        ACTIVITY_LOG_LOOP_COUNT=0
        echo "0:0"
        return 0
    fi

    # 最新活動ログの時刻とファイル名を分離    
    local latest_activity_log_mtime=$(echo "$latest_activity_log_info" | cut -d' ' -f1)
    local latest_activity_log_file=$(echo "$latest_activity_log_info" | cut -d' ' -f2-)

    debug_log "ACTIVITY_LOG_LOOP: Current latest file: $latest_activity_log_file (mtime: $latest_activity_log_mtime)"
    
    # 前回と同じファイルかチェック
    if [ "$latest_activity_log_file" = "$ACTIVITY_LOG_LOOP_LAST_FILE" ]; then
        # 同じファイルの場合、更新時刻が変わったかチェック
        if [ "$latest_activity_log_mtime" != "$ACTIVITY_LOG_LOOP_LAST_MTIME" ]; then
            # 更新時刻が変わった場合、ループカウントをインクリメント
            ACTIVITY_LOG_LOOP_COUNT=$((ACTIVITY_LOG_LOOP_COUNT + 1))
            debug_log "ACTIVITY_LOG_LOOP: Same file updated, loop count incremented to $ACTIVITY_LOG_LOOP_COUNT"
            
            # 更新時刻を保存
            ACTIVITY_LOG_LOOP_LAST_MTIME="$latest_activity_log_mtime"
            
            # ループカウントが2以上でエラー（手動編集による問題行動として検知）
            if [ $ACTIVITY_LOG_LOOP_COUNT -ge 2 ]; then
                debug_warning "ACTIVITY_LOG_LOOP: Error level reached (loop count: $ACTIVITY_LOG_LOOP_COUNT)"
                echo "2:$ACTIVITY_LOG_LOOP_COUNT"
                return 0
            fi
        else
            # 更新時刻が同じ場合は何もしない
            debug_log "ACTIVITY_LOG_LOOP: Same file, same mtime, no change"
        fi
    else
        # 異なるファイルの場合、ループ状態をクリア
        debug_log "ACTIVITY_LOG_LOOP: Different file detected, clearing loop state"
        ACTIVITY_LOG_LOOP_LAST_FILE="$latest_activity_log_file"
        ACTIVITY_LOG_LOOP_LAST_MTIME="$latest_activity_log_mtime"
        ACTIVITY_LOG_LOOP_COUNT=0
    fi
    
    debug_log "ACTIVITY_LOG_LOOP: Updated state: file=$ACTIVITY_LOG_LOOP_LAST_FILE, mtime=$ACTIVITY_LOG_LOOP_LAST_MTIME, count=$ACTIVITY_LOG_LOOP_COUNT"
    debug_log "ACTIVITY_LOG_LOOP: Normal operation (loop count: $ACTIVITY_LOG_LOOP_COUNT)"
    echo "0:$ACTIVITY_LOG_LOOP_COUNT"
    return 0
}

# 重複した関数定義を削除（上部に移動済み）

# 最新の内省活動があった活動ログ情報を取得するヘルパー関数
_get_latest_introspection_info() {
    # "内省"という単語を含む活動ログファイルのリストを取得し、その中から最新のものを探す
    # `grep -l`でファイルリストを取得し、`xargs`で`stat`に渡す
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find ai-works/artifacts -path "*/histories/*.md" -type f -exec grep -l "内省" {} + 2>/dev/null | xargs -I {} stat -f "%m %N" {} 2>/dev/null | sort -nr | head -n 1
    else
        # Linux
        find ai-works/artifacts -path "*/histories/*.md" -type f -exec grep -l "内省" {} + 2>/dev/null | xargs stat -c "%Y %n" 2>/dev/null | sort -nr | head -n 1
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
        # 「内省」を含む活動ログが見つからない場合、ハートビート開始からの経過時間で判定
        introspection_diff=$((current_time - heartbeat_start_time))
        debug_log "INTROSPECTION_ACTIVITY: No activity logs with '内省' found, using heartbeat start time (${introspection_diff}s elapsed)"
    else
        # 最新の内省活動があった活動ログの更新時刻を取得
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
    
    debug_log "INTROSPECTION_ACTIVITY: Time difference = ${introspection_diff}s"
    
    # エラーコード付きで出力（誤使用防止のためreturnは常に0）
    # 通知(3) 警告(1) エラー(2)
    if [ $introspection_diff -gt $introspection_threshold ]; then
        debug_warning "INTROSPECTION_ACTIVITY: Error level reached (${introspection_diff}s > ${introspection_threshold}s)"
        echo "2:$introspection_diff"
    elif [ $introspection_diff -gt $((introspection_threshold * 2 / 3)) ]; then
        debug_log "INTROSPECTION_ACTIVITY: Warning level reached (${introspection_diff}s > $((introspection_threshold * 2 / 3))s)"
        echo "1:$introspection_diff"
    elif [ $introspection_diff -gt $((introspection_threshold / 2)) ]; then
        debug_log "INTROSPECTION_ACTIVITY: Info level reached (${introspection_diff}s > $((introspection_threshold / 2))s)"
        echo "3:$introspection_diff"
    else
        echo "0:$introspection_diff"
    fi
    debug_log "INTROSPECTION_ACTIVITY: Normal operation (${introspection_diff}s <= ${introspection_warning_threshold}s)"
    return 0
}

# 活動ログタイムスタンプ乖離異常の判定（新機能 - v2復活）
# 最新活動ログのファイル名に含まれるタイムスタンプが現在時刻から乖離していないかチェック
# 引数: current_time, warning_threshold, error_threshold, heartbeat_start_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:diff=正常, 1:diff=警告, 2:diff=エラー）
check_activity_log_timestamp_anomaly() {
    local current_time="$1"
    local warning_threshold="$2"
    local error_threshold="$3"
    local heartbeat_start_time="$4"

    debug_log "ACTIVITY_LOG_TIMESTAMP check started: current_time=$current_time"
    debug_log "ACTIVITY_LOG_TIMESTAMP thresholds: warning=${warning_threshold}s, error=${error_threshold}s"
    
    # 長時間処理宣言の期限チェック
    if check_extended_processing_deadline; then
        debug_log "ACTIVITY_LOG_TIMESTAMP: Extended processing declared and valid, skipping check"
        echo "0:0"
        return 0
    fi

    # 最新活動ログまたはチェックポイントログファイル情報を取得
    local latest_info=$(_get_latest_activity_or_checkpoint_info)

    if [ -z "$latest_info" ]; then
        debug_log "ACTIVITY_LOG_TIMESTAMP: No activity or checkpoint log files found"
        echo "0:0"
        return 0
    fi

    # 最新ログのファイル名を取得
    local latest_file=$(echo "$latest_info" | cut -d' ' -f2-)
    local latest_filename=$(basename "$latest_file")

    # ファイル名からタイムスタンプ部分を抽出（YYYYMMDDHHMMSS）
    local timestamp_pattern=""
    if [[ "$latest_filename" =~ ^([0-9]{14}) ]]; then
        timestamp_pattern="${BASH_REMATCH[1]}"
    else
        debug_log "ACTIVITY_LOG_TIMESTAMP: Could not extract timestamp from filename: $latest_filename"
        echo "0:0"
        return 0
    fi

    debug_log "ACTIVITY_LOG_TIMESTAMP: Extracted timestamp = $timestamp_pattern"

    # タイムスタンプを秒に変換
    local file_time=$(convert_timestamp_to_seconds "$timestamp_pattern")
    if [ -z "$file_time" ]; then
        debug_log "ACTIVITY_LOG_TIMESTAMP: Could not convert timestamp to seconds"
        echo "0:0"
        return 0
    fi

    # 現在時刻とファイル名タイムスタンプの差を計算
    local timestamp_diff
    if [ $file_time -lt $heartbeat_start_time ]; then
        # ファイル名タイムスタンプがハートビート起動前の場合、起動時刻を基軸とする
        timestamp_diff=$((current_time - heartbeat_start_time))
        debug_log "ACTIVITY_LOG_TIMESTAMP: Using heartbeat start time as baseline (file timestamp older than heartbeat start)"
    else
        timestamp_diff=$((current_time - file_time))
    fi
    debug_log "ACTIVITY_LOG_TIMESTAMP: Time difference = ${timestamp_diff}s"

    # 未来のタイムスタンプは即座にエラー
    if [ $timestamp_diff -lt 0 ]; then
        local future_seconds=$((-timestamp_diff))
        debug_warning "ACTIVITY_LOG_TIMESTAMP: Future timestamp detected (${future_seconds}s future) - immediate error"
        echo "2:$timestamp_diff"
        return 0
    fi

    # エラーコード付きで出力
    if [ $timestamp_diff -gt $error_threshold ]; then
        debug_warning "ACTIVITY_LOG_TIMESTAMP: Error level reached (${timestamp_diff}s > ${error_threshold}s)"
        echo "2:$timestamp_diff"
        return 0
    elif [ $timestamp_diff -gt $warning_threshold ]; then
        debug_log "ACTIVITY_LOG_TIMESTAMP: Warning level reached (${timestamp_diff}s > ${warning_threshold}s)"
        echo "1:$timestamp_diff"
        return 0
    fi

     debug_log "ACTIVITY_LOG_TIMESTAMP: Normal operation (${timestamp_diff}s <= ${warning_threshold}s)"
    echo "0:$timestamp_diff"
    return 0
}






# flexibleモードでのチェックポイント必須チェック関数
# 引数: current_time
# 戻り値: 常に0（エラーコードはecho出力に含める）
# 出力: "error_code:detail" 形式（0:0=正常, 1:elapsed_minutes=警告）
check_flexible_mode_checkpoint_requirement() {
    local current_time="$1"
    
    debug_log "FLEXIBLE_MODE_CHECKPOINT check started: current_time=$current_time"
    
    # アクティブなflexibleモードの深い作業宣言を検索
    local active_files=$(find ai-works/stats/deep_work -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f 2>/dev/null)
    
    if [ -z "$active_files" ]; then
        debug_log "FLEXIBLE_MODE_CHECKPOINT: No active deep work declarations"
        echo "0:0"
        return 0
    fi
    
    # 最新の宣言ファイルを取得
    local latest_declaration=$(echo "$active_files" | sort | tail -n 1)
    local heartbeat_id=$(basename "$latest_declaration" .txt)
    
    # 制限タイプを確認
    local restriction_type=$(grep "制限タイプ:" "$latest_declaration" 2>/dev/null | cut -d' ' -f2)
    
    if [ "$restriction_type" != "flexible" ]; then
        debug_log "FLEXIBLE_MODE_CHECKPOINT: Not flexible mode, skipping check"
        echo "0:0"
        return 0
    fi
    
    debug_log "FLEXIBLE_MODE_CHECKPOINT: Checking flexible mode declaration: $heartbeat_id"
    
    # 宣言開始時刻を取得
    local declaration_time=$(convert_timestamp_to_seconds "$heartbeat_id")
    if [ -z "$declaration_time" ]; then
        debug_warning "FLEXIBLE_MODE_CHECKPOINT: Invalid heartbeat ID format: $heartbeat_id"
        echo "0:0"
        return 0
    fi
    
    # 宣言以降のチェックポイントログを検索
    local recent_checkpoints=""
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            if [[ "$filename" =~ ^([0-9]{14})\.txt$ ]]; then
                local file_timestamp="${BASH_REMATCH[1]}"
                local file_time=$(convert_timestamp_to_seconds "$file_timestamp")
                if [ -n "$file_time" ] && [ $file_time -gt $declaration_time ]; then
                    if [ -z "$recent_checkpoints" ]; then
                        recent_checkpoints="$file_time $file"
                    else
                        recent_checkpoints="$recent_checkpoints"$'\n'"$file_time $file"
                    fi
                fi
            fi
        fi
    done < <(find ai-works/stats/checkpoints -name "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].txt" -type f 2>/dev/null)
    
    # 宣言からの経過時間を計算
    local elapsed_seconds=$((current_time - declaration_time))
    local elapsed_minutes=$((elapsed_seconds / 60))
    
    debug_log "FLEXIBLE_MODE_CHECKPOINT: Elapsed time since declaration: ${elapsed_minutes} minutes"
    
    # チェックポイントが作成されているかチェック
    if [ -n "$recent_checkpoints" ]; then
        debug_log "FLEXIBLE_MODE_CHECKPOINT: Checkpoints found after declaration"
        echo "0:0"
        return 0
    fi
    
    # 10分経過してもチェックポイントがない場合は警告
    if [ $elapsed_minutes -ge 10 ]; then
        debug_warning "FLEXIBLE_MODE_CHECKPOINT: No checkpoints for ${elapsed_minutes} minutes in flexible mode"
        echo "1:$elapsed_minutes"
        return 0
    fi
    
    debug_log "FLEXIBLE_MODE_CHECKPOINT: Normal operation (${elapsed_minutes} minutes elapsed)"
    echo "0:$elapsed_minutes"
    return 0
}