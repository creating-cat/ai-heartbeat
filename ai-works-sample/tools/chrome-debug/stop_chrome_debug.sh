#!/bin/bash

# Chrome リモートデバッグプロセス停止スクリプト

set -e

DEBUG_PORT=${1:-9222}
PID_FILE="/tmp/chrome_debug_${DEBUG_PORT}.pid"

echo "Chrome デバッグプロセスを停止しています..."

# PIDファイルから停止
if [[ -f "$PID_FILE" ]]; then
    CHROME_PID=$(cat "$PID_FILE")
    echo "PIDファイルから取得: $CHROME_PID"
    
    if kill -0 "$CHROME_PID" 2>/dev/null; then
        echo "プロセス $CHROME_PID を終了しています..."
        kill "$CHROME_PID"
        
        # 終了確認（最大10秒待機）
        for i in {1..10}; do
            if ! kill -0 "$CHROME_PID" 2>/dev/null; then
                echo "プロセスが正常に終了しました"
                break
            fi
            sleep 1
        done
        
        # 強制終了が必要な場合
        if kill -0 "$CHROME_PID" 2>/dev/null; then
            echo "強制終了を実行しています..."
            kill -9 "$CHROME_PID" 2>/dev/null || true
        fi
    else
        echo "プロセス $CHROME_PID は既に終了しています"
    fi
    
    rm -f "$PID_FILE"
else
    echo "PIDファイルが見つかりません: $PID_FILE"
fi

# ポートを使用しているプロセスを確認・停止
if lsof -ti:$DEBUG_PORT >/dev/null 2>&1; then
    echo "ポート $DEBUG_PORT を使用しているプロセスを停止しています..."
    PIDS=$(lsof -ti:$DEBUG_PORT)
    for pid in $PIDS; do
        echo "プロセス $pid を終了しています..."
        kill "$pid" 2>/dev/null || true
    done
    
    sleep 2
    
    # 強制終了が必要な場合
    if lsof -ti:$DEBUG_PORT >/dev/null 2>&1; then
        echo "強制終了を実行しています..."
        lsof -ti:$DEBUG_PORT | xargs kill -9 2>/dev/null || true
    fi
fi

# 一時ディレクトリのクリーンアップ
TEMP_DIRS=$(find /tmp -maxdepth 1 -name "chrome_debug_*" -type d 2>/dev/null || true)
if [[ -n "$TEMP_DIRS" ]]; then
    echo "一時ディレクトリをクリーンアップしています..."
    echo "$TEMP_DIRS" | xargs rm -rf
fi

echo "Chrome デバッグプロセスの停止が完了しました"