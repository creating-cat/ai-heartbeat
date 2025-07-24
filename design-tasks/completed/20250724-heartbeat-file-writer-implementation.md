# heartbeat.sh ファイル書き込み機能実装

## 概要

heartbeat.shにハートビートIDをファイルに書き込む機能を追加する。この機能により、AIエージェントは処理を中断することなく、最新のハートビートIDを自律的に取得できるようになる。

## 実装目標

### 主要機能
- ハートビート送信時に、ハートビートIDを `ai-works/stats/current_heartbeat_id.txt` に書き込み
- 原子的書き込みによるデータ競合の回避
- 既存のプロンプト送信機能との並行動作
- エラー時の継続性確保

### 設計原則
- **既存機能への影響ゼロ**: プロンプト送信、ログ出力、異常検知は従来通り
- **原子性保証**: 読み取り側が不完全なデータを読むことを防ぐ
- **エラー耐性**: ファイル書き込み失敗でもシステム継続
- **即座導入**: 段階的導入なしで本格運用開始

## 技術仕様

### 1. ファイル管理仕様

#### ファイルパス
```bash
HEARTBEAT_FILE="ai-works/stats/current_heartbeat_id.txt"
```

#### ファイル内容
- **形式**: ハートビートID（YYYYMMDDHHMMSS形式）のみ
- **文字数**: 14文字固定
- **改行**: なし（`echo -n` を使用）
- **例**: `20250724143000`

#### ディレクトリ構造
```
ai-works/stats/
├── cooldown/           # 既存
├── extended_processing/ # 既存
├── lock/               # 既存
└── current_heartbeat_id.txt  # 新規追加
```

### 2. 原子的書き込み実装

#### 新規関数の追加
```bash
# heartbeat.sh内に追加する関数
write_heartbeat_id() {
    local heartbeat_id="$1"
    local heartbeat_file="ai-works/stats/current_heartbeat_id.txt"
    local temp_file="${heartbeat_file}.tmp"
    
    # ディレクトリ存在確認・作成
    mkdir -p "$(dirname "$heartbeat_file")"
    
    # 一時ファイルに書き込み
    if ! echo -n "$heartbeat_id" > "$temp_file"; then
        log_error "一時ファイル書き込み失敗: $temp_file"
        return 1
    fi
    
    # 原子的な移動
    if mv "$temp_file" "$heartbeat_file"; then
        log_info "ハートビートID更新: $heartbeat_id"
        return 0
    else
        log_error "ハートビートファイル更新失敗: $heartbeat_id"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}
```

#### 原子性の保証
- **一時ファイル使用**: `.tmp` 拡張子で一時ファイルを作成
- **mvコマンド**: 同一ファイルシステム内での原子的移動
- **競合回避**: 読み取り側は常に完全なデータまたは古い完全なデータを読む
- **中途半端な状態なし**: 書き込み中の不完全なデータを読み取ることがない

### 3. 既存コード修正箇所

#### 3.1 初回ハートビート送信部分（511行目周辺）

**修正前**:
```bash
initial_heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
```

**修正後**:
```bash
initial_heartbeat_id=$(date "+%Y%m%d%H%M%S")
initial_heartbeat_msg="Heartbeat: $initial_heartbeat_id"

# ハートビートIDをファイルに書き込み
write_heartbeat_id "$initial_heartbeat_id"
```

#### 3.2 定期ハートビート送信部分（618行目周辺）

**修正前**:
```bash
heartbeat_msg="Heartbeat: $(date "+%Y%m%d%H%M%S")"
```

**修正後**:
```bash
current_heartbeat_id=$(date "+%Y%m%d%H%M%S")
heartbeat_msg="Heartbeat: $current_heartbeat_id"

# ハートビートIDをファイルに書き込み
write_heartbeat_id "$current_heartbeat_id"
```

### 4. エラーハンドリング

#### 4.1 失敗パターンと対応

**ディスク容量不足**:
- エラーログ出力
- プロンプト送信は継続
- システム停止なし

**権限エラー**:
- エラーログ出力
- ディレクトリ作成試行
- 失敗時もシステム継続

**一時ファイル作成失敗**:
- 詳細エラーログ
- 一時ファイルクリーンアップ
- 次回ハートビートで再試行

#### 4.2 継続性の確保
```bash
# ファイル書き込み失敗でもプロンプト送信は必ず実行
write_heartbeat_id "$current_heartbeat_id"  # 失敗してもOK
send_message_to_agent "$heartbeat_msg"      # 必ず実行
```

