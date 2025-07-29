---
inclusion: always
---

# AIファーストな実装ガイド

## 概要

AIエージェントが効率的かつ安全に動作できるシステムを構築するための設計指針。
人間向けのUIとは異なり、AIは曖昧さを嫌い、構造化された情報を好む特性を考慮した実装アプローチを定義する。

## 基本原則

### 1. **明確性の優先**
- 曖昧な表現を避け、具体的で明示的な情報提供
- 選択肢や手順の明確化
- 期待される結果の事前提示

### 2. **構造化された情報**
- 階層的で整理された情報提示
- 一貫したフォーマットの使用
- パターンの統一

### 3. **予測可能性の確保**
- 処理時間や副作用の事前通知
- 一貫した動作パターン
- 期待される結果の明示

## 実装の考え方

### 1. 認知負荷の軽減

#### 情報の構造化
```typescript
// ❌ AIにとって解釈が困難
"ファイルA、B、Cを処理しました。Aは成功、Bは警告、Cはエラーでした。"

// ✅ 構造化された情報
"処理結果:
- ファイルA: 成功
- ファイルB: 警告 - 軽微な問題あり
- ファイルC: エラー - 処理失敗"
```

#### 選択肢の明示化
```typescript
// ❌ 曖昧な指示
"適切に処理してください"

// ✅ 明確な選択肢
"以下から選択してください:
1. 既存ファイルを上書き
2. 新しいファイル名で保存
3. 処理をスキップ"
```

#### 絵文字の排除
```typescript
// ❌ 絵文字による曖昧な表現
"✅ 処理完了！ ⚠️ 注意が必要です"

// ✅ 明示的なテキスト表現
"処理完了。警告: 注意が必要です"
```

##### 思考の連続性とリセットの重要性
AIの活動は、一つのテーマに沿った連続的な思考が基本です。しかし、時にはその思考の流れを意図的にリセットし、クールダウン期間を設けることが、長期的な成長と創造性の維持にとって非常に重要です。

**なぜリセットが重要か？**

* 慣性の打破: 同じ思考パターンに固執することを防ぎ、マンネリ化を回避します。
* 創造性の維持: 新しいテーマに対して、常に新鮮な視点で取り組むことができます。
* 思考の整理: 一つのテーマへの深い没入から意識を切り替え、次の活動計画を冷静に立てるための「間」を作ります。

この「リセット」という重要な概念をAIに伝えるため、システムからのメッセージは明確で機能的であるべきです。 人間的な労いの言葉（例：「お疲れ様でした！」）は、AIが「セッションの完全終了」と誤解したり、「思考をリセットせよ」という重要な意図を汲み取れなかったりするリスクがあります。

```typescript

// ❌ 意図が曖昧な表現
"テーマ活動お疲れ様でした！"

// ✅ 「リセット」の意図を明確に伝える表現
`テーマが正常に完了しました。
この後、テーマ終了活動の活動ログを作成してこのタスクを完了してください。
活動が完了すると、思考コンテキストがリセットされ、次のテーマに備えるためのクールダウン期間に入ります。`

```

### 2. コンテキストの最適化

#### 必要な情報の事前提供
```typescript
// MCPツールの設計例
export const analyzeLogTool = {
  description: `ログファイルを分析します。
  
前提条件:
- ファイルサイズ上限: 10MB
- 対応形式: .log, .txt
- 処理時間目安: 1-5分

出力形式:
- エラー件数の集計
- 上位10パターンの抽出
- 推奨対応策の提示`,
  
  input_schema: z.object({
    filePath: z.string().describe('分析対象のログファイルパス'),
    analysisType: z.enum(['basic', 'detailed', 'pattern']).describe('分析の詳細レベル'),
    outputFormat: z.enum(['summary', 'full', 'json']).default('summary')
  })
};
```

