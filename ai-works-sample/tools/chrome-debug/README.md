# Chrome リモートデバッグスクリプト

AIエージェントがブラウザ自動化・デバッグ作業を効率的に行うためのスクリプト群です。

## スクリプト一覧

- `start_chrome_debug.sh`: リモートデバッグモードでChromeを起動
- `stop_chrome_debug.sh`: Chrome停止とクリーンアップ
- `check_chrome_debug.sh`: 状態確認とデバッグ情報表示

## 基本的な使用方法

### 1. Chrome起動
```bash
./start_chrome_debug.sh [ポート番号]
```
- リモートデバッグモードで起動します
- デフォルトポート: 9222
- 起動後すぐにスクリプト終了
- プロセスはバックグラウンドで継続実行

### 2. ブラウザ操作
- MCPツール（puppeteer等）を使用
- または直接的なブラウザ自動化ツール（Puppeteer、Playwright等）
- 接続先: `http://localhost:9222`

### 3. Chrome停止
```bash
./stop_chrome_debug.sh [ポート番号]
```

## 状態確認

```bash
./check_chrome_debug.sh [ポート番号]
```
プロセス状態、ポート使用状況、エンドポイント接続性を確認できます。

## 使用例

```bash
# Chrome起動
./start_chrome_debug.sh

# 30秒間のブラウザ操作（任意のツール）
timeout 30s [ブラウザ自動化ツールの実行]

# Chrome停止
./stop_chrome_debug.sh
```

## よくあるエラーと対処法

### ポートが既に使用されている
```bash
# 使用中のプロセスを確認
lsof -i:9222

# 強制停止
./stop_chrome_debug.sh 9222
```

### Chrome実行ファイルが見つからない
スクリプトは以下のパスを自動検出します：
- macOS: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
- Linux: `/usr/bin/google-chrome`, `/usr/bin/chromium-browser`

### プロセスが残存している
```bash
# 状態確認
./check_chrome_debug.sh

# 完全クリーンアップ
./stop_chrome_debug.sh
pkill -f "chrome.*remote-debugging"
```

## 重要な注意事項

- Chrome/Chromiumがシステムにインストールされている必要があります
- ヘッドレスモードで実行されるため、GUI操作はできません
- デバッグポートはローカルホスト（127.0.0.1）のみでリッスンします
- 一時ディレクトリは自動的にクリーンアップされます
