# MCPツールの時間追跡機能強化

## 問題・目的

### 現状の問題
- **checkpointツールの使用頻度が低い**: 3つのcheckpointファイルのみ（活動ログは多数存在）
- **時間情報の不足**: 前回のcheckpointからの経過時間が分からない
- **処理時間の把握困難**: 実際の作業時間を測定する手段が限定的
- **活動パターンの分析不足**: AIの活動リズムや効率性を把握する情報が不十分

### 改善の目的
- checkpointツールの実用性向上と使用頻度増加
- 処理時間測定機能の提供
- AIの活動パターン分析支援
- 時間意識の向上による効率化促進

## 解決策

### 1. checkpointツールの機能拡張

#### 現状の出力
```
チェックポイントを作成しました
ハートビートID: 20250727022500
ファイル: ai-works/stats/checkpoints/20250727022500.txt
最後の活動ログから約8分が経過しています。
長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。
```

#### 改善後の出力

**通常ケース**:
```
チェックポイントを作成しました
ハートビートID: 20250727022500
ファイル: ai-works/stats/checkpoints/20250727022500.txt

最後の活動ログから約8分が経過しています。
前回のチェックポイントから約3分が経過しています。
前回のメッセージ: データベース設計開始

長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。
```

**初回チェックポイントの場合**:
```
チェックポイントを作成しました
ハートビートID: 20250727022500
ファイル: ai-works/stats/checkpoints/20250727022500.txt

最後の活動ログから約8分が経過しています。
初回のチェックポイントです。

長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。
```

**エラー時の出力**:
```
チェックポイントを作成しました
ハートビートID: 20250727022500
ファイル: ai-works/stats/checkpoints/20250727022500.txt

最後の活動ログから約8分が経過しています。
前回のチェックポイント情報の取得に失敗しました。

長時間の集中作業が見込まれる場合は、start_deep_workツールの使用を検討してください。
```

### 2. create_activity_logツールの機能拡張

#### 現状の出力（時間関連部分）
```
活動ログを作成しました: ai-works/artifacts/.../histories/20250727022500.md
ハートビートID: 20250727022500
テーマ: creating_card_battle_game (20250727015543)

経過時間通知: ハートビート開始から7分が経過しています。
```

#### 改善後の出力

**通常ケース**:
```
活動ログを作成しました: ai-works/artifacts/.../histories/20250727022500.md
ハートビートID: 20250727022500
テーマ: creating_card_battle_game (20250727015543)

前回の活動ログから約15分が経過しています。
最後のチェックポイントから約3分が経過しています。
最後のチェックポイント: データベース設計完了
```

**時間制限警告が必要な場合**:
```
活動ログを作成しました: ai-works/artifacts/.../histories/20250727022500.md
ハートビートID: 20250727022500
テーマ: creating_card_battle_game (20250727015543)

前回の活動ログから約15分が経過しています。
最後のチェックポイントから約3分が経過しています。
最後のチェックポイント: データベース設計完了

※ 長時間作業中です。適度な区切りでの活動ログ作成を推奨します。
```

## 実装詳細

### 対象ファイル
- `mcp/ai-heartbeat-mcp/src/tools/checkpointTool.ts`
- `mcp/ai-heartbeat-mcp/src/tools/activityLogTool.ts`
- `mcp/ai-heartbeat-mcp/src/lib/` (新規ユーティリティ関数)

### 新規作成ファイル
- `mcp/ai-heartbeat-mcp/src/lib/timeAnalysisUtils.ts` - 時間分析共通ユーティリティ

### 実装する機能

#### 1. 最新チェックポイント情報取得機能
```typescript
export async function getLatestCheckpointInfo(): Promise<LogInfo | null> {
  const checkpointDir = path.join(STATS_DIR, 'checkpoints');
  if (!await fs.pathExists(checkpointDir)) return null;
  
  const files = await fs.readdir(checkpointDir);
  const checkpointFiles = files
    .filter(f => /^\d{14}\.txt$/.test(f))
    .sort()
    .reverse();
    
  if (checkpointFiles.length === 0) return null;
  
  const latestFile = checkpointFiles[0];
  const heartbeatId = latestFile.replace('.txt', '');
  
  return {
    heartbeatId,
    filePath: path.join(checkpointDir, latestFile)
  };
}
```