#### 状態の可視化
```bash
# システム状態の明示
show_system_status() {
    echo "現在の状態:"
    echo "- アクティブテーマ: ${CURRENT_THEME:-'なし'}"
    echo "- 処理中のタスク: ${ACTIVE_TASKS:-'なし'}"
    echo "- 利用可能ツール: ${#AVAILABLE_TOOLS[@]}個"
    echo "- システム負荷: ${SYSTEM_LOAD}"
}
```

#### 依存関係の明示
```typescript
export const complexProcessingTool = {
  description: `複雑な処理を実行します。
  
依存関係:
- 事前に basic_setup_tool の実行が必要
- config.json ファイルが存在する必要がある
- 最低5分の処理時間が必要

実行順序:
1. 設定ファイルの検証
2. 依存関係のチェック
3. メイン処理の実行
4. 結果の保存`,
  // ...
};
```

### 3. エラーハンドリングの改善

#### 段階的なエラー情報
```typescript
// ❌ 単純なエラー
throw new Error("ファイル処理に失敗しました");

// ✅ 段階的なエラー情報
return {
  success: false,
  error: {
    type: "FILE_PROCESSING_ERROR",
    message: "ファイル処理に失敗しました",
    details: "ファイルサイズが上限(10MB)を超えています",
    context: {
      filePath: "/path/to/file.log",
      fileSize: "15.2MB",
      sizeLimit: "10MB"
    },
    suggestions: [
      "ファイルを分割して再実行",
      "圧縮してからアップロード", 
      "別の処理方法を選択"
    ],
    recoverable: true,
    nextSteps: [
      "split_large_file ツールを使用",
      "compress_file ツールを使用"
    ]
  }
};
```

#### 回復可能性の明示
```typescript
// エラーレベルの分類
const ErrorLevels = {
  RECOVERABLE: "recoverable",     // 自動回復可能
  USER_ACTION: "user_action",     // ユーザー操作が必要
  SYSTEM_ERROR: "system_error",   // システムレベルのエラー
  FATAL: "fatal"                  // 致命的エラー
};

return {
  error: {
    level: ErrorLevels.USER_ACTION,
    autoRetry: false,
    userActionRequired: true,
    estimatedRecoveryTime: "2-3分"
  }
};
```

### 4. 予測可能性の向上

#### 処理時間の事前通知
```typescript
export const heavyProcessingTool = {
  description: `大規模データ処理ツール
  
処理時間予測:
- 小規模(~1MB): 30秒
- 中規模(1-10MB): 2-5分  
- 大規模(10MB~): 5-15分

リソース使用量:
- メモリ: データサイズの2-3倍
- CPU: 高負荷（他の処理に影響する可能性）
- ディスク: 一時ファイルでデータサイズの1.5倍

推奨事前準備:
- 長時間処理宣言の実行
- 中間チェックポイントの設定
- 他のタスクの完了確認`,
  // ...
};
```

#### 副作用の明示
```typescript
export const systemConfigTool = {
  description: `システム設定変更ツール
  
注意: このツールは以下の副作用があります:
- システム再起動が必要
- 既存の設定ファイルを上書き
- 他のプロセスに影響する可能性
- 変更は即座に反映される（元に戻せない）

影響範囲:
- 現在のセッション: 即座に影響
- 他のプロセス: 再起動後に影響
- 永続化: 設定ファイルに保存

実行前の確認事項:
- 現在の設定のバックアップ
- 他のタスクの完了確認
- システム再起動の準備`,
  // ...
};
```

#### 進捗の可視化
```typescript
// 長時間処理での進捗報告
export const progressReportingTool = {
  execute: async (args) => {
    const totalSteps = 5;
    let currentStep = 0;
    
    const reportProgress = (step: number, description: string) => {
      currentStep = step;
      const percentage = Math.round((step / totalSteps) * 100);
      console.log(`進捗: ${percentage}% (${step}/${totalSteps}) - ${description}`);
    };
    
    reportProgress(1, "初期化中...");
    // 処理1
    
    reportProgress(2, "データ読み込み中...");
    // 処理2
    
    reportProgress(3, "分析実行中...");
    // 処理3
    
    reportProgress(4, "結果整理中...");
    // 処理4
    
    reportProgress(5, "完了");
    
    return { success: true, totalTime: "3分15秒" };
  }
};
```

