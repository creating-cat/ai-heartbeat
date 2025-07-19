# 活動ログ時間ベース制御への移行設計

## 概要

現在の活動ログ異常検知システムを、連番ベースの制御から時間ベースの制御に移行する設計文書。
「一回一歩」の原則を「1回のハートビートで1つの活動」から「適切な時間内での柔軟な活動」に変更し、
AIの自然な思考フローを尊重しながらシステムの安定性を保つことを目的とする。

## 背景・課題

### 現在の問題点

1. **過度に厳格な制限**
   - 1ハートビート = 1活動ログの厳格な制限
   - AIの自然な思考フロー（観測→思考→創造）を人為的に分断
   - 論理的に連続した処理でも異常として検知

2. **複雑な異常検知システム**
   - 活動ログパターン異常検知（同一タイムスタンプファイル数チェック）
   - 活動ログループ異常検知（同一ファイル連続編集チェック）
   - 連番生成時の警告システム
   - デバッグ・保守が困難

3. **技術的制約との不整合**
   - 真の問題は「長時間処理によるハートビート見逃し」
   - 連番の数ではなく、処理時間が本質的な制約要因

### システムの根本的制約

- AIエージェントは一つのタスク実行中は他のタスクを受け付けられない
- 長時間処理中はハートビートを複数回見逃し、「活動ログ頻度異常」が発生
- この制約が「小さな一歩」原則の論理的根拠

## 設計方針

### 基本原則の変更

**変更前**: 「1回のハートビートで1つの活動を行い、1つの活動ログを記録する」
**変更後**: 「適切な時間内で、自然な思考フローに基づく活動を行い、各活動でログを記録する」

### 制御方式の変更

**変更前**: 連番ベースの制御
- 2つ目の活動ログで警告
- 3つ目の活動ログでエラー

**変更後**: 時間ベースの制御
- 処理時間に基づく段階的警告
- ハートビート開始からの経過時間で判定

## 詳細設計

### 1. 時間閾値の設定

```bash
# 提案する時間制限
PROCESSING_TIME_INFO_THRESHOLD=300      # 5分で情報通知
PROCESSING_TIME_WARNING_THRESHOLD=600   # 10分で警告  
PROCESSING_TIME_ERROR_THRESHOLD=900     # 15分でエラー
```

### 2. MCPツール側の変更（activityLogTool.ts）

#### 2.1 時間ベース警告システムの実装

```typescript
function checkProcessingTime(heartbeatId: string): string | null {
  const heartbeatTime = convertTimestampToSeconds(heartbeatId);
  const currentTime = Math.floor(Date.now() / 1000);
  const elapsedMinutes = Math.floor((currentTime - heartbeatTime) / 60);
  
  if (elapsedMinutes >= 10) {
    return `⚠️ 長時間処理警告: ハートビート開始から${elapsedMinutes}分が経過しています。処理を区切ることを推奨します。`;
  } else if (elapsedMinutes >= 5) {
    return `ℹ️ 処理時間通知: ハートビート開始から${elapsedMinutes}分が経過しています。`;
  }
  
  return null;
}
```

#### 2.2 連番警告システムの削除

```typescript
// 削除対象
async function findAvailableSequence() {
  // 連番警告ロジックを削除
  // 単純にファイル存在チェックのみ実行
}

// 変更後
const timeWarning = checkProcessingTime(args.heartbeatId);
if (timeWarning) {
  responseText += `\n${timeWarning}`;
}
```

### 3. heartbeat.sh側の変更

#### 3.1 削除する異常検知機能

```bash
# 削除対象の関数呼び出し
# check_activity_log_pattern_anomaly()  # 活動ログパターン異常検知
# check_activity_log_loop_anomaly()     # 活動ログループ異常検知
```

#### 3.2 維持する異常検知機能

```bash
# 継続使用（時間制限の主要手段として活用）
check_activity_log_timestamp_anomaly()  # タイムスタンプ乖離異常検知
check_activity_log_frequency_anomaly()  # 活動ログ頻度異常検知
check_introspection_activity_anomaly()  # 内省活動異常検知
```

### 4. 戻り値コード体系の整理

#### 4.1 削除するコード

```bash
# 削除対象
# 13: 活動ログパターン異常
# 14: 活動ログループ異常
```

#### 4.2 維持するコード

```bash
# 継続使用
# 10-11: 活動ログ頻度異常（警告・エラー）
# 17-18: 内省活動異常（警告・エラー）
# 19-20: タイムスタンプ異常（警告・エラー）
```

## 段階的移行計画

### Phase 1: 警告システムの調整

#### 目標
- 既存システムを破壊せずに新しい警告システムを導入
- 動作確認と調整

#### 実装内容
1. **MCPツール側**
   - 時間ベース警告システムの実装
   - 連番警告の時間警告への置き換え
   - 既存の連番生成ロジックは維持（ファイル重複回避のため）

2. **heartbeat.sh側**
   - 活動ログパターン異常検知を警告レベルに緩和（エラーにしない）
   - 活動ログループ異常検知を警告レベルに緩和（エラーにしない）