#### 2. 統合時間分析メッセージ生成機能
```typescript
export async function generateTimeAnalysisMessage(
  currentHeartbeatId: string,
  includeActivityLog: boolean = true
): Promise<string> {
  const currentTime = convertTimestampToSeconds(currentHeartbeatId);
  const messages: string[] = [];
  
  try {
    // 前回の活動ログからの経過時間（活動ログ作成時のみ）
    if (includeActivityLog) {
      const latestLogInfo = await getLatestActivityLogInfo();
      if (latestLogInfo) {
        const logElapsedMinutes = Math.floor((currentTime - convertTimestampToSeconds(latestLogInfo.heartbeatId)) / 60);
        messages.push(`前回の活動ログから${formatElapsedTime(logElapsedMinutes)}が経過しています。`);
      } else {
        messages.push(`初回の活動ログです。`);
      }
    }
    
    // 最後のチェックポイントからの経過時間
    const latestCheckpointInfo = await getLatestCheckpointInfo();
    if (latestCheckpointInfo) {
      const checkpointElapsedMinutes = Math.floor((currentTime - convertTimestampToSeconds(latestCheckpointInfo.heartbeatId)) / 60);
      messages.push(`前回のチェックポイントから${formatElapsedTime(checkpointElapsedMinutes)}が経過しています。`);
      
      // チェックポイントの内容も表示（エラーハンドリング付き）
      try {
        const checkpointContent = await fs.readFile(latestCheckpointInfo.filePath, 'utf-8');
        const trimmedContent = checkpointContent.trim();
        if (trimmedContent) {
          messages.push(`前回のメッセージ: ${trimmedContent}`);
        }
      } catch (fileError) {
        // ファイル読み取りエラーは無視（メッセージ表示をスキップ）
      }
    } else {
      messages.push(`初回のチェックポイントです。`);
    }
  } catch (error) {
    // 全体的なエラーの場合
    messages.push(`前回のチェックポイント情報の取得に失敗しました。`);
  }
  
  return messages.length > 0 ? '\n' + messages.join('\n') : '';
}

// 時間制限警告の生成（簡素化版）
export async function generateTimeWarningMessage(heartbeatId: string): Promise<string> {
  try {
    // 深い作業宣言の確認
    const deepWorkDir = path.join(STATS_DIR, 'deep_work');
    const deepWorkFile = path.join(deepWorkDir, `${heartbeatId}.txt`);
    if (await fs.pathExists(deepWorkFile)) {
      return ''; // 宣言ファイルが存在する場合は警告を抑制
    }

    const heartbeatTime = convertTimestampToSeconds(heartbeatId);
    const currentTime = Math.floor(Date.now() / 1000);
    const elapsedSeconds = currentTime - heartbeatTime;
    
    if (elapsedSeconds >= 600) { // 10分
      return '\n※ 長時間作業中です。適度な区切りでの活動ログ作成を推奨します。';
    }
    
    return '';
  } catch (error) {
    return '';
  }
}

// 時間計算のヘルパー関数
function formatElapsedTime(minutes: number): string {
  if (minutes < 60) {
    return `約${minutes}分`;
  } else if (minutes < 1440) { // 24時間未満
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? `約${hours}時間${remainingMinutes}分` : `約${hours}時間`;
  } else {
    const days = Math.floor(minutes / 1440);
    return `約${days}日`;
  }
}
```

#### 3. checkpointTool.tsの修正
- `getElapsedTimeMessage`関数を`generateTimeAnalysisMessage`に置き換え
- チェックポイント間の経過時間表示を追加
- **パラメータ変更**: `current_activity` → `message`
- **パラメータ説明の更新**: 処理時間測定にも対応した内容に変更
- **ツール説明の更新**: 処理時間測定機能を明記

#### 4. activityLogTool.tsの修正
- `checkProcessingTime`の後に時間分析メッセージを追加
- 活動ログとチェックポイントの両方の経過時間を表示
- **表示方針の変更**: ハートビート開始からの経過時間表示を簡素化
- **時間制限警告**: 内部判定は継続、表示は簡潔なメッセージに変更

## 期待される効果

### 1. checkpointツールの使用頻度向上
- **処理時間測定**: 作業前後でcheckpointを使用して実際の処理時間を把握
- **進捗確認**: チェックポイント間の時間で作業効率を確認
- **時間意識の向上**: 具体的な数値による時間感覚の改善