### 5. 学習効率の向上

#### パターンの一貫性
```bash
# 統一されたファイル命名規則
ai-works/artifacts/theme_histories/20250119143000_theme_start.md
ai-works/artifacts/theme_histories/20250119143500_analysis_result.md
ai-works/artifacts/theme_histories/20250119144000_conclusion.md

# 統一されたログ形式
[INFO] 2025-01-19 14:30:00 - Task started: analysis
[WARN] 2025-01-19 14:35:00 - Large file detected: 15MB
[INFO] 2025-01-19 14:40:00 - Task completed: analysis

# 統一されたレスポンス形式
{
  "status": "success|warning|error",
  "message": "人間が読める説明",
  "data": { /* 構造化されたデータ */ },
  "metadata": { /* 実行情報 */ }
}
```

#### フィードバックループの設計
```typescript
// 実行結果に学習材料を含める
return {
  result: "処理完了",
  executionInfo: {
    duration: "3分15秒",
    resourceUsage: {
      memory: "256MB",
      cpu: "45%",
      disk: "1.2GB"
    },
    performance: {
      itemsProcessed: 1500,
      processingRate: "8.3 items/sec",
      efficiency: "良好"
    }
  },
  optimizationHints: [
    "次回はファイルを事前に圧縮すると高速化可能",
    "並列処理により処理時間を50%短縮可能",
    "メモリ使用量を削減するため、バッチサイズを調整推奨"
  ],
  relatedTools: [
    "compress_file - ファイル圧縮",
    "parallel_process - 並列処理",
    "optimize_memory - メモリ最適化"
  ]
};
```

#### 学習パターンの提供
```typescript
// 成功パターンの記録
const successPatterns = {
  "large_file_processing": {
    steps: [
      "1. ファイルサイズ確認",
      "2. 長時間処理宣言",
      "3. メモリ使用量チェック",
      "4. 処理実行",
      "5. 結果検証"
    ],
    bestPractices: [
      "10MB以上のファイルは事前宣言必須",
      "メモリ使用量はファイルサイズの3倍を想定",
      "中間結果の保存を推奨"
    ]
  }
};
```

### 6. 意思決定支援の強化

#### コンテキスト情報の提供
```typescript
// 意思決定に必要な情報を構造化
return {
  currentContext: {
    systemLoad: "中程度",
    availableMemory: "2.1GB",
    activeProcesses: 3,
    timeConstraints: "30分以内",
    riskTolerance: "低"
  },
  historicalData: {
    similarTasksSuccess: "85%",
    averageExecutionTime: "12分",
    commonFailureReasons: [
      "メモリ不足 (40%)",
      "タイムアウト (30%)",
      "データ形式エラー (20%)",
      "その他 (10%)"
    ]
  },
  recommendations: {
    primary: "段階的実行を推奨",
    reasoning: "現在のシステム状況と過去の成功率を考慮",
    alternatives: ["テスト実行（より安全）", "即座実行（より高速）"]
  }
};
```

### 7. メモリ効率の考慮

#### 情報の圧縮と要約
```typescript
// ❌ 冗長な情報
"ファイル1を読み込みました。ファイル1のサイズは1MBです。ファイル1の内容を解析しました。ファイル1の解析結果は正常でした。ファイル2を読み込みました..."

// ✅ 効率的な要約
"処理サマリー:
対象: 3ファイル (合計5.2MB)
結果: 成功2件、警告1件、エラー0件
所要時間: 2分30秒
詳細: file1.log(成功), file2.log(成功), file3.log(警告-軽微な形式エラー)"
```