#### 期間
- 実装: 1-2日
- 検証: 1週間

### Phase 2: 完全移行

#### 目標
- 新システムへの完全移行
- 不要な異常検知機能の削除

#### 実装内容
1. **heartbeat.sh側**
   - 活動ログパターン異常検知の完全削除
   - 活動ログループ異常検知の完全削除
   - 戻り値コード13, 14の削除

2. **設定ファイル更新**
   - `lib/config.sh`から不要なアドバイスメッセージ削除
   - ドキュメントの更新

3. **health_check_core.sh**
   - 不要な検知関数の削除
   - コードの簡素化

#### 期間
- 実装: 1日
- 検証: 1週間

## 期待される効果

### 1. 自然な動作の許可

**許可される動作例**:
```
ハートビート開始 (14:00:00)
├─ 観測活動 (14:02:00) - 活動ログ1作成
├─ 思考活動 (14:05:00) - 活動ログ2作成  
└─ 創造活動 (14:08:00) - 活動ログ3作成
総処理時間: 8分 → 正常動作として許可
```

**警告される動作例**:
```
ハートビート開始 (14:00:00)
├─ 長時間の分析処理...
└─ 活動ログ作成 (14:12:00)
総処理時間: 12分 → 長時間処理警告
```

### 2. システム安定性の維持

- 長時間処理による無活動異常は引き続き防止
- ハートビートのリズムは保持
- 技術的制約（ハートビート見逃し）への直接的対処

### 3. 運用の簡素化

- 複雑な異常検知ロジックの削減
- より直感的な制限システム
- デバッグ・トラブルシューティングの簡素化

### 4. AIの自律性向上

- 自然な思考フローの尊重
- 論理的に連続した処理の分断回避
- 効率的な処理の許可

## 長時間処理の事前宣言システム

### 背景・必要性

時間制限を導入することで、AIエージェントが正当な理由で長時間処理を行う必要がある場合に、
時間制限による異常検知を回避する仕組みが必要となる。

#### 正当な長時間処理のケース
- 大規模なファイル解析・変換
- 複雑なデータ構造の構築  
- システム的に中断できない一連の処理
- 緊急事態への対応

### 設計方針

#### 基本原則
- **事前宣言**: 長時間処理開始前に明示的に宣言
- **時間制限**: 最大30分までの制限
- **自動管理**: ファイルベースの簡単な制御
- **競合回避**: 専用ディレクトリによる名前空間分離

#### ファイルベース制御
- MCPツールに依存しない基本機能
- heartbeat.shから直接制御可能
- シンプルで確実な実装

### 実装仕様

#### ファイル構造
```bash
stats/
├── cooldown/                    # ツールクールダウン管理
├── lock/                       # ツールロック管理
├── extended_processing/        # 長時間処理宣言（新規）
│   └── current.conf           # 現在の宣言（固定ファイル名）
└── (その他の既存ファイル)
```

#### 宣言ファイル形式
```bash
# stats/extended_processing/current.conf
HEARTBEAT_ID=20250119143000
PLANNED_DURATION_MINUTES=15
REASON="大規模ログファイル分析"
```

#### heartbeat.sh側の実装
```bash
# 長時間処理宣言チェック関数
check_extended_processing_declaration() {
    local declaration_file="stats/extended_processing/current.conf"
    
    if [ ! -f "$declaration_file" ]; then
        return 1  # 宣言ファイルなし
    fi
    
    source "$declaration_file"
    
    # ハートビートIDチェック
    if [ "$HEARTBEAT_ID" != "$HEARTBEAT_START_TIMESTAMP" ]; then
        log_warning "Extended processing declaration is for different heartbeat: $HEARTBEAT_ID"
        rm "$declaration_file"  # 古い宣言を削除
        return 1
    fi
    
    # 時間チェック
    local start_time=$(convert_timestamp_to_seconds "$HEARTBEAT_ID")
    local current_time=$(date +%s)
    local planned_end_time=$((start_time + PLANNED_DURATION_MINUTES * 60))
    
    if [ $current_time -le $planned_end_time ]; then
        log_info "Extended processing active: ${PLANNED_DURATION_MINUTES}min, remaining $((planned_end_time - current_time))s"
        log_info "Reason: $REASON"
        return 0  # 宣言済み、時間内
    else
        log_warning "Extended processing time exceeded: planned ${PLANNED_DURATION_MINUTES}min"
        rm "$declaration_file"
        return 1  # 時間超過
    fi
}

# 異常検知関数の修正
check_activity_log_frequency_anomaly() {
    # 長時間処理宣言チェック
    if check_extended_processing_declaration; then
        debug_log "ACTIVITY_LOG_FREQUENCY: Extended processing declared, skipping check"
        echo "0:0"
        return 0
    fi
    
    # 既存のロジック...
}

check_activity_log_timestamp_anomaly() {
    # 長時間処理宣言チェック
    if check_extended_processing_declaration; then
        debug_log "ACTIVITY_LOG_TIMESTAMP: Extended processing declared, skipping check"
        echo "0:0"
        return 0
    fi
    
    # 既存のロジック...
}
```

