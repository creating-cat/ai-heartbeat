# get_heartbeat_elapsed_time ツール設計書

## 概要

AIがハートビート活動時間を確認し、適切な時間管理を行うためのMCPツール。ハートビートIDを入力として、ハートビート開始時刻からの経過時間を返すとともに、経過時間に応じた段階的な警告・通知を提供する。

## 設計目標

### 1. 自己認識の向上
- AIが自分の処理時間を客観的に把握
- 長時間処理の自覚促進
- 適切なタイミングでの活動区切り判断支援

### 2. システム統合性
- 既存の `create_activity_log` ツールとの一貫性
- `heartbeat.sh` の異常検知システムとの相互補完
- 長時間処理宣言システムとの連携

### 3. AIファーストな設計
- 明確で構造化された情報提供
- 段階的な警告システム
- 具体的なアクション提案

## 機能仕様

### 入力パラメータ

```typescript
interface GetHeartbeatElapsedTimeInput {
  heartbeatId: string; // YYYYMMDDHHMMSS形式
}
```

### 出力形式

シンプルなJSON形式で必要最小限の情報を提供：

```json
{
  "elapsedSeconds": 300,
  "elapsedFormatted": "5分30秒",
  "warningMessage": null
}
```

- `elapsedSeconds`: 経過秒数（プログラム的な判断用）
- `elapsedFormatted`: 人間が読みやすい形式
- `warningMessage`: 警告がある場合のみメッセージ、なければ `null`

## 警告システム設計

### 警告レベルと閾値

`create_activity_log` ツールと完全に統一：

```typescript
const PROCESSING_TIME_CONFIG = {
  infoThreshold: 300,    // 5分で情報通知
  warningThreshold: 600, // 10分で警告（heartbeat.shのエラーレベルと統一）
};
```

### 段階的メッセージ設計

#### 1. 正常範囲（0-5分）
```json
{
  "elapsedSeconds": 195,
  "elapsedFormatted": "3分15秒",
  "warningMessage": null
}
```

#### 2. 情報通知（5-10分）
```json
{
  "elapsedSeconds": 450,
  "elapsedFormatted": "7分30秒",
  "warningMessage": "経過時間通知: ハートビート開始から7分が経過しています。"
}
```

#### 3. 警告（10分以上）
```json
{
  "elapsedSeconds": 765,
  "elapsedFormatted": "12分45秒",
  "warningMessage": "活動分割推奨: ハートビート開始から12分が経過しています。「小さな一歩」の原則に従い、活動を区切ることを推奨します。"
}
```

### 長時間処理宣言時の調整

`declare_extended_processing` が有効な場合は警告閾値を緩和し、メッセージで状態を通知：

```json
{
  "elapsedSeconds": 920,
  "elapsedFormatted": "15分20秒",
  "warningMessage": "長時間処理宣言中: 宣言により警告が緩和されています。"
}
```

## 技術実装詳細

### 1. 時間計算ロジック

```typescript
function calculateElapsedTime(heartbeatId: string): ElapsedTimeInfo {
  const heartbeatTime = convertTimestampToSeconds(heartbeatId);
  const currentTime = Math.floor(Date.now() / 1000);
  const elapsedSeconds = currentTime - heartbeatTime;
  const elapsedMinutes = Math.floor(elapsedSeconds / 60);
  
  return {
    elapsedSeconds,
    elapsedMinutes,
    elapsedFormatted: formatElapsedTime(elapsedSeconds)
  };
}

function formatElapsedTime(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  
  if (minutes === 0) {
    return `${remainingSeconds}秒`;
  } else if (remainingSeconds === 0) {
    return `${minutes}分`;
  } else {
    return `${minutes}分${remainingSeconds}秒`;
  }
}
```

### 2. 長時間処理宣言の確認

```typescript
async function checkExtendedProcessingDeclaration(): Promise<boolean> {
  const declarationFile = path.join(EXTENDED_PROCESSING_DIR, 'current.conf');
  return await fs.pathExists(declarationFile);
}
```

### 3. 警告メッセージ生成

`create_activity_log` と完全に同じロジック：

```typescript
async function generateWarningMessage(heartbeatId: string): Promise<string | null> {
  const heartbeatTime = convertTimestampToSeconds(heartbeatId);
  const currentTime = Math.floor(Date.now() / 1000);
  const elapsedSeconds = currentTime - heartbeatTime;
  const elapsedMinutes = Math.floor(elapsedSeconds / 60);
  
  // 長時間処理宣言の確認
  const declarationFile = path.join(EXTENDED_PROCESSING_DIR, 'current.conf');
  const hasDeclaration = await fs.pathExists(declarationFile);
  
  if (hasDeclaration) {
    // 宣言中は通常の警告を抑制し、宣言状態を通知
    return `長時間処理宣言中: 宣言により警告が緩和されています。`;
  }
  
  // 通常の警告処理
  if (elapsedSeconds >= PROCESSING_TIME_CONFIG.warningThreshold) { // 10分
    return `活動分割推奨: ハートビート開始から${elapsedMinutes}分が経過しています。「小さな一歩」の原則に従い、活動を区切ることを推奨します。`;
  } else if (elapsedSeconds >= PROCESSING_TIME_CONFIG.infoThreshold) { // 5分
    return `経過時間通知: ハートビート開始から${elapsedMinutes}分が経過しています。`;
  }
  
  return null;
}
```

### 4. エラーハンドリング

`create_activity_log` と完全に同じ検証ロジック：