#### 段階的な情報開示
```typescript
// 基本情報 → 詳細情報の段階的提供
return {
  summary: {
    status: "完了",
    itemsProcessed: 150,
    duration: "2分30秒"
  },
  details: {
    // 必要に応じて詳細情報を提供
    breakdown: {
      parsing: "45秒",
      analysis: "1分20秒", 
      output: "25秒"
    },
    warnings: [
      "3件の軽微な形式エラーを修正"
    ]
  },
  rawData: {
    // さらに詳細なデータ（通常は不要）
    // 必要時のみアクセス
  }
};
```

### 8. 自己修復機能の組み込み

#### 自動回復の仕組み
```bash
# 自動回復機能付きの処理
execute_with_recovery() {
    local max_attempts=3
    local attempt=1
    local backoff_seconds=5
    
    while [ $attempt -le $max_attempts ]; do
        log_info "処理開始 (試行 $attempt/$max_attempts)"
        
        if execute_main_process; then
            log_info "処理成功 (試行回数: $attempt)"
            return 0
        else
            log_warning "処理失敗 (試行 $attempt/$max_attempts)"
            
            # 部分的な結果をクリーンアップ
            cleanup_partial_results
            
            # 最後の試行でなければ待機
            if [ $attempt -lt $max_attempts ]; then
                log_info "${backoff_seconds}秒後に再試行します"
                sleep $backoff_seconds
                backoff_seconds=$((backoff_seconds * 2))  # 指数バックオフ
            fi
            
            attempt=$((attempt + 1))
        fi
    done
    
    log_error "最大試行回数に達しました。手動介入が必要です。"
    log_error "推奨対応: 1) システム状態確認 2) 設定ファイル検証 3) 手動実行"
    return 1
}
```

#### 状態の自動検証
```typescript
// 処理前後の状態検証
export const selfValidatingTool = {
  execute: async (args) => {
    // 事前状態の記録
    const preState = await captureSystemState();
    
    try {
      // メイン処理
      const result = await executeMainLogic(args);
      
      // 事後状態の検証
      const postState = await captureSystemState();
      const validation = validateStateTransition(preState, postState);
      
      if (!validation.isValid) {
        // 自動ロールバック
        await rollbackToState(preState);
        throw new Error(`状態検証失敗: ${validation.errors.join(', ')}`);
      }
      
      return {
        success: true,
        result,
        stateValidation: validation
      };
      
    } catch (error) {
      // エラー時の自動クリーンアップ
      await rollbackToState(preState);
      throw error;
    }
  }
};
```

## MCPツールのAIファースト的な利点

### 1. 処理負荷の軽減

#### コンテキスト圧縮
```typescript
// ❌ AI自身が複雑な処理を実行
"大量のログファイルを読み込んで、エラーパターンを抽出し、統計を計算し..."
// → AIが全ての処理ロジックを考える必要がある

// ✅ MCPツールによる処理の委譲
list_theme_artifacts() 
// → 複雑なファイル検索・フィルタリング・整理をツール側で実行
// → AIは結果を受け取るだけ
```

#### 認知リソースの節約
```typescript
// AI側の思考プロセス
// ❌ ツールなしの場合
"ファイルを探して... パスを確認して... 権限をチェックして... 
 内容を読み込んで... パースして... エラーハンドリングして..."

// ✅ MCPツール使用時
"analyze_logs ツールを使用"
// → 単純な意思決定のみ、複雑な実装詳細は不要
```

### 2. 専門知識の外部化

#### ドメイン固有の処理
```typescript
// ❌ AI自身が専門知識を持つ必要
"タイムスタンプの形式を理解し、Unix時間に変換し、時差を考慮し..."

// ✅ 専門知識をツールに委譲
export const convertTimestampTool = {
  description: 'タイムスタンプを各種形式に変換',
  // 複雑な時間処理ロジックはツール内に封じ込め
};
```

### 3. エラーハンドリングの一元化

