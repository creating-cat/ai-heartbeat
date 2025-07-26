---
inclusion: always
---

# AI心臓システム プロジェクト概要

## プロジェクトの目的
AI心臓システムは、AIの自律的思考・創造・成長を支援するフレームワークです。定期的な「ハートビート」によりAIの継続的な活動を促し、長期間にわたる自律的な進化を実現します。

## 技術スタック
- **Shell Script (Bash)**: メインシステム制御
- **tmux**: セッション管理（agent/heartbeat分離）
- **Gemini CLI**: AIエージェント実行環境
- **Node.js + TypeScript**: MCPツール開発
- **Model Context Protocol (MCP)**: AI支援ツール群

## システムアーキテクチャ

### 2セッション構成
- **agentセッション**: AIエージェント本体が動作
- **heartbeatセッション**: 定期的にハートビート信号を送信

### 主要スクリプト
- `setup.sh`: システム初期化・起動
- `heartbeat.sh`: ハートビート送信とヘルスチェック
- `stop.sh`: システム停止
- `restart.sh`: ハートビート再起動

### ライブラリ構成 (`lib/`)
- `config.sh`: 設定管理とアドバイスメッセージ定数
- `logging.sh`: ログ管理（色付き出力、ファイル出力）
- `utils.sh`: ユーティリティ関数（OS判定、時間処理）
- `agent_io.sh`: tmux経由のエージェント操作
- `health_check_core.sh`: 異常検知ロジック

## ディレクトリ構造

### システム管理
- `heartbeat.conf`: ハートビート設定
- `logs/`: ハートビートログ（自動クリーンアップ）
- `ai-works/stats/`: システム状態管理

### AI活動環境テンプレート
- `ai-works-lib/`: AI活動環境のテンプレート
- `ai-works-lib/GEMINI.md`: AI動作の基本ルール
- `ai-works-lib/.gemini/`: AI用Gemini CLI設定
- `ai-works-lib/ai-docs/`: AI向け詳細ドキュメント

### AI活動領域（setup.shで自動生成）
- `ai-works/artifacts/`: AI生成物・活動ログ（テーマ別・履歴管理）
- `ai-works/themebox/`: テーマ事前準備（draft/processed管理）
- `ai-works/feedbackbox/`: ユーザーフィードバック（緊急フィードバック対応）
- `ai-works/projects/`: 開発プロジェクト作業領域（独立git管理）

### ドキュメント
- `ai-works-lib/ai-docs/`: AI向け詳細運用ドキュメント
- `theme_sample/`: サンプルテーマファイル

### 開発ツール
- `mcp/ai-heartbeat-mcp/`: Model Context Protocol ツール群

## 重要な設計原則

### 自律性と継続性
- AIが人間の介入なしに長時間動作
- 60秒間隔のハートビートによる定期的な活動促進
- 異常検知と自動回復機能

### 段階的成長
- 持続可能な継続的な進歩の積み重ね
- テーマ中心の集中的探求活動
- 思考・観測・創造・内省の4つの活動種別

### 堅牢性
- 複数レベルの異常検知（頻度、パターン、ループ、内省不足、タイムスタンプ等）
- 最大3回の自動回復試行・5サイクル回復待機
- ログベースの状態追跡と問題診断
- feedbackbox緊急フィードバック機能（即座処理中断）