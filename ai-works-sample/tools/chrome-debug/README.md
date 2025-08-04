# Chrome リモートデバッグスクリプト

AIエージェントがpuppeteerでデバッグ作業を効率的に行うためのChromeリモートデバッグ環境を提供するスクリプト群です。

## スクリプト一覧

### `start_chrome_debug.sh`
Chromeをリモートデバッグモードでバックグラウンド起動します。

**使用方法:**
```bash
./start_chrome_debug.sh [ポート番号]
```

**例:**
```bash
# デフォルトポート(9222)で起動
./start_chrome_debug.sh

# カスタムポート(9223)で起動
./start_chrome_debug.sh 9223
```

**機能:**
- Chromeをヘッドレスモードで起動
- リモートデバッグポートを開放
- プロセスIDをファイルに保存
- 自動クリーンアップ機能
- シグナルハンドリング（Ctrl+C対応）

### `stop_chrome_debug.sh`
実行中のChromeデバッグプロセスを停止します。

**使用方法:**
```bash
./stop_chrome_debug.sh [ポート番号]
```

**機能:**
- PIDファイルからプロセスを特定・停止
- ポート使用プロセスの強制終了
- 一時ディレクトリのクリーンアップ

### `check_chrome_debug.sh`
Chromeデバッグプロセスの状態を確認します。

**使用方法:**
```bash
./check_chrome_debug.sh [ポート番号]
```

**確認項目:**
- プロセス実行状態
- ポート使用状況
- デバッグエンドポイントの接続性
- 一時ディレクトリの状況

## AIエージェント向け使用パターン

### 基本的な使用フロー

1. **Chrome起動**
```bash
cd ai-works-sample/tools/chrome-debug
./start_chrome_debug.sh
```

2. **Puppeteerから接続**
```javascript
const puppeteer = require('puppeteer');

const browser = await puppeteer.connect({
  browserURL: 'http://localhost:9222'
});

const page = await browser.newPage();
// デバッグ作業...

await browser.disconnect();
```

3. **状態確認（必要に応じて）**
```bash
./check_chrome_debug.sh
```

4. **Chrome停止**
```bash
./stop_chrome_debug.sh
```

### timeout実行での使用例

AIファーストな実装ガイドラインに従い、timeout実行での使用も可能です：

```bash
# 30秒間のデバッグセッション
timeout 30s ./start_chrome_debug.sh &
CHROME_PID=$!

# Puppeteerスクリプト実行
node your_debug_script.js

# 自動終了（timeoutにより）
```

### バックグラウンド実行での使用例

並行作業が必要な場合：

```bash
# Chrome起動（バックグラウンド）
./start_chrome_debug.sh &
SCRIPT_PID=$!
echo $SCRIPT_PID > /tmp/chrome_script_$$.pid

# 並行作業
node debug_script1.js
curl http://localhost:9222/json/list
node debug_script2.js

# 終了処理
./stop_chrome_debug.sh
kill $SCRIPT_PID 2>/dev/null || true
rm -f /tmp/chrome_script_$$.pid
```

## トラブルシューティング

### よくある問題

#### 1. ポートが既に使用されている
```bash
# 使用中のプロセスを確認
lsof -i:9222

# 強制停止
./stop_chrome_debug.sh 9222
```

#### 2. Chrome実行ファイルが見つからない
スクリプトが自動検出する標準パス：
- macOS: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
- Linux: `/usr/bin/google-chrome`, `/usr/bin/chromium-browser`

#### 3. プロセスが残存している
```bash
# 状態確認
./check_chrome_debug.sh

# 完全クリーンアップ
./stop_chrome_debug.sh
pkill -f "chrome.*remote-debugging"
```

### デバッグ情報

#### プロセス情報の確認
```bash
# Chrome関連プロセス
ps aux | grep chrome

# ポート使用状況
netstat -tlnp | grep 9222
```

#### ログ確認
スクリプトは標準出力にログを出力します。必要に応じてファイルに保存：

```bash
./start_chrome_debug.sh 2>&1 | tee chrome_debug.log
```

## 設計思想

このスクリプト群は以下の原則に基づいて設計されています：

### AIファースト設計
- **明確な状態表示**: プロセスID、ポート、URLを明示
- **予測可能な動作**: 一貫したファイル命名とクリーンアップ
- **エラーハンドリング**: 段階的な回復処理と明確なエラーメッセージ
- **自動化支援**: スクリプト間の連携とプロセス管理

### 堅牢性
- **リソース管理**: 一時ファイル・ディレクトリの自動クリーンアップ
- **プロセス管理**: 適切なシグナルハンドリングと終了処理
- **状態追跡**: PIDファイルによる確実なプロセス管理

### 使いやすさ
- **デフォルト値**: 一般的な設定での即座使用
- **柔軟性**: ポート番号等のカスタマイズ対応
- **情報提供**: 使用方法と接続情報の明示

## 注意事項

- Chrome/Chromiumがシステムにインストールされている必要があります
- ヘッドレスモードで実行されるため、GUI操作はできません
- デバッグポートは外部からアクセス可能なため、セキュリティに注意してください
- 長時間実行する場合は、適切なリソース監視を行ってください

## 拡張可能性

このスクリプト群は以下の拡張が可能です：

- **設定ファイル対応**: Chrome起動オプションの外部設定
- **ログ機能強化**: 詳細なデバッグログの出力
- **監視機能**: プロセス状態の定期監視
- **複数インスタンス**: 異なるポートでの並行実行
- **プロファイル管理**: 用途別のChromeプロファイル