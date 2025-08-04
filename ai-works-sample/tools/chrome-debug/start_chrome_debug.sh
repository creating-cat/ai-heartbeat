#!/bin/bash

# Chrome リモートデバッグモード起動スクリプト（シンプル版）
# Chrome起動後、すぐにスクリプト終了

set -e

# 設定
DEBUG_PORT=${1:-9222}
USER_DATA_DIR="/tmp/chrome_debug_$$"
CHROME_BINARY=""

# Chrome実行ファイルの検出（macOS対応）
detect_chrome_binary() {
    local chrome_paths=(
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "/Applications/Chromium.app/Contents/MacOS/Chromium"
        "/usr/bin/google-chrome"
        "/usr/bin/chromium-browser"
        "/opt/google/chrome/chrome"
    )
    
    for path in "${chrome_paths[@]}"; do
        if [[ -x "$path" ]]; then
            CHROME_BINARY="$path"
            return 0
        fi
    done
    
    echo "エラー: Chrome/Chromiumが見つかりません" >&2
    echo "以下のパスを確認してください:" >&2
    printf '%s\n' "${chrome_paths[@]}" >&2
    return 1
}

# Chrome実行ファイルの検出
if ! detect_chrome_binary; then
    exit 1
fi

echo "Chrome リモートデバッグモードを起動しています..."
echo "デバッグポート: $DEBUG_PORT"
echo "Chrome実行ファイル: $CHROME_BINARY"
echo "ユーザーデータディレクトリ: $USER_DATA_DIR"

# 既存のChromeプロセスをチェック
if lsof -ti:$DEBUG_PORT >/dev/null 2>&1; then
    echo "警告: ポート $DEBUG_PORT は既に使用されています"
    echo "既存のプロセスを確認してください: lsof -ti:$DEBUG_PORT"
    exit 1
fi

# Chromeをリモートデバッグモードで起動（デーモン化）
"$CHROME_BINARY" \
    --remote-debugging-port=$DEBUG_PORT \
    --user-data-dir="$USER_DATA_DIR" \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --headless=new \
    >/dev/null 2>&1 &

CHROME_PID=$!

# プロセス起動確認
sleep 2
if ! kill -0 "$CHROME_PID" 2>/dev/null; then
    echo "エラー: Chrome の起動に失敗しました" >&2
    exit 1
fi

# プロセス情報をファイルに保存
PID_FILE="/tmp/chrome_debug_${DEBUG_PORT}.pid"
echo "$CHROME_PID" > "$PID_FILE"

# 一時ディレクトリ情報も保存（クリーンアップ用）
TEMP_DIR_FILE="/tmp/chrome_debug_${DEBUG_PORT}.tmpdir"
echo "$USER_DATA_DIR" > "$TEMP_DIR_FILE"

echo "Chrome プロセスが起動しました"
echo "プロセスID: $CHROME_PID"
echo "デバッグURL: http://localhost:$DEBUG_PORT"
echo "プロセスID情報を保存: $PID_FILE"
echo "一時ディレクトリ情報を保存: $TEMP_DIR_FILE"

echo ""
echo "=== 使用方法 ==="
echo "1. Puppeteerから接続: puppeteer.connect({browserURL: 'http://localhost:$DEBUG_PORT'})"
echo "2. DevToolsでデバッグ: http://localhost:$DEBUG_PORT"
echo "3. プロセス終了: ./stop_chrome_debug.sh $DEBUG_PORT"
echo ""
echo "Chrome デバッグモードが起動完了しました"
echo "このスクリプトは終了します。Chromeプロセスはバックグラウンドで継続実行中です。"