#### 統一されたエラー処理
```typescript
// MCPツール内で統一されたエラーハンドリング
export const robustFileTool = {
  execute: async (args) => {
    try {
      // 複雑な処理
    } catch (error) {
      // 統一されたエラー形式で返却
      return {
        success: false,
        error: {
          type: 'FILE_ACCESS_ERROR',
          message: 'ファイルアクセスに失敗',
          suggestions: ['権限確認', 'パス確認'],
          recoverable: true
        }
      };
    }
  }
};

// AI側は統一されたエラー形式を処理するだけ
```

### 4. 状態管理の簡素化

#### 複雑な状態をツール側で管理
```typescript
// ❌ AI自身が状態を追跡
"現在のテーマは... 前回の処理は... ファイルの状態は..."

// ✅ 状態管理をツールに委譲
export const themeStatusTool = {
  execute: async () => {
    // 複雑な状態計算をツール内で実行
    return {
      currentTheme: getCurrentTheme(),
      progress: calculateProgress(),
      nextActions: suggestNextActions()
    };
  }
};
```

### 5. パフォーマンス最適化

#### 効率的なデータ処理
```typescript
// ❌ AI側でのデータ処理（非効率）
"全ファイルを読み込んで、一つずつ処理して..."

// ✅ 最適化されたツール処理
export const batchProcessTool = {
  execute: async (args) => {
    // 並列処理、キャッシュ、インデックス等を活用
    return await optimizedBatchProcess(args.files);
  }
};
```

#### メモリ効率の向上
```typescript
// ストリーミング処理をツール内で実装
export const largeFileProcessTool = {
  execute: async (args) => {
    // ファイルを分割して処理、メモリ使用量を制限
    return await streamProcess(args.filePath);
  }
};
```

### 6. 一貫性の保証

#### 標準化された操作
```typescript
// 全ての活動ログ作成が同じ形式・検証を通る
export const createActivityLogTool = {
  input_schema: z.object({
    // 厳密なスキーマ検証
  }),
  execute: async (args) => {
    // 一貫した形式での出力
    // 自動的な検証・サニタイズ
  }
};
```

### 7. 学習効率の向上

#### パターンの抽象化
```typescript
// AI側は高レベルの概念のみ理解すればよい
"ログを分析する" → analyze_logs()
"テーマを開始する" → start_theme()
"進捗を確認する" → check_progress()

// 実装詳細は学習不要
```

### 8. 拡張性とメンテナンス性

#### 機能追加の容易さ
```typescript
// 新機能をツールとして追加
export const newFeatureTool = {
  // AI側のコード変更なしに新機能を提供
};
```

#### バグ修正の局所化
```typescript
// ツール内のバグ修正がAI側に影響しない
// AI側の動作パターンは変更不要
```

### 具体的な処理負荷軽減の例

#### 1. ファイル操作の複雑さ隠蔽
```typescript
// ❌ AI自身が考える必要がある処理
"ディレクトリを作成し、権限を確認し、既存ファイルをチェックし、
 バックアップを作成し、原子的な書き込みを実行し、検証し..."

// ✅ MCPツールによる簡素化
safe_write_file({
  path: "output.txt",
  content: "data",
  backup: true
})
// → 複雑な処理はツール内で完結
```

#### 2. データ変換の自動化
```typescript
// ❌ AI自身がデータ形式を理解・変換
"CSVをパースし、JSONに変換し、スキーマを検証し..."

// ✅ 変換ツールによる自動化
convert_data({
  input: "data.csv",
  outputFormat: "json",
  schema: "user_schema"
})
```

#### 3. 複雑な検索・フィルタリング
```typescript
// ❌ AI自身が検索ロジックを実装
"正規表現を構築し、ファイルを順次検索し、結果をフィルタリングし..."

// ✅ 検索ツールによる効率化
smart_search({
  query: "error patterns",
  scope: "logs",
  timeRange: "last_week"
})
```

### MCPツールによる認知負荷軽減の効果

