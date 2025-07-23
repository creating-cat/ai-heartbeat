# 未来ハートビートID検証機能 設計文書

## 概要

AIエージェントが未来の日時でハートビートIDを自作して活動ログを作成する問題を防ぐため、MCPツール側での事前検証機能を実装する。

## 問題の背景

### 発生した問題
- AIエージェントが独自に未来のハートビートID（YYYYMMDDHHMMSS形式）を生成
- 未来の日時で活動ログファイルを作成する異常行動が発生
- 現在のシステムでは未来タイムスタンプを「正常」として扱ってしまう

### 現在のチェック機能の限界
```bash
# health_check_core.shの問題箇所
if [ $timestamp_diff -lt 0 ]; then
    debug_log "ACTIVITY_LOG_TIMESTAMP: Future timestamp detected, skipping"
    echo "0:$timestamp_diff"  # 未来を正常として扱う
    return 0
fi
```

## 設計方針

### 1. 多層防御アプローチ
- **Primary Defense**: MCPツール側での事前検証（推奨）
- **Secondary Defense**: heartbeat.sh側での事後検知（補完）

### 2. MCPツール側検証の利点
- **根本的防止**: 不正ファイル作成前にブロック
- **即座のフィードバック**: AIへの学習効果が高い
- **システム整合性**: 不正データによる汚染を防止
- **処理効率**: 無駄な処理を事前に排除

## 実装設計

### 1. MCPツール側実装（Primary）

#### 実装箇所
- `mcp/ai-heartbeat-mcp/src/tools/activityLogTool.ts`
- `execute`関数内での事前検証

#### 検証ロジック
```typescript
function validateHeartbeatIdTiming(heartbeatId: string): void {
  const heartbeatTime = convertTimestampToSeconds(heartbeatId);
  const currentTime = Math.floor(Date.now() / 1000);
  const timeDiff = heartbeatTime - currentTime;
  
  const FUTURE_TOLERANCE_SECONDS = 300; // 5分の許容範囲
  
  if (timeDiff > FUTURE_TOLERANCE_SECONDS) {
    const futureMinutes = Math.floor(timeDiff / 60);
    throw new Error(`未来のハートビートIDは使用できません。指定されたID（${heartbeatId}）は現在時刻より${futureMinutes}分未来です。`);
  }
}
```

#### 実装フロー
1. Zodバリデーション後、最初に時間検証を実行
2. 未来IDの場合は即座にエラーを返す
3. 許容範囲内の場合は既存処理を継続

### 2. heartbeat.sh側実装（Secondary）

#### 既存機能の修正
- `check_activity_log_timestamp_anomaly`関数の未来タイムスタンプ処理を修正
- 未来タイムスタンプを異常として検知するよう変更

#### 検知レベル設定
```bash
FUTURE_TOLERANCE_SECONDS=300  # 5分以内の未来は許容
FUTURE_WARNING_THRESHOLD=900  # 15分以上の未来で警告
FUTURE_ERROR_THRESHOLD=1800   # 30分以上の未来でエラー
```

## 設定パラメータ

### 許容範囲の設定理由
- **5分許容**: システム時刻のわずかなズレを考慮
- **段階的警告**: 軽微な未来（5-15分）→ 明らかな未来（15分以上）
- **エラー閾値**: 30分以上の未来は明らかに異常

### 設定値
```typescript
const FUTURE_VALIDATION_CONFIG = {
  toleranceSeconds: 300,    // 5分以内の未来は許容
  warningThreshold: 900,    // 15分以上で警告
  errorThreshold: 1800,     // 30分以上でエラー
};
```

## エラーメッセージ設計

### MCPツール側エラーメッセージ
```typescript
// 明確で教育的なエラーメッセージ
`未来のハートビートIDは使用できません。
指定されたID（${heartbeatId}）は現在時刻より${futureMinutes}分未来です。
ハートビートIDは現在時刻またはそれ以前の時刻を使用してください。`
```

### heartbeat.sh側警告メッセージ
```bash
INACTIVITY_WARNING_MESSAGE="未来ハートビートID警告: 活動ログに未来のハートビートID（${futureMinutes}分先）が検出されました。
ハートビートIDは現在時刻またはそれ以前の時刻を使用する必要があります。"
```

## 実装優先度

### Phase 1: MCPツール側実装（高優先度）
- `activityLogTool.ts`での事前検証機能
- 即座のエラーフィードバック
- 不正ファイル作成の根本的防止

### Phase 2: heartbeat.sh側実装（中優先度）
- 既存チェック機能の修正
- 事後検知による補完機能
- 監査・ログ機能の強化

### Phase 3: 設定の最適化（低優先度）
- 許容範囲の調整
- エラーメッセージの改善
- 統計情報の収集

## 期待される効果

### 1. 問題の根本的解決
- 未来ハートビートIDの使用を事前に防止
- AIエージェントの時間感覚の正常化
- システムの時系列整合性の保証

### 2. システムの信頼性向上
- 不正データによる汚染の防止
- 活動ログの品質向上
- 異常検知システムの精度向上

### 3. AIエージェントの学習効果
- 即座のエラーフィードバックによる学習促進
- 適切な時間概念の習得
- システムルールの理解向上

## 実装時の注意点

### 1. 既存機能への影響
- 既存の時間ベース制御機能との整合性確保
- 長時間処理宣言機能との連携
- エラーハンドリングの統一

### 2. テスト要件
- 境界値テスト（許容範囲の境界）
- タイムゾーン考慮テスト
- システム時刻変更時の動作確認

### 3. 運用考慮事項
- エラーログの監視
- 誤検知の可能性への対応
- 設定値の調整機能

## 関連ドキュメント

- `ai-docs/OPERATION_DETAILS.md`: 活動ログ記録の詳細手順
- `ai-docs/TROUBLESHOOTING_GUIDE.md`: 異常検知対応ガイド
- `ai-docs/MCP_WARNING_GUIDE.md`: MCPツール警告対応
- `lib/health_check_core.sh`: 異常検知コアライブラリ
- `mcp/ai-heartbeat-mcp/src/tools/activityLogTool.ts`: 活動ログ作成ツール

## 実装チェックリスト

### MCPツール側
- [ ] `validateHeartbeatIdTiming`関数の実装
- [ ] `activityLogTool.execute`への検証処理追加
- [ ] エラーメッセージの実装
- [ ] 設定値の定数化
- [ ] テストケースの作成

### heartbeat.sh側
- [ ] `check_activity_log_timestamp_anomaly`の修正
- [ ] 未来タイムスタンプ検知ロジックの追加
- [ ] 警告メッセージの実装
- [ ] 設定値の外部化
- [ ] ログ出力の改善

### 統合テスト
- [ ] MCPツールとheartbeat.shの連携確認
- [ ] エラーケースでの動作確認
- [ ] 正常ケースでの影響確認
- [ ] パフォーマンステスト
- [ ] 運用テスト

## まとめ

この設計により、AIエージェントの未来ハートビートID使用問題を根本的に解決し、システムの時系列整合性と信頼性を大幅に向上させることができる。MCPツール側での事前検証を主軸とし、heartbeat.sh側での事後検知で補完する多層防御アプローチにより、堅牢で信頼性の高いシステムを実現する。