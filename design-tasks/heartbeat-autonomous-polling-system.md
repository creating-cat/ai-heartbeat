# ハートビート自律ポーリングシステム設計

## 概要

現在のAI心臓システムでは、AIエージェントがハートビート受信のために処理を中断する必要があり、思考の連続性が阻害されている。この問題を解決するため、AIエージェントが自律的にハートビート状態をポーリングし、処理を中断することなく継続的に活動できるシステムに変更する。

## 現状の問題点

### 1. 強制的な処理中断
- AIが集中して作業している最中に強制的に中断される
- 思考の流れや作業のコンテキストが分断される
- ハートビート待ちの間、AIは何もできない状態になる

### 2. AIファースト設計からの逸脱
- 人間的な「呼び出し」パターンを採用している
- AIの自律性が制限されている
- 継続的思考フローが阻害されている

### 3. 効率性の問題
- 作業の区切りが悪いタイミングでの中断
- コンテキストの再構築に時間がかかる
- 全体的な生産性の低下

## 提案する新システム

### 基本コンセプト
**プッシュ型 + プル型のハイブリッド方式**
- 既存: heartbeat.sh → AIエージェント（プッシュ型・継続）
- 新規: AIエージェント → ハートビートファイル（プル型・追加）
- 両方式を併用することで、AIの自律性向上と既存システムの安定性を両立

### システム構成

#### 1. ハートビートファイル管理
```bash
# heartbeat.sh側での実装
HEARTBEAT_FILE="ai-works/stats/current_heartbeat_id.txt"
HEARTBEAT_ID=$(date +"%Y%m%d%H%M%S")

# ハートビートIDをファイルに書き込み
echo "$HEARTBEAT_ID" > "$HEARTBEAT_FILE"
log_heartbeat "ハートビートID更新: $HEARTBEAT_ID"
```

#### 2. AIエージェント側の自律チェック
```typescript
// MCPツール経由での実装
export const getCurrentHeartbeatIdTool = {
  name: "get_current_heartbeat_id",
  description: `現在のハートビートIDを取得します。
  
使用タイミング:
- 活動ログ作成前
- 長時間処理の開始時
- 定期的な状態確認時

戻り値:
- heartbeatId: 現在のハートビートID (YYYYMMDDHHMMSS形式)
- timestamp: ハートビート生成時刻
- elapsedSeconds: 前回ハートビートからの経過時間`,
  
  input_schema: z.object({}),
  
  execute: async () => {
    try {
      const heartbeatFile = "ai-works/stats/current_heartbeat_id.txt";
      const heartbeatId = await fs.readFile(heartbeatFile, 'utf-8').then(s => s.trim());
      
      // ハートビート時刻の解析
      const timestamp = parseHeartbeatId(heartbeatId);
      const elapsedSeconds = Math.floor((Date.now() - timestamp.getTime()) / 1000);
      
      return {
        success: true,
        heartbeatId,
        timestamp: timestamp.toISOString(),
        elapsedSeconds,
        status: elapsedSeconds < 120 ? "正常" : "要注意"
      };
    } catch (error) {
      return {
        success: false,
        error: "ハートビートファイルの読み取りに失敗",
        fallbackId: generateFallbackHeartbeatId()
      };
    }
  }
};
```

#### 3. 活動ログ作成の自動化
```typescript
// 既存のcreateActivityLogToolを拡張
export const createActivityLogTool = {
  execute: async (args) => {
    // 自動的に最新のハートビートIDを取得
    const heartbeatResult = await getCurrentHeartbeatIdTool.execute({});
    const heartbeatId = heartbeatResult.success 
      ? heartbeatResult.heartbeatId 
      : heartbeatResult.fallbackId;
    
    // 活動ログを作成
    const logEntry = {
      heartbeat_id: heartbeatId,
      activity_type: args.activityType,
      content: args.content,
      timestamp: new Date().toISOString()
    };
    
    // ファイル保存処理...
    
    return {
      success: true,
      heartbeatId,
      logPath: logFilePath,
      message: `活動ログを作成しました (ハートビートID: ${heartbeatId})`
    };
  }
};
```

## 技術的実装詳細

### 1. ファイル管理の安全性

#### 原子的書き込み
```bash
# heartbeat.sh内での安全な書き込み
write_heartbeat_id() {
    local heartbeat_id="$1"
    local heartbeat_file="ai-works/stats/current_heartbeat_id.txt"
    local temp_file="${heartbeat_file}.tmp"
    
    # 一時ファイルに書き込み
    echo "$heartbeat_id" > "$temp_file"
    
    # 原子的な移動
    mv "$temp_file" "$heartbeat_file"
    
    log_info "ハートビートID更新: $heartbeat_id"
}
```