#### 未来ハートビートID検証
```typescript
function validateHeartbeatIdTiming(heartbeatId: string): void {
  try {
    const heartbeatTime = convertTimestampToSeconds(heartbeatId);
    const currentTime = Math.floor(Date.now() / 1000);
    const timeDiff = heartbeatTime - currentTime;
    
    // 未来のタイムスタンプは即座にエラー
    if (timeDiff > 0) {
      const futureMinutes = Math.floor(timeDiff / 60);
      const futureSeconds = timeDiff % 60;
      const timeDescription = futureMinutes > 0 
        ? `${futureMinutes}分${futureSeconds}秒`
        : `${futureSeconds}秒`;
      
      throw new Error(
        `未来のハートビートIDは使用できません。\n` +
        `指定されたID（${heartbeatId}）は現在時刻より${timeDescription}未来です。\n` +
        `ハートビートIDは現在時刻またはそれ以前の時刻を使用してください。`
      );
    }
  } catch (error) {
    // convertTimestampToSecondsでエラーが発生した場合は、そのエラーを再スロー
    if (error instanceof Error && error.message.includes('Invalid timestamp format')) {
      throw error;
    }
    // 未来時刻検証エラーの場合もそのまま再スロー
    throw error;
  }
}
```

**未来ハートビートIDが指定された場合の動作：**
- 即座にエラーを投げて処理を停止
- 具体的な未来時間（X分Y秒未来）を表示
- 適切な使用方法を案内

## システム統合

### 1. create_activity_log との連携

- 同一の時間閾値設定を使用
- 一貫した警告メッセージ形式
- 長時間処理宣言の共通処理

### 2. heartbeat.sh との相互補完

| 監視方式 | 対象 | 検知内容 | 対応 |
|---------|------|---------|------|
| heartbeat.sh | 外部監視 | 活動ログ頻度異常 | 自動回復・停止 |
| MCPツール | 内部監視 | 処理時間超過 | 警告・推奨アクション |

### 3. 異常検知システムとの協調

`heartbeat.sh` の異常検知閾値と統一：
- 5分（300秒）: 情報通知 - `heartbeat.sh` の `INACTIVITY_WARNING_THRESHOLD` と統一
- 10分（600秒）: 警告 - `heartbeat.sh` の `INACTIVITY_STOP_THRESHOLD` 手前で警告

## 使用例

### 基本的な使用パターン

```typescript
// 正常範囲での確認
const result = await get_heartbeat_elapsed_time({ heartbeatId: "20250119143000" });
// → { elapsedSeconds: 150, elapsedFormatted: "2分30秒", warningMessage: null }

// 警告範囲での確認
const result = await get_heartbeat_elapsed_time({ heartbeatId: "20250119142000" });
// → { elapsedSeconds: 735, elapsedFormatted: "12分15秒", warningMessage: "活動分割推奨: ..." }

// 未来ハートビートIDでエラー
try {
  await get_heartbeat_elapsed_time({ heartbeatId: "20250119160000" }); // 未来の時刻
} catch (error) {
  // → Error: "未来のハートビートIDは使用できません。\n指定されたID（20250119160000）は現在時刻より15分30秒未来です。\nハートビートIDは現在時刻またはそれ以前の時刻を使用してください。"
}
```

### AIの自己管理フローでの活用

```typescript
// 1. 処理開始前の時間確認
const timeCheck = await get_heartbeat_elapsed_time({ heartbeatId: currentHeartbeatId });

// 2. シンプルで明確な判断
if (timeCheck.warningMessage || timeCheck.elapsedSeconds > 600) {
  // 活動を区切る判断
  await create_activity_log({
    heartbeatId: currentHeartbeatId,
    activityType: '思考',
    activityContent: ['時間制限により活動を区切り'],
    // ...
  });
} else {
  // 継続して作業
  console.log(`現在の経過時間: ${timeCheck.elapsedFormatted}`);
  // ...
}
```

## 期待される効果

### 1. AIの自律性向上
- 自分の処理時間への意識向上
- 適切なタイミングでの活動区切り
- 効率的な時間管理の習得

### 2. システム安定性向上
- 長時間処理による異常検知の予防
- 適切な処理分割の促進
- リソース使用量の最適化

### 3. ユーザビリティ向上
- 明確で段階的な警告システム
- 具体的なアクション提案
- 予測可能な動作パターン

## 今後の拡張可能性

### 1. 統計機能
- 平均処理時間の追跡
- 活動パターンの分析
- 効率性指標の提供

### 2. 学習機能
- 個別の処理パターン学習
- 動的な閾値調整
- パーソナライズされた推奨

### 3. 可視化機能
- 時間経過のグラフ表示
- 活動パターンの可視化
- パフォーマンス分析

## 実装優先度

### Phase 1: 基本機能
- [x] 時間計算ロジック
- [x] 基本的な警告システム
- [x] 長時間処理宣言との連携

### Phase 2: 高度な警告
- [x] 段階的警告メッセージ
- [x] 推奨アクションの提供
- [x] エラーハンドリングの強化

### Phase 3: システム統合
- [x] create_activity_log との統一
- [x] heartbeat.sh との協調
- [x] 異常検知システムとの連携

### Phase 4: 拡張機能
- [ ] 統計機能
- [ ] 学習機能
- [ ] 可視化機能

## 結論

`get_heartbeat_elapsed_time` ツールは、AIの自己管理能力を大幅に向上させる重要なコンポーネントです。既存システムとの統合性を保ちながら、AIファーストな設計原則に基づいた明確で実用的な機能を提供します。

このツールにより、AIは自分の処理時間を客観的に把握し、適切なタイミングで活動を区切ることができるようになり、システム全体の安定性と効率性が向上することが期待されます。