#### MCPツールの実装
```typescript
export const declareExtendedProcessingTool = {
  name: 'declare_extended_processing',
  description: '長時間処理の事前宣言。時間制限による異常検知を一時的に無効化します。',
  input_schema: z.object({
    heartbeatId: z.string()
      .regex(/^\d{14}$/, 'ハートビートIDは14桁の数字（YYYYMMDDHHMMSS形式）である必要があります。'),
    plannedDurationMinutes: z.number()
      .min(1, '処理時間は1分以上である必要があります')
      .max(30, '処理時間は30分以下である必要があります'),
    reason: z.string()
      .min(5, '理由は5文字以上で入力してください')
  }),
  
  execute: async (args) => {
    try {
      const configContent = `# 長時間処理宣言ファイル
HEARTBEAT_ID=${args.heartbeatId}
PLANNED_DURATION_MINUTES=${args.plannedDurationMinutes}
REASON="${args.reason}"
`;
      
      const filePath = 'stats/extended_processing/current.conf';
      await fs.ensureDir('stats/extended_processing');
      await fs.writeFile(filePath, configContent, 'utf-8');
      
      return {
        content: [
          {
            type: 'text' as const,
            text: `長時間処理を宣言しました: ${filePath}
予定処理時間: ${args.plannedDurationMinutes}分
理由: ${args.reason}

この時間内は活動ログ頻度異常検知が無効化されます。`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text' as const,
            text: `エラーが発生しました: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
      };
    }
  },
} as const;
```

#### 使用フロー例
```
1. 長時間処理の必要性を認識
   「大規模なログファイル分析が必要です。推定15分かかります。」

2. 事前宣言の実行
   declare_extended_processing({
     heartbeatId: "20250119143000",
     plannedDurationMinutes: 15,
     reason: "大規模ログファイル分析"
   })

3. 長時間処理の実行
   「宣言完了。ログファイル分析を開始します。」
   [15分間の処理実行]

4. 活動ログの作成
   create_activity_log({...})
   「分析完了。活動ログを作成しました。」
```

#### 安全機能
- **自動クリーンアップ**: 異なるハートビートIDの宣言は自動削除
- **時間制限**: 最大30分までの制限
- **上書き方式**: 同一ハートビート内での再宣言は上書き

## リスク分析と対策

### 1. 長時間処理の増加リスク

**リスク**: AIが長時間処理を行いやすくなる可能性

**対策**:
- 事前宣言による明示的な意図表明
- 最大30分の時間制限
- 理由の記録による透明性確保
- 内省活動での処理時間評価の推奨

### 2. 完璧主義的行動の増加リスク

**リスク**: 「一度に多くをやろう」とする傾向の強まり

**対策**:
- 事前宣言の手間による心理的ハードル
- 時間制限による物理的な制約
- 内省活動での行動パターン評価
- ドキュメントでの適切な活動パターンの明示

### 3. 異常検知精度の低下リスク

**リスク**: 真の異常と正常な複数活動の区別困難

**対策**:
- 事前宣言による明確な区別
- 時間ベースの明確な基準設定
- 段階的な警告システムによる早期発見
- 内省活動での自己評価システム

### 4. システム競合リスク

**リスク**: stats配下の他の機能との競合

**対策**:
- 専用ディレクトリ（stats/extended_processing/）による名前空間分離
- 固定ファイル名（current.conf）による管理の簡素化
- 自動クリーンアップによる古いファイルの削除

## 成功指標

### 1. 技術指標

- ハートビート見逃し回数の減少
- 異常検知による回復処理の減少
- システム稼働時間の向上

### 2. 動作指標

- 自然な思考フロー（観測→思考→創造）の増加
- 論理的に連続した処理の完遂率向上
- 処理効率の向上

### 3. 品質指標

- 活動ログの質的向上
- 成果物の一貫性向上
- 長期的な学習・成長の継続性

## 関連ドキュメント

- `GEMINI.md` - 基本動作ルールの更新が必要
- `ai-docs/GUIDELINES.md` - 運用ガイドラインの更新が必要
- `ai-docs/OPERATION_DETAILS.md` - 運用詳細の更新が必要
- `ai-docs/TROUBLESHOOTING_GUIDE.md` - トラブルシューティングの更新が必要

## 実装チェックリスト

### Phase 1
- [ ] MCPツールの時間ベース警告システム実装
- [ ] 連番警告の時間警告への置き換え
- [ ] heartbeat.shの異常検知緩和
- [ ] 動作テスト・検証

### Phase 2  
- [ ] 不要な異常検知機能の削除
- [ ] 戻り値コード体系の整理
- [ ] 設定ファイルの更新
- [ ] ドキュメントの更新
- [ ] 最終動作テスト

### 完了後
- [ ] 運用開始
- [ ] 効果測定
- [ ] 必要に応じた調整