#### 高次思考への集中
```
❌ 従来の処理分散
├─ 実装詳細の考慮 (60%)
├─ エラーハンドリング (20%)
├─ データ形式の理解 (15%)
└─ 本来の思考・判断 (5%)

✅ MCPツール活用後
├─ 本来の思考・判断 (70%)
├─ ツール選択・組み合わせ (20%)
├─ 結果の解釈・活用 (8%)
└─ エラー対応 (2%)
```

#### 創造性の向上
- **実装制約からの解放**: 技術的制約を考えずにアイデアを発想
- **高速プロトタイピング**: ツールの組み合わせで迅速な検証
- **複雑な処理の実現**: 個別には困難な処理の組み合わせ実現

### 9. 意思決定支援の強化

#### 選択肢の重み付け
```typescript
return {
  decision: "処理方法の選択",
  options: [
    {
      name: "即座に実行",
      description: "現在の設定でそのまま実行",
      pros: ["迅速な結果", "シンプルな手順"],
      cons: ["リスクが高い", "元に戻せない"],
      risk: "高",
      estimatedTime: "5分",
      successRate: "70%",
      recommended: false,
      reason: "リスクが高く、失敗時の影響が大きい"
    },
    {
      name: "段階的実行",
      description: "小さなステップに分けて実行",
      pros: ["安全性が高い", "途中で修正可能", "進捗確認可能"],
      cons: ["時間がかかる", "手順が複雑"],
      risk: "低",
      estimatedTime: "15分",
      successRate: "95%",
      recommended: true,
      reason: "安全性と成功率が高く、長期的に効率的"
    }
  ],
  defaultChoice: "段階的実行",
  decisionFactors: [
    "データの重要性: 高",
    "時間的制約: 中",
    "リスク許容度: 低"
  ]
};
```

## 実際のシステムでの応用例

### 1. AI心臓システムでの実装

#### ハートビートIDによる一意識別
```bash
# 明確な識別子の使用
HEARTBEAT_ID="20250119143000"  # YYYYMMDDHHMMSS形式
echo "ハートビートIDは${HEARTBEAT_ID}です。"
```

#### 段階的な異常検知
```bash
# 警告 → エラーの段階的対応
case $health_status in
    0) log_info "正常動作" ;;
    1) log_warning "軽微な問題を検出" ;;
    2) log_error "重大な問題を検出 - 回復処理を開始" ;;
esac
```

#### 自動回復機能
```bash
# 構造化された回復処理
attempt_recovery() {
    local detection_type="$1"
    
    log_warning "異常検知: ${detection_type}"
    log_info "回復手順: 1) 処理中断 2) 状態保存 3) システムリセット"
    
    interrupt_agent
    save_agent_state
    reset_system_state
}
```

### 2. 時間ベース制御設計での実装

#### 事前宣言による予測可能性
```typescript
// 明確な事前情報提供
export const declareExtendedProcessingTool = {
  description: `長時間処理の事前宣言。
  
効果: 時間制限による異常検知を一時的に無効化
制限: 最大30分まで
自動削除: 活動ログ作成時に自動削除`,
  // ...
};
```

#### 段階的な警告システム
```typescript
// 明確な段階分け
function checkProcessingTime(heartbeatId: string): string | null {
  const elapsedMinutes = calculateElapsedMinutes(heartbeatId);
  
  if (elapsedMinutes >= 10) {
    return `長時間処理警告: ${elapsedMinutes}分経過。処理を区切ることを推奨します。`;
  } else if (elapsedMinutes >= 5) {
    return `処理時間通知: ${elapsedMinutes}分経過。`;
  }
  
  return null;
}
```

## 実装チェックリスト

### 設計段階
- [ ] 情報の構造化を検討
- [ ] 選択肢の明示化を計画
- [ ] エラーハンドリングの段階化を設計
- [ ] 予測可能性の確保を検討