### 2. 活動パターンの分析支援
- **活動間隔の把握**: 前回の活動ログからの時間で活動リズムを理解
- **実作業時間の測定**: チェックポイントからの時間で実際の作業効率を把握
- **効率化の促進**: 時間データによる自己改善の促進

### 3. 実用的な使用パターンの確立

#### パターン1: 処理時間測定
```
checkpoint(message="新機能の設計開始")
↓ (設計作業)
checkpoint(message="基本設計完了") → "前回のチェックポイントから15分が経過"
↓ (詳細設計)
create_activity_log(...) → "最後のチェックポイントから8分が経過"
```

#### パターン2: 学習・分析
```
checkpoint(message="複雑なコードの解析開始")
↓ (解析作業)
checkpoint(message="解析完了、理解度80%") → "前回のチェックポイントから12分が経過"
```

## ドキュメント修正方針

### 修正の背景
checkpointツールの機能拡張に伴い、関連ドキュメントでの記述を以下の観点で見直す必要があります：
1. **パラメータ変更**: `current_activity` → `message`
2. **理念・概念の見直し**: 補完的ツールから実用的ツールへの位置づけ変更
3. **使用場面の拡張**: 処理時間測定機能の追加

### 修正対象ファイルと内容

#### 1. ai-works-lib/GEMINI.md（高優先度）

**パラメータ記述の修正**:
```markdown
# 修正前
**作成方法**: `checkpoint(current_activity="現在の活動内容")`

# 修正後
**作成方法**: `checkpoint(message="現在の状況メッセージ")`
```

**理念・概念の修正**:
```markdown
# 修正前
- **チェックポイントログ**: 長時間処理中の軽量な活動記録（補完）

# 修正後
- **チェックポイントログ**: 活動の節目を記録し、処理時間測定と効率化分析を支援
```

**記載例の拡充**:
```markdown
# 修正前
**記載例**:
- "エラー原因の調査中"
- "創造活動の実行中"
- "データ分析処理中"

# 修正後
**記載例**:
- "エラー原因の調査開始"
- "エラー原因の調査完了"
- "創造活動実行中"
- "データ分析処理完了"
```

#### 2. ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md（高優先度）

**システム内での位置づけ見直し**:
```markdown
# 修正前（推定）
- **活動ログ**: 思考の「完成」を記録する詳細な成果記録
- **チェックポイントログ**: 思考の「継続」を証明する軽量な状況報告
- **補完の価値**: 両者が揃って初めて、完全で自然な活動記録となる

# 修正後
- **活動ログ**: 思考の成果と洞察を記録する詳細な成果記録
- **チェックポイントログ**: 活動の節目と時間を記録し、効率化を支援する実用的ツール
- **相互補完**: 「何を達成したか」（活動ログ）と「いつ、どのくらいの時間で」（チェックポイント）を記録し、包括的な活動支援を実現
```

**階層構造から並列構造への変更**:
```markdown
# 修正前
活動ログ（メイン）
└── チェックポイント（補完）

# 修正後
活動記録システム
├── 活動ログ（成果・洞察の記録）
└── チェックポイント（節目・時間の記録）
```

#### 3. ai-works-lib/ai-docs/BASIC_OPERATIONS.md（高優先度）

**パラメータ記述の修正**:
```markdown
# 修正前
checkpoint(current_activity="現在の活動内容を簡潔に記載")

# 修正後
checkpoint(message="現在の状況を簡潔に記載")
```

**使用タイミングの拡張**:
```markdown
# 修正前
### 作成タイミング
- 長時間処理や連続処理がひと段落した時
- 最後の活動ログまたはチェックポイントログから10分以内が目安
- まだ活動ログを記録する状況でない時

# 修正後
### 作成タイミング
- **処理時間測定**: 作業の開始・完了・中間地点での時間記録
- **効率化分析**: 作業パターンの分析と改善のための記録
- **活動継続証明**: 長時間処理中の意識的活動の証明
- **推奨間隔**: 最後の活動ログまたはチェックポイントから10分以内
```