#### 読み取り時のエラーハンドリング
```typescript
// MCPツール側での堅牢な読み取り
async function readHeartbeatIdSafely(): Promise<string> {
  const heartbeatFile = "ai-works/stats/current_heartbeat_id.txt";
  const maxRetries = 3;
  const retryDelay = 100; // ms
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const content = await fs.readFile(heartbeatFile, 'utf-8');
      const heartbeatId = content.trim();
      
      // 形式検証
      if (!/^\d{14}$/.test(heartbeatId)) {
        throw new Error(`無効なハートビートID形式: ${heartbeatId}`);
      }
      
      return heartbeatId;
    } catch (error) {
      if (attempt === maxRetries) {
        // 最終試行でも失敗した場合はフォールバック
        return generateFallbackHeartbeatId();
      }
      
      // 短時間待機して再試行
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }
}
```

### 2. 異常検知システムとの統合

#### 既存の異常検知ロジックの維持
```bash
# health_check_core.shは変更不要
# ハートビートIDベースの検知は継続可能

check_activity_log_frequency() {
    # 既存のロジックをそのまま使用
    # ファイル名にハートビートIDが含まれているため、
    # 検知精度は維持される
}

check_timestamp_anomaly() {
    # タイムスタンプベースの検知も継続
    # ハートビートIDから時刻を抽出して検証
}
```

#### 新しい異常パターンの検知
```bash
# ハートビートファイル関連の異常検知を追加
check_heartbeat_file_health() {
    local heartbeat_file="ai-works/stats/current_heartbeat_id.txt"
    
    # ファイル存在確認
    if [[ ! -f "$heartbeat_file" ]]; then
        return 21  # ハートビートファイル不存在
    fi
    
    # ファイル更新時刻確認
    local file_age=$(get_file_age_seconds "$heartbeat_file")
    if [[ $file_age -gt 300 ]]; then  # 5分以上更新されていない
        return 22  # ハートビートファイル更新停止
    fi
    
    # ファイル内容確認
    local heartbeat_id=$(cat "$heartbeat_file" 2>/dev/null | tr -d '\n\r')
    if [[ ! "$heartbeat_id" =~ ^[0-9]{14}$ ]]; then
        return 23  # ハートビートID形式異常
    fi
    
    return 0  # 正常
}
```

### 3. 段階的移行戦略

#### Phase 1: 並行運用
```bash
# heartbeat.sh内で両方式を並行実行
send_heartbeat() {
    local heartbeat_id="$1"
    
    # 新方式: ファイル更新
    write_heartbeat_id "$heartbeat_id"
    
    # 旧方式: メッセージ送信（互換性のため）
    if [[ "$ENABLE_LEGACY_MODE" == "true" ]]; then
        send_message_to_agent "ハートビート受信: $heartbeat_id"
    fi
}
```

#### Phase 2: 安定運用（両方式継続）
```bash
# 両方式の安定運用
send_heartbeat() {
    local heartbeat_id="$1"
    
    # 新方式: ファイル更新
    write_heartbeat_id "$heartbeat_id"
    
    # 既存方式: プロンプト送信（継続）
    send_message_to_agent "ハートビート受信: $heartbeat_id"
    
    # 統計情報の更新
    update_heartbeat_stats "$heartbeat_id"
}
```

### 4. パフォーマンス最適化

#### キャッシュ機能
```typescript
// MCPツール側でのキャッシュ実装
class HeartbeatCache {
  private cache: {
    heartbeatId: string;
    timestamp: number;
    fileModTime: number;
  } | null = null;
  
  private cacheValidityMs = 5000; // 5秒間有効
  
  async getCurrentHeartbeatId(): Promise<string> {
    const heartbeatFile = "ai-works/stats/current_heartbeat_id.txt";
    
    try {
      const stat = await fs.stat(heartbeatFile);
      const fileModTime = stat.mtime.getTime();
      const now = Date.now();
      
      // キャッシュが有効かチェック
      if (this.cache && 
          this.cache.fileModTime === fileModTime &&
          (now - this.cache.timestamp) < this.cacheValidityMs) {
        return this.cache.heartbeatId;
      }
      
      // ファイルから読み取り
      const heartbeatId = await readHeartbeatIdSafely();
      
      // キャッシュ更新
      this.cache = {
        heartbeatId,
        timestamp: now,
        fileModTime
      };
      
      return heartbeatId;
    } catch (error) {
      // エラー時はキャッシュがあれば使用
      if (this.cache) {
        return this.cache.heartbeatId;
      }
      throw error;
    }
  }
}
```

#### バッチ処理の最適化
```typescript
// 複数の活動ログを効率的に処理
export const batchCreateActivityLogsTool = {
  name: "batch_create_activity_logs",
  description: "複数の活動ログを効率的に作成",
  
  execute: async (args: { activities: ActivityLogEntry[] }) => {
    // 一度だけハートビートIDを取得
    const heartbeatId = await heartbeatCache.getCurrentHeartbeatId();
    
    const results = [];
    for (const activity of args.activities) {
      const result = await createSingleActivityLog({
        ...activity,
        heartbeatId // 共通のハートビートIDを使用
      });
      results.push(result);
    }
    
    return {
      success: true,
      heartbeatId,
      processedCount: results.length,
      results
    };
  }
};
```