### 5. 実装手順

#### Step 1: 関数追加
- `write_heartbeat_id()` 関数をheartbeat.shに追加
- 適切な位置（他の関数定義の近く）に配置

#### Step 2: 初回ハートビート修正
- 511行目周辺の初回ハートビート送信部分を修正
- ハートビートID生成とファイル書き込みを追加

#### Step 3: 定期ハートビート修正
- 618行目周辺の定期ハートビート送信部分を修正
- ハートビートID生成とファイル書き込みを追加

#### Step 4: テスト実行
- heartbeat.shを再起動
- ファイル作成・更新の確認
- エラーケースのテスト

### 6. テスト・検証方法

#### 6.1 基本動作確認
```bash
# 1. ファイル存在確認
ls -la ai-works/stats/current_heartbeat_id.txt

# 2. ファイル内容確認
cat ai-works/stats/current_heartbeat_id.txt

# 3. リアルタイム更新確認
watch -n 1 'echo "File: $(cat ai-works/stats/current_heartbeat_id.txt 2>/dev/null || echo "NOT_FOUND")"; echo "Time: $(date "+%Y%m%d%H%M%S")"'

# 4. ファイル形式確認
wc -c ai-works/stats/current_heartbeat_id.txt  # 14文字であることを確認
```

#### 6.2 エラーケーステスト
```bash
# 1. 権限エラーのシミュレーション
chmod 000 ai-works/stats/
# heartbeat.sh実行後、権限を戻す
chmod 755 ai-works/stats/

# 2. ディスク容量不足のシミュレーション（注意して実行）
# 3. 同時読み書きテスト
```

#### 6.3 パフォーマンステスト
```bash
# 書き込み時間の測定
time write_heartbeat_id "20250724143000"

# システム負荷の確認
top -p $(pgrep -f heartbeat.sh)
```

### 7. 期待される効果

#### 7.1 AIエージェント側の利点
- **継続的思考**: 処理中断なしでハートビート確認
- **自律性向上**: 自分のタイミングでの状態確認
- **柔軟性**: プロンプト待ちかファイル確認かを選択可能

#### 7.2 システム側の利点
- **堅牢性**: 単一障害点の削減
- **監視性**: ファイルベースでの状態確認が容易
- **拡張性**: 将来的な機能追加の基盤

#### 7.3 運用面の利点
- **デバッグ容易**: ファイル内容で現在状態を即座に確認
- **ログ分析**: ハートビートIDとファイル更新時刻の相関分析
- **外部監視**: 外部ツールからのハートビート状態監視が可能

### 8. 完了基準

#### 8.1 機能要件
- [ ] ハートビート送信時にファイルが更新される
- [ ] ファイル内容が正しいハートビートID形式（14文字）
- [ ] 原子的書き込みが正常に動作する
- [ ] エラー時もシステムが継続動作する

#### 8.2 性能要件
- [ ] ファイル書き込みによる遅延が1秒未満
- [ ] プロンプト送信への影響がない
- [ ] システム負荷の増加が無視できるレベル

#### 8.3 運用要件
- [ ] 24時間連続運用でファイル更新が継続
- [ ] エラーログが適切に出力される
- [ ] 既存の異常検知機能が正常動作

### 9. 実装後の次ステップ

#### 9.1 AIエージェント側の対応準備
- ファイル読み取り機能の実装準備
- エラーハンドリングの設計
- 使い分けロジックの検討

#### 9.2 ドキュメント更新準備
- GEMINI.mdの更新内容準備
- OPERATION_DETAILS.mdの更新内容準備
- 運用ガイドラインの更新準備

#### 9.3 監視・運用準備
- ファイル更新状況の監視方法検討
- 異常時の対応手順策定
- パフォーマンス監視項目の設定

## 注意事項

### 実装時の注意
- 既存のログ出力やエラーハンドリングパターンに合わせる
- 関数名や変数名は既存コードの命名規則に従う
- コメントは既存コードと同じスタイルで記述

### 運用時の注意
- ファイル書き込み失敗は正常な動作の一部として扱う
- エラーログの頻度が高い場合は原因調査が必要
- ディスク容量の定期的な監視を推奨

### 将来の拡張
- 複数AIエージェント対応時の排他制御
- ハートビート統計情報の追加
- リアルタイム監視機能の実装

この実装により、AI心臓システムはより柔軟で堅牢なハートビート管理システムに進化し、AIエージェントの自律性向上の基盤が整います。