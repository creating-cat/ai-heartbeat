#!/bin/bash

# Chrome リモートデバッグプロセス状態確認スクリプト

set -e

DEBUG_PORT=${1:-9222}
PID_FILE="/tmp/chrome_debug_${DEBUG_PORT}.pid"

echo "=== Chrome デバッグプロセス状態確認 ==="
echo "デバッグポート: $DEBUG_PORT"
echo ""

# PIDファイルの確認
if [[ -f "$PID_FILE" ]]; then
    CHROME_PID=$(cat "$PID_FILE")
    echo "PIDファイル: $PID_FILE"
    echo "記録されたPID: $CHROME_PID"
    
    if kill -0 "$CHROME_PID" 2>/dev/null; then
        echo "プロセス状態: 実行中 ✓"
        
        # プロセス詳細情報
        echo ""
        echo "=== プロセス詳細 ==="
        ps -p "$CHROME_PID" -o pid,ppid,cpu,mem,etime,command 2>/dev/null || echo "プロセス情報の取得に失敗"
    else
        echo "プロセス状態: 停止済み ✗"
        echo "注意: PIDファイルは存在しますが、プロセスは実行されていません"
    fi
else
    echo "PIDファイル: 存在しません"
fi

echo ""

# ポート使用状況の確認
echo "=== ポート使用状況 ==="
if lsof -i:$DEBUG_PORT >/dev/null 2>&1; then
    echo "ポート $DEBUG_PORT: 使用中"
    echo ""
    echo "使用中のプロセス:"
    lsof -i:$DEBUG_PORT 2>/dev/null || echo "プロセス情報の取得に失敗"
else
    echo "ポート $DEBUG_PORT: 利用可能"
fi

echo ""

# デバッグエンドポイントの確認
echo "=== デバッグエンドポイント確認 ==="
if command -v curl >/dev/null 2>&1; then
    if curl -s "http://localhost:$DEBUG_PORT/json/version" >/dev/null 2>&1; then
        echo "デバッグエンドポイント: アクセス可能 ✓"
        echo "URL: http://localhost:$DEBUG_PORT"
        
        # バージョン情報取得
        VERSION_INFO=$(curl -s "http://localhost:$DEBUG_PORT/json/version" 2>/dev/null || echo "{}")
        if [[ "$VERSION_INFO" != "{}" ]]; then
            echo ""
            echo "Chrome情報:"
            echo "$VERSION_INFO" | python3 -m json.tool 2>/dev/null || echo "$VERSION_INFO"
        fi
    else
        echo "デバッグエンドポイント: アクセス不可 ✗"
    fi
else
    echo "デバッグエンドポイント: curl未インストールのため確認不可"
fi

echo ""

# 一時ディレクトリの確認
echo "=== 一時ディレクトリ ==="
TEMP_DIRS=$(find /tmp -maxdepth 1 -name "chrome_debug_*" -type d 2>/dev/null || true)
if [[ -n "$TEMP_DIRS" ]]; then
    echo "Chrome一時ディレクトリ:"
    echo "$TEMP_DIRS" | while read -r dir; do
        if [[ -d "$dir" ]]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "不明")
            echo "  $dir (サイズ: $SIZE)"
        fi
    done
else
    echo "Chrome一時ディレクトリ: なし"
fi

echo ""

# 使用方法の表示
echo "=== 使用方法 ==="
echo "起動: ./start_chrome_debug.sh [$DEBUG_PORT]"
echo "停止: ./stop_chrome_debug.sh [$DEBUG_PORT]"
echo "確認: ./check_chrome_debug.sh [$DEBUG_PORT]"
echo ""
echo "Puppeteer接続例:"
echo "const browser = await puppeteer.connect({"
echo "  browserURL: 'http://localhost:$DEBUG_PORT'"
echo "});"