## 運用上の利点

### 1. AIエージェントの選択肢拡大
- **柔軟な活動パターン**: プロンプト待ちか自律確認かを状況に応じて選択
- **継続的思考の選択肢**: 集中したい時は自律確認、区切りをつけたい時はプロンプト待ち
- **効率的な作業フロー**: 両方式を使い分けることで最適な作業リズムを実現

### 2. システムの堅牢性向上
- **単一障害点の削除**: tmuxセッション間の依存関係を削減
- **エラー耐性**: ファイル読み取り失敗時のフォールバック機能
- **デバッグの容易さ**: ファイルベースの状態確認

### 3. 拡張性の向上
- **複数エージェント対応**: 将来的な複数AIエージェントの並行実行に対応
- **監視機能の追加**: ハートビートファイルを監視する外部ツールの追加が容易
- **統計情報の収集**: ハートビート使用パターンの分析が可能

## リスク分析と対策

### 1. ファイルアクセス競合
**リスク**: 読み書きの競合によるデータ破損
**対策**: 
- 原子的書き込みの実装
- 読み取り時のリトライ機能
- ファイルロック機能（必要に応じて）

### 2. ハートビート見逃し
**リスク**: AIがハートビートファイルの確認を忘れる
**対策**:
- 活動ログ作成時の自動チェック
- 長時間処理宣言時の自動チェック
- 定期的なリマインダー機能

### 3. システム移行時の互換性
**リスク**: 新旧システム間での不整合
**対策**:
- 段階的移行戦略の実装
- 並行運用期間の設定
- ロールバック機能の準備

## 実装スケジュール

### Phase 1: AIエージェント向けドキュメント更新 (1日)
- [ ] `GEMINI.md`の更新 - 新しいハートビート確認方法の説明
- [ ] `ai-docs/OPERATION_DETAILS.md`の更新 - 運用パターンの詳細
- [ ] `ai-docs/GUIDELINES.md`の更新 - 自律確認の推奨タイミング
- [ ] `ai-docs/MCP_WARNING_GUIDE.md`の更新 - 新ツールの警告対応

### Phase 2: システム基盤実装 (1-2日)
- [ ] `heartbeat.sh`の修正 - ハートビートファイル管理機能
- [ ] `lib/health_check_core.sh`の拡張 - 新しい異常検知
- [ ] 並行運用テスト - 既存システムとの整合性確認

### Phase 3: MCPツール実装 (1日)
- [ ] ハートビートID取得ツールの実装
- [ ] 活動ログ作成の自動化機能
- [ ] 統合テストとパフォーマンス確認

### Phase 4: 本格運用 (1日)
- [ ] 24時間連続運用テスト
- [ ] 異常ケースでの動作確認
- [ ] 運用ドキュメントの最終更新

## 完了基準

### 機能要件
- [ ] AIエージェントが処理中断なしにハートビートIDを取得可能
- [ ] 既存の異常検知機能が正常に動作
- [ ] エラー時のフォールバック機能が動作

### 性能要件
- [ ] ハートビートID取得の応答時間が100ms以下
- [ ] ファイルアクセス競合によるエラー率が1%以下
- [ ] システム全体の安定性が現状と同等以上

### 運用要件
- [ ] 24時間以上の連続運用テストをクリア
- [ ] ログ出力が適切に行われる
- [ ] 既存のスクリプトとの互換性を維持

## 関連ファイル

### 最優先: AIエージェント向けドキュメント
- `GEMINI.md`: 新しいハートビート確認方法の使用説明
- `ai-docs/OPERATION_DETAILS.md`: 運用パターンの詳細追加
- `ai-docs/GUIDELINES.md`: 自律確認の推奨タイミング
- `ai-docs/MCP_WARNING_GUIDE.md`: 新ツールの警告・制限事項

### システム基盤の修正
- `heartbeat.sh`: ハートビートファイル管理機能の追加
- `lib/health_check_core.sh`: 異常検知機能の拡張
- `lib/heartbeat_file.sh`: ハートビートファイル操作ライブラリ（新規）

### MCPツール実装（最後）
- `mcp/ai-heartbeat-mcp/src/tools/`: 新しいMCPツールの実装
- `ai-works/stats/current_heartbeat_id.txt`: ハートビートID管理ファイル（新規）

## 注意事項

### 開発時の注意
- ファイル操作は`ai-works/`配下のみに限定
- 既存の異常検知ロジックとの整合性を保つ
- エラーハンドリングを十分に実装

### 運用時の注意
- 移行期間中は両方式の動作を監視
- ハートビートファイルのディスク容量を監視
- 異常時のロールバック手順を準備

### 将来の拡張
- 複数AIエージェント対応の準備
- ハートビート統計機能の追加
- リアルタイム監視機能の実装

この設計により、AIエージェントはより自律的で効率的な動作が可能になり、システム全体の堅牢性も向上することが期待される。