**記載例の更新**:
```markdown
# 修正前
### 記載例
- "エラー原因の調査中"
- "創造活動の実行中"
- "データ分析処理中"
- "APIドキュメントの精読中"

# 修正後
### 記載例
- "エラー原因の調査開始"
- "エラー原因の調査完了"
- "創造活動実行中"
- "データ分析処理完了"
- "APIドキュメントの精読中"
```

#### 4. ai-works-lib/ai-docs/TOOL_USAGE.md（中優先度）

**ツール説明の拡充**:
```markdown
# 修正前
**目的**: 長時間処理中の軽量な活動証明
**使用場面**: 活動ログ作成までの間隔が長い場合

# 修正後
**目的**: 活動の節目記録と処理時間測定による効率化支援
**使用場面**: 
- 処理時間の測定と分析
- 作業効率の改善
- 長時間処理中の活動証明
```

**パラメータ記述の修正**:
```markdown
# 修正前
checkpoint({
  current_activity: "大規模ファイルの分析中"
})

# 修正後
checkpoint({
  message: "大規模ファイルの分析中"
})
```

#### 5. ai-works-lib/ai-docs/ADVANCED_FEATURES.md（中優先度）

**効率化機能としての記述追加**:
```markdown
# 新規追加
## チェックポイントによる効率化分析

### 処理時間測定機能
checkpointツールを活用することで、以下の効率化分析が可能になります：

**使用パターン**:
```
checkpoint(message="データベース設計開始")
↓ (設計作業)
checkpoint(message="データベース設計完了")
→ 出力: "前回のチェックポイントから15分が経過"
```

**分析可能な指標**:
- 類似作業の処理時間比較
- 作業効率の時系列変化
- 集中力の持続時間分析
```

### 修正の優先順位

#### Phase 1: 基本概念の修正（高優先度）
1. **GEMINI.md**: 基本概念とパラメータ記述の修正
2. **SYSTEM_PHILOSOPHY.md**: システム哲学での位置づけ見直し
3. **BASIC_OPERATIONS.md**: 使用タイミングとパラメータの修正

#### Phase 2: 詳細機能の記述（中優先度）
4. **TOOL_USAGE.md**: ツール説明の拡充とパラメータ修正
5. **ADVANCED_FEATURES.md**: 効率化機能としての記述追加

### 修正の一貫性確保

#### 用語の統一
- **修正前**: 「現在の活動内容」「軽量な記録」「補完的」
- **修正後**: 「現在の状況」「実用的ツール」「効率化支援」

#### 概念の統一
- **修正前**: 階層的関係（メイン vs 補完）
- **修正後**: 並列的関係（異なる目的を持つ独立したツール）

#### 価値提案の統一
- **修正前**: 活動証明のみ
- **修正後**: 活動証明 + 処理時間測定 + 効率化分析

## 完了の判断基準

### 実装完了
- [ ] `timeAnalysisUtils.ts`の作成と実装
- [ ] `checkpointTool.ts`の機能拡張
- [ ] `activityLogTool.ts`の機能拡張
- [ ] TypeScriptビルドの成功

### ドキュメント修正完了
- [ ] `GEMINI.md`の理念・概念・パラメータ修正
- [ ] `SYSTEM_PHILOSOPHY.md`の位置づけ見直し
- [ ] `BASIC_OPERATIONS.md`の使用タイミング・パラメータ修正
- [ ] `TOOL_USAGE.md`のツール説明拡充
- [ ] `ADVANCED_FEATURES.md`の効率化機能記述追加

### 動作確認

#### 基本機能テスト
- [ ] checkpointツールで前回のチェックポイントからの経過時間が表示される
- [ ] create_activity_logツールで活動ログとチェックポイントの経過時間が表示される
- [ ] 初回使用時の適切なメッセージ表示

#### エラーハンドリングテスト
- [ ] checkpointsディレクトリが存在しない場合の動作
- [ ] チェックポイントファイルが破損している場合の動作
- [ ] 無効なハートビートID形式での動作
- [ ] 未来のタイムスタンプでの動作
- [ ] 極端に古いタイムスタンプでの動作

#### パフォーマンステスト
- [ ] 大量のチェックポイントファイル（100個以上）での動作
- [ ] 連続実行時のレスポンス時間確認

#### 統合テスト
- [ ] checkpointツールとcreate_activity_logツールの連携動作
- [ ] 時間表示の一貫性確認
- [ ] deep_work宣言との連携確認

#### 時間表示方針テスト
- [ ] 通常時は前回の活動ログ・チェックポイントからの経過時間のみ表示
- [ ] 10分超過時のみ簡潔な時間制限警告が表示される
- [ ] deep_work宣言時は時間制限警告が抑制される
- [ ] 時間フォーマット関数の動作確認（分・時間・日の表示）

### 品質確認
- [ ] 出力メッセージの一貫性確認
- [ ] 時間計算の正確性確認
- [ ] 既存機能への影響がないことの確認
- [ ] パフォーマンスへの影響がないことの確認
- [ ] ドキュメント間の記述一貫性確認

## 注意点・リスク

### 技術的リスク
- **ファイルI/O増加**: チェックポイントファイルの読み取り処理が増加
- **エラーハンドリング**: ファイルが存在しない場合の適切な処理
- **時間計算の精度**: タイムスタンプ変換の正確性

### 具体的なエラーケースと対応

#### 1. チェックポイントファイル関連
- **ケース**: `stats/checkpoints/`ディレクトリが存在しない
- **対応**: 「初回のチェックポイントです」メッセージを表示

- **ケース**: チェックポイントファイルが破損している
- **対応**: ファイルを無視して「初回のチェックポイントです」を表示

- **ケース**: ファイル読み取り権限がない
- **対応**: エラーログを出力し、時間情報なしで継続

#### 2. 時間計算関連
- **ケース**: 無効なハートビートID形式
- **対応**: 時間計算をスキップし、基本情報のみ表示

- **ケース**: 未来のタイムスタンプ
- **対応**: 「時間計算エラー」として処理をスキップ

- **ケース**: 極端に古いタイムスタンプ（1年以上前など）
- **対応**: 「長期間経過」として特別なメッセージを表示

#### 3. パフォーマンス関連
- **ケース**: 大量のチェックポイントファイル（1000個以上）
- **対応**: 最新100個のみを対象として処理

### 設計上の考慮点
- **情報過多の回避**: 必要な情報のみを適切に表示
- **一貫性の維持**: 両ツール間での出力形式の統一
- **後方互換性**: 既存の機能への影響を最小化
- **グレースフルデグラデーション**: エラー時も基本機能は継続

### 時間表示の方針変更

#### 変更の背景
現在の実装では3つの時間情報を表示していますが、実用性の観点から見直しを行います：

1. **ハートビート開始からの経過時間**: システム制約との整合性は重要だが、AIにとっての実用性は限定的
2. **前回の活動ログからの経過時間**: 活動リズムの把握に有用
3. **最後のチェックポイントからの経過時間**: 実作業時間の測定に有用

#### 新しい表示方針

**create_activity_logツールの時間表示**:
- **メイン表示**: 前回の活動ログ・チェックポイントからの経過時間
- **システム警告**: 時間制限（10分）に達した場合のみ簡潔な警告を表示
- **内部処理**: ハートビート開始からの経過時間判定は継続（deep_work連携のため）

**表示例の比較**:
```
# 変更前
前回の活動ログから約15分が経過しています。
最後のチェックポイントから約3分が経過しています。
最後のチェックポイント: データベース設計完了
経過時間通知: ハートビート開始から7分が経過しています。

# 変更後（通常時）
前回の活動ログから約15分が経過しています。
最後のチェックポイントから約3分が経過しています。
最後のチェックポイント: データベース設計完了

# 変更後（時間制限警告時）
前回の活動ログから約15分が経過しています。
最後のチェックポイントから約3分が経過しています。
最後のチェックポイント: データベース設計完了
※ 長時間作業中です。適度な区切りでの活動ログ作成を推奨します。
```

#### 実装上の変更点
- `checkProcessingTime`関数の戻り値を簡素化
- 時間制限判定ロジックは維持（deep_work連携のため）
- 表示メッセージのみを実用性重視に変更

## パラメータ設計の詳細

### checkpointツールのパラメータ変更

#### 変更内容
- **変更前**: `current_activity` - 「簡潔な現在の活動内容」
- **変更後**: `message` - 「このチェックポイントの状況を表すメッセージ」

#### 変更理由
1. **汎用性の向上**: 現在の活動だけでなく、完了状況や進捗も表現可能
2. **処理時間測定への対応**: 開始・完了・中間状況を自然に表現
3. **直感性**: コミットメッセージのような親しみやすさ
4. **柔軟性**: 様々な使用場面に対応

#### 新しいパラメータ仕様
```typescript
const checkpointInputSchema = z.object({
  message: z.string().min(1, 'メッセージを記述してください')
    .describe('このチェックポイントの状況を表すメッセージ。作業の開始・完了・進捗・現在の活動内容など（例: 「データベース設計開始」「分析完了」「複雑な問題の調査中」）'),
});
```

#### 使用例の比較

**変更前（current_activity）**:
```typescript
checkpoint(current_activity="大規模ファイルの分析中")
checkpoint(current_activity="データベース設計の検討中")  // 完了を表現しにくい
```

**変更後（message）**:
```typescript
checkpoint(message="大規模ファイルの分析開始")
checkpoint(message="大規模ファイルの分析完了")
checkpoint(message="データベース設計検討中")
checkpoint(message="データベース設計完了")
checkpoint(message="テスト実行中")
checkpoint(message="バグ修正完了")
```

#### ツール説明の更新
```typescript
export const checkpointTool = {
  name: 'checkpoint',
  description: '活動の継続を示すチェックポイントを作成します。処理時間の測定、作業の区切り、長時間処理中の活動証明に使用できます。これにより無活動エラーを回避し、作業効率の分析も可能になります。',
  // ...
}
```

## 将来の拡張可能性

### 統計機能の追加
- 平均処理時間の計算
- 活動パターンの分析
- 効率性指標の提供

### 可視化機能
- 時間チャートの生成
- 活動履歴の可視化
- パフォーマンストレンドの表示

## 実装ステップ

### Phase 1: 基盤機能の実装

#### Step 1: 共通ユーティリティの作成
**対象**: `mcp/ai-heartbeat-mcp/src/lib/timeAnalysisUtils.ts`

**作業内容**:
1. `getLatestCheckpointInfo()`関数の実装
2. `generateTimeAnalysisMessage()`関数の実装
3. `generateTimeWarningMessage()`関数の実装
4. `formatElapsedTime()`ヘルパー関数の実装

**完了基準**:
- [ ] TypeScriptコンパイルエラーなし
- [ ] 各関数の基本動作確認
- [ ] エラーハンドリングの動作確認

#### Step 2: checkpointツールの機能拡張
**対象**: `mcp/ai-heartbeat-mcp/src/tools/checkpointTool.ts`

**作業内容**:
1. パラメータ名を`current_activity`から`message`に変更
2. パラメータ説明文の更新
3. `getElapsedTimeMessage()`を`generateTimeAnalysisMessage()`に置き換え
4. ツール説明文の更新（処理時間測定機能を明記）

**完了基準**:
- [ ] パラメータ変更の動作確認
- [ ] 前回のチェックポイントからの経過時間表示
- [ ] エラーケースでの適切な動作

#### Step 3: create_activity_logツールの機能拡張
**対象**: `mcp/ai-heartbeat-mcp/src/tools/activityLogTool.ts`

**作業内容**:
1. `generateTimeAnalysisMessage()`の統合
2. `generateTimeWarningMessage()`の統合
3. 既存の`checkProcessingTime()`の置き換え
4. 出力メッセージの構成変更

**完了基準**:
- [ ] 活動ログとチェックポイントの経過時間表示
- [ ] 時間制限警告の簡素化
- [ ] deep_work連携の継続動作

#### Step 4: ビルドとテスト
**対象**: MCPサーバー全体

**作業内容**:
1. TypeScriptビルドの実行
2. 基本機能テストの実行
3. エラーハンドリングテストの実行

**完了基準**:
- [ ] `npm run build`の成功
- [ ] 両ツールの基本動作確認
- [ ] エラーケースでの適切な動作

### Phase 2: ドキュメント修正

#### Step 5: 基本概念ドキュメントの修正
**対象**: `ai-works-lib/GEMINI.md`

**作業内容**:
1. checkpointツールの理念・概念の修正
2. パラメータ記述の更新
3. 記載例の拡充（開始・完了パターン）

**完了基準**:
- [ ] 「補完的ツール」から「実用的ツール」への位置づけ変更
- [ ] `message`パラメータの記述更新
- [ ] 処理時間測定機能の記載

#### Step 6: システム哲学ドキュメントの修正
**対象**: `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md`

**作業内容**:
1. checkpointツールのシステム内位置づけ見直し
2. 階層構造から並列構造への変更
3. 価値提案の更新

**完了基準**:
- [ ] 活動ログとの並列的関係の記述
- [ ] 効率化支援機能の明記
- [ ] システム全体での一貫性確保

#### Step 7: 基本操作ドキュメントの修正
**対象**: `ai-works-lib/ai-docs/BASIC_OPERATIONS.md`

**作業内容**:
1. パラメータ記述の更新
2. 使用タイミングの拡張
3. 記載例の更新

**完了基準**:
- [ ] `message`パラメータの記述統一
- [ ] 処理時間測定用途の追加
- [ ] 開始・完了パターンの記載例

#### Step 8: ツール使用ドキュメントの修正
**対象**: `ai-works-lib/ai-docs/TOOL_USAGE.md`

**作業内容**:
1. ツール説明の拡充
2. パラメータ記述の修正
3. 使用場面の拡張

**完了基準**:
- [ ] 効率化支援機能の記述
- [ ] `message`パラメータの更新
- [ ] 実用的な使用例の追加

#### Step 9: 高度機能ドキュメントの修正
**対象**: `ai-works-lib/ai-docs/ADVANCED_FEATURES.md`

**作業内容**:
1. 効率化機能としての記述追加
2. 処理時間測定パターンの説明
3. 分析可能な指標の記載

**完了基準**:
- [ ] 効率化分析セクションの追加
- [ ] 具体的な使用パターンの記載
- [ ] 時系列分析機能の説明

### Phase 3: 統合テストと品質確認

#### Step 10: 機能統合テスト
**作業内容**:
1. checkpointツールとcreate_activity_logツールの連携確認
2. 時間表示の一貫性確認
3. deep_work宣言との連携確認
4. エラーケースでの動作確認

**完了基準**:
- [ ] 両ツール間での時間情報の整合性
- [ ] deep_work宣言時の適切な動作
- [ ] エラー時のグレースフルデグラデーション

#### Step 11: パフォーマンステスト
**作業内容**:
1. 大量のチェックポイントファイルでの動作確認
2. 連続実行時のレスポンス時間測定
3. メモリ使用量の確認

**完了基準**:
- [ ] 100個以上のチェックポイントファイルでの正常動作
- [ ] レスポンス時間の許容範囲内での動作
- [ ] メモリリークの無いことの確認

#### Step 12: ドキュメント一貫性確認
**作業内容**:
1. 全ドキュメント間での記述一貫性確認
2. 用語統一の確認
3. 概念統一の確認

**完了基準**:
- [ ] パラメータ記述の統一
- [ ] 理念・概念の一貫性
- [ ] 使用例の整合性

### Phase 4: 最終確認とリリース準備

#### Step 13: 総合動作確認
**作業内容**:
1. 実際の使用シナリオでの動作確認
2. 処理時間測定機能の実用性確認
3. 既存機能への影響確認

**完了基準**:
- [ ] 処理時間測定パターンの動作確認
- [ ] 効率化分析機能の動作確認
- [ ] 既存機能の正常動作

#### Step 14: 最終品質チェック
**作業内容**:
1. コード品質の確認
2. ドキュメント品質の確認
3. テストカバレッジの確認

**完了基準**:
- [ ] TypeScriptの型安全性確認
- [ ] エラーハンドリングの完全性
- [ ] ドキュメントの完全性

### 実装時の注意点

#### 優先順位
1. **高優先度**: Phase 1（基盤機能）とStep 5-7（基本ドキュメント）
2. **中優先度**: Step 8-9（詳細ドキュメント）とPhase 3（テスト）
3. **低優先度**: Phase 4（最終確認）

#### 依存関係
- Step 1完了後にStep 2-3を並行実行可能
- Step 4完了後にPhase 2を開始
- Phase 2完了後にPhase 3を開始

#### リスク管理
- 各Stepで完了基準を満たしてから次に進む
- 問題発生時は前のStepに戻って修正
- 既存機能への影響を常に確認

この改善により、MCPツールがより実用的で価値のある時間追跡機能を提供し、AIの活動効率向上に大きく貢献することが期待されます。