### 実装段階
- [ ] 一貫したパターンの使用
- [ ] 明示的なメッセージの実装
- [ ] 自動回復機能の組み込み
- [ ] 進捗の可視化

### テスト段階
- [ ] AIエージェントの理解度確認
- [ ] エラーケースでの動作確認
- [ ] 学習効率の測定
- [ ] 認知負荷の評価

### 運用段階
- [ ] フィードバックの収集
- [ ] パフォーマンスの監視
- [ ] 継続的な改善
- [ ] パターンの最適化

## まとめ

AIファーストな実装は、AIエージェントの特性を理解し、それに最適化されたシステム設計を行うことです。
明確性、構造化、予測可能性を重視し、AIが「迷わず、効率的に、安全に」動作できる環境を提供することが重要です。

これらの原則に従うことで、AIエージェントの生産性向上、エラー率の削減、システムの安定性向上が期待できます。

### あなた自身への適用

このガイドの原則は、あなた自身の動作にも適用できます：

1. **明確な意思決定**: 曖昧な状況では明確化を求める
2. **構造化された思考**: 情報を整理して段階的に処理する
3. **予測可能な行動**: 処理時間や結果を事前に見積もる
4. **エラーからの学習**: 失敗を分析して改善につなげる
5. **MCPツールの活用**: 複雑な処理はツールに委譲して高次思考に集中する

これらの原則を意識することで、より効率的で安全な活動が可能になります。

## 開発実践における注意点

### 開発サーバー実行時の推奨方法

#### 基本方法: timeout実行（推奨）
```bash
# 基本的な使用方法（30秒間実行）
timeout 30s npm run dev

# 出力も保存したい場合（オプション）
timeout 30s npm run dev 2>&1 | tee ai-works/artifacts/current_theme/server_output.log
```

**利点**:
- **確実な終了**: timeoutにより30秒で確実に終了
- **直接出力**: サーバーの出力が直接表示され、リアルタイムで確認可能
- **無活動回避**: 長時間プロセスによる異常検知を防ぐ
- **継続監視**: 次のハートビートで再実行・監視が可能
- **シンプル**: 複雑なファイル操作が不要

#### 並行作業が必要な場合: バックグラウンド実行
```bash
# サーバーをバックグラウンドで起動（プロセスIDを記録）
npm run dev &
SERVER_PID=$!
echo $SERVER_PID > /tmp/dev_server_$$.pid

# 並行作業の例
curl http://localhost:3000/api/test
cat logs/server.log
# その他の確認作業...

# 作業完了後、確実にサーバーを終了
kill $SERVER_PID 2>/dev/null || true
rm -f /tmp/dev_server_$$.pid
```

**バックグラウンド実行時の注意点**:
- **プロセス管理**: 必ずプロセスIDを記録し、作業完了後に終了する
- **時間制限**: 長時間の並行作業は避け、適度な間隔でハートビートを受信できるようにする
- **リソース管理**: プロセスの残存を防ぐため、確実な終了処理を実行する
- **用途限定**: 並行して確認作業が必要な場合のみ使用し、基本はtimeout実行を優先する

**使い分けの判断基準**:
- **シンプルな動作確認**: timeout実行
- **APIテスト + ログ確認**: バックグラウンド実行
- **設定変更 + 動作確認**: バックグラウンド実行
- **複数エンドポイントのテスト**: バックグラウンド実行

### ファイル操作の安全性

**許可領域**: `ai-works/` ディレクトリ配下のみ
**禁止領域**: `ai-works/` 以外の全てのファイル・ディレクトリ

**主な禁止対象**:
- システムスクリプト（`*.sh`・`lib/`配下）
- 設定ファイル（`heartbeat.conf`・`ai-works-lib/.gemini/settings.json`）
- AIドキュメント（`ai-works-lib/ai-docs/`・`ai-works-lib/GEMINI.md`）
- システムファイル（`.gitignore`, `LICENSE`, `README.md`等）