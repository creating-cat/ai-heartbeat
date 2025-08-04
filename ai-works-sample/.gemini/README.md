# Gemini CLI設定サンプル

このディレクトリには、AI心臓システムで使用可能なGemini CLI設定のサンプルが含まれています。

## 設定ファイル

### `settings.json`
豊富なMCPサーバー設定例を含む完全版の設定ファイルです。

**含まれるMCPサーバー:**
- `puppeteer` - Puppeteerによるブラウザ自動化
- `creative-ideation-mcp` - 創造的アイデア生成支援
- `gemini-image-mcp-server` - Gemini画像処理機能
- `mult-fetch-mcp-server` - 多言語対応のWeb取得機能
- `ai-heartbeat-mcp` - AI心臓システム専用ツール

## 使用方法

### 1. 基本的な使用（推奨）
AI心臓システムの基本機能のみを使用する場合は、システムデフォルトの設定（`ai-works-lib/.gemini/settings.json`）をそのまま使用してください。

### 2. 拡張機能の追加
追加のMCPツールを使用したい場合は、このサンプル設定を参考にして設定を追加できます：

```bash
# 現在の設定をバックアップ
cp ai-works/.gemini/settings.json ai-works/.gemini/settings.json.backup

# サンプル設定から必要な部分をコピー
# （手動で必要なMCPサーバー設定を追加）
```

### 3. 完全版の使用
全てのMCPツールを使用したい場合：

```bash
# サンプル設定をコピー
cp ai-works-sample/.gemini/settings.json ai-works/.gemini/settings.json
```

## MCPサーバー詳細

### `puppeteer`
**用途**: Webスクレイピング、ブラウザ自動化
**インストール**: 自動（npx使用）
**設定**: 環境変数不要

### `creative-ideation-mcp`
**用途**: 創造的なアイデア生成、ブレインストーミング支援
**インストール**: 自動（npx使用）
**設定**: `GEMINI_API_KEY`環境変数が必要

### `gemini-image-mcp-server`
**用途**: 画像生成、画像解析
**インストール**: 自動（npx使用）
**設定**: `GEMINI_API_KEY`環境変数が必要

### `mult-fetch-mcp-server`
**用途**: 多言語対応のWeb取得、翻訳機能
**インストール**: 自動（npx使用）
**設定**: `MCP_LANG`で言語設定（デフォルト: en）

### `ai-heartbeat-mcp`
**用途**: AI心臓システム専用機能（活動ログ、テーマ管理等）
**インストール**: システムに含まれる
**設定**: 環境変数不要
**注意**: このツールはシステム動作に必須です

## 設定のカスタマイズ

### 環境変数の設定
```bash
# Gemini API Key（creative-ideation-mcp、gemini-image-mcp-server用）
export GEMINI_API_KEY="your-api-key-here"

# 多言語設定（mult-fetch-mcp-server用）
export MCP_LANG="ja"  # 日本語の場合
```

### タイムアウト設定
重い処理を行うMCPサーバーには適切なタイムアウト値を設定：

```json
{
  "timeout": 300000,  // 5分（ミリ秒）
  "trust": true
}
```

### 無効化
特定のMCPサーバーを一時的に無効にする場合：

```json
{
  "disabled": true
}
```

## トラブルシューティング

### よくある問題

#### 1. MCPサーバーが起動しない
```bash
# 手動でテスト実行
npx -y @creating-cat/creative-ideation-mcp

# 環境変数の確認
echo $GEMINI_API_KEY
```

#### 2. タイムアウトエラー
- `timeout`値を増加（デフォルト: 30秒）
- 重い処理の場合は300000（5分）を推奨

#### 3. 権限エラー
- `trust: true`の設定を確認
- npmの権限設定を確認

### ログ確認
```bash
# Gemini CLIのログ確認
gemini --verbose

# 個別MCPサーバーのテスト
node ../mcp/ai-heartbeat-mcp/dist/index.js
```

## 設計思想

### 段階的導入
1. **最小構成**: システム必須機能のみ（ai-heartbeat-mcp）
2. **基本構成**: よく使用される機能を追加
3. **完全構成**: 全ての利用可能機能

### パフォーマンス考慮
- 不要なMCPサーバーは無効化してリソース節約
- タイムアウト値の適切な設定
- 環境変数による動的設定

### 拡張性
- 新しいMCPサーバーの追加が容易
- 設定の部分的な適用が可能
- 環境に応じたカスタマイズ対応

## 注意事項

- **API Key管理**: 環境変数を使用し、設定ファイルに直接記載しない
- **リソース使用量**: 多数のMCPサーバーは起動時間とメモリ使用量に影響
- **ネットワーク**: 一部のMCPサーバーはインターネット接続が必要
- **更新**: MCPサーバーは自動更新されるため、動作が変わる可能性

## 関連ドキュメント

- [AI心臓システム概要](../../README.md)
- [MCPツール開発ガイド](../../mcp/ai-heartbeat-mcp/README.md)
- [Chrome デバッグツール](../tools/chrome-debug/README.md)