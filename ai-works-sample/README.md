# サンプル・開発支援ツール集

このディレクトリには、AI心臓システムの使用例、サンプルファイル、開発支援ツールが含まれています。

## ディレクトリ構成

### `.gemini/`
Gemini CLI設定のサンプルです。豊富なMCPサーバー設定例が含まれています。

**主な内容:**
- `settings.json` - 完全版MCP設定（puppeteer、creative-ideation-mcp等）
- `README.md` - 各MCPサーバーの詳細説明と使用方法

**使用方法:**
```bash
# 拡張機能を使いたい場合
cp ai-works-sample/.gemini/settings.json ai-works/.gemini/settings.json
```

### `themebox/`
テーマファイルのサンプル集です。AI心臓システムでの活動テーマ作成時の参考として使用できます。

**含まれるサンプル:**
- `000_ai_heartbeat_tutorial.md` - AI心臓システムの基本チュートリアル
- `001_gemini_cli_builtin_tools_tutorial.md` - Gemini CLI組み込みツールの使用方法
- `002_generate_categories_tutorial.md` - カテゴリ生成のチュートリアル
- `003_localhost_debug_tutorial.md` - ローカルホストデバッグのチュートリアル
- `xxx_stop_heartbeat_for_snapshot.md` - スナップショット用ハートビート停止
- `zzz_summary_of_activities.md` - 活動サマリーの作成例

**使用方法:**
```bash
# AI心臓システムでテーマとして使用
cp ai-works-sample/themebox/000_ai_heartbeat_tutorial.md ai-works/themebox/
```

### `tools/`
開発・デバッグ支援ツール集です。AI心臓システムでの開発作業を効率化するためのスクリプトやユーティリティが含まれています。

#### `chrome-debug/`
Puppeteerを使用したWebスクレイピングやブラウザ自動化のデバッグ用Chromeリモートデバッグ環境を提供します。

**主な機能:**
- Chromeのリモートデバッグモード起動
- プロセス管理（起動・停止・状態確認）
- 自動クリーンアップ
- AIエージェント向けの明確な状態表示

**使用例:**
```bash
cd ai-works-sample/tools/chrome-debug
./start_chrome_debug.sh
# Puppeteerスクリプト実行
./stop_chrome_debug.sh
```

詳細は各ディレクトリのREADMEを参照してください。

## 設計思想

### 分離の原則
- **システム本体**: AI心臓システムの核となる機能
- **サンプル・ツール**: 参考例や開発支援（このディレクトリ）

### 拡張性
新しいサンプルやツールは以下の構造で追加できます：

```
ai-works-sample/
├── .gemini/           # Gemini CLI設定サンプル
│   ├── settings.json  # 完全版MCP設定
│   └── README.md      # MCP設定ガイド
├── themebox/          # テーマサンプル
├── tools/             # 開発支援ツール
│   ├── chrome-debug/  # Chromeデバッグツール
│   ├── new-tool/      # 新しいツール
│   └── ...
└── examples/          # その他の例（将来的な拡張）
```

### AIファースト設計
このディレクトリのツールは、AIエージェントが効率的に使用できるよう設計されています：

- **明確な状態表示**: プロセスID、ポート、URLの明示
- **予測可能な動作**: 一貫したファイル命名とクリーンアップ
- **段階的エラーハンドリング**: 問題の段階的な特定と回復
- **自動化支援**: スクリプト間の連携とプロセス管理

## 使用上の注意

- このディレクトリのファイルは**参考・例・支援**目的です
- 実際の使用時は適切な場所にコピーまたは参照してください
- ツールの使用前に各READMEを確認してください
- 開発環境に応じて設定の調整が必要な場合があります

## 貢献

新しいサンプルやツールの追加は歓迎します。以下の点を考慮してください：

- **汎用性**: 特定のプロジェクトに依存しない設計
- **ドキュメント**: 適切なREADMEとコメント
- **AIフレンドリー**: AIエージェントが理解・使用しやすい設計
- **一貫性**: 既存のパターンとの整合性