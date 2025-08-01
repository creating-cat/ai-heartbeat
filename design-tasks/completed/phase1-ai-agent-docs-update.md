# Phase 1: AIエージェント向けドキュメント更新

## 概要

ハートビート自律ポーリングシステムのPhase 1として、AIエージェント向けドキュメントを更新し、自律的なハートビート確認方法を説明する。MCPツールを使用せず、直接ファイル確認による方法で実装する。

## 背景

現在のAI心臓システムでは、AIエージェントがハートビート受信のために処理を中断する必要があり、思考の連続性が阻害されている。この問題を解決するため、AIエージェントが自律的にハートビート状態をファイル確認により把握できるよう、ドキュメントを更新する。

## 修正対象ファイル

### 1. `ai-works-lib/ai-docs/GUIDELINES.md` - 運用ガイドライン

**修正箇所**: 1.2 重要ルールの末尾に追記

**追加内容**:
```markdown
**ハートビート確認の選択肢**
ハートビートはシステムからのメッセージ受信の他に、`ai-works/stats/current_heartbeat_id.txt`ファイルを確認することでも取得できます。活動ログ記録前に確認することで、待機時間を短縮できます。
```

## 修正方針

### 基本アプローチ
ハートビート確認の選択肢として、ファイル確認方法をGUIDALINES.mdに軽く追記する。既存のメッセージ受信方式と併用可能な補助的な手段として位置づける。

## 期待される効果

### 実用的なメリット
- **待機時間の短縮**: 活動ログ記録前にファイル確認することで、メッセージ待機を回避
- **選択肢の提供**: 状況に応じてハートビート確認方法を選択可能

## 完了基準

### ドキュメント更新完了
- [ ] `GUIDELINES.md`の1.2重要ルールに軽い追記

### 内容確認
- [ ] 簡潔で分かりやすい説明
- [ ] 既存ドキュメントとの矛盾がない

## 次のステップ

この修正完了後、以下の展開が可能：
1. **Phase 2**: MCPツール実装による機能強化
2. **Phase 3**: 完全自律ポーリングシステムへの移行
3. **運用評価**: 実際の使用状況とフィードバック収集
4. **最適化**: 使用パターンに基づく改善

## 関連ファイル

- `design-tasks/heartbeat-autonomous-polling-system.md`: 全体設計
- `design-tasks/completed/20250724-heartbeat-file-writer-implementation.md`: ハートビートファイル実装
- `heartbeat.sh`: ハートビートファイル書き込み実装
- `ai-works/stats/current_heartbeat_id.txt`: 対象ファイル