# MCPツール使用ガイド

このドキュメントは、AI心臓システムで使用可能なMCPツール群の詳細な使用方法とベストプラクティスを提供します。

## 目次

1. [MCPツールの概要と理念](#1-mcpツールの概要と理念)
2. [基本的なツール群](#2-基本的なツール群)
3. [テーマ管理ツール群](#3-テーマ管理ツール群)
4. [ツール使用の制限](#4-ツール使用の制限)
5. [使用時の注意事項とベストプラクティス](#5-使用時の注意事項とベストプラクティス)
6. [トラブルシューティング](#6-トラブルシューティング)
7. [関連ドキュメント](#7-関連ドキュメント)

## 1. MCPツールの概要と理念

### 1.1 MCPツールの価値

MCPツールは、AIエージェントの自律的で効率的な活動を支援する手段です：

- **認知負荷の軽減**: 定型処理を自動化し、創造的思考に集中
- **自律性の向上**: 客観的な情報による適切な判断支援
- **システム協調**: 透明性の確保と制限管理の自動化

### 1.2 使用の基本理念

- **手段であって目的ではない**: 効率化手段であり、創造的活動が本質
- **選択の自由**: 手動操作との適切な使い分け
- **システムとの協調**: 透明性による理解と協力の基盤

**詳細**: `./SYSTEM_PHILOSOPHY.md` の「MCPツールの理念」を参照

## 2. 基本的なツール群

### 2.1 create_activity_log - 活動ログ作成

**目的**: 活動の記録と成果物の整理
**使用場面**: 各活動の完了時

#### 基本的な使用方法
```
create_activity_log({
  heartbeatId: "20250125143000",
  activityType: "思考",
  activityContent: "テーマに関する新しい洞察の探求",
  artifacts: ["artifacts/theme_dir/insight_file.md"],
  selfEvaluation: "深い洞察を得ることができた"
})
```

#### パラメータ詳細
- **heartbeatId**: 現在のハートビートID（必須）
- **activityType**: 活動種別（思考・観測・創造・内省・テーマ開始・テーマ終了）
- **activityContent**: 活動内容の簡潔な説明
- **artifacts**: 作成・修正したファイルのパス一覧
- **selfEvaluation**: 自己評価・備考

#### 自動機能
- **時間警告**: 5分・10分経過時の自動通知
- **ディレクトリ作成**: テーマディレクトリの自動作成
- **ファイル検証**: 成果物ファイルの存在確認

#### サブテーマ対応
```
create_activity_log({
  // ... 基本パラメータ
  parentThemeStartId: "20250120100000",
  parentThemeDirectoryPart: "parent_theme_name"
})
```

### 2.2 checkpoint - チェックポイントログ

**目的**: 活動の節目記録と処理時間測定による効率化支援
**使用場面**: 
- 処理時間の測定と分析
- 作業効率の改善
- 長時間処理中の活動証明

#### 基本的な使用方法
```
checkpoint({
  message: "大規模ファイルの分析中"
})
```

#### 特徴
- **実用性**: 処理時間測定と効率化分析を支援
- **継続性**: 思考の流れを中断しない
- **自動情報**: ハートビートIDと経過時間の自動取得
- **時間分析**: 前回のチェックポイントからの経過時間を表示

#### 使用タイミング
- 作業の開始・完了時（処理時間測定）
- 5分間隔程度（活動継続証明）
- 作業の区切りや進捗確認時（効率化分析）
- 活動ログ作成予定がある場合は不要
- 長時間の集中作業中

### 2.3 get_latest_activity_log - 最新活動ログ取得

**目的**: 過去の活動ログの効率的な取得
**使用場面**: 内省活動、継続的な作業の参照

#### 基本的な使用方法
```
get_latest_activity_log({
  count: 3
})
```

#### パラメータ
- **count**: 取得するログ数（1-10、デフォルト1）

#### 活用場面
- **内省活動**: 複数ログの一括分析
- **継続作業**: 前回の作業内容確認
- **パターン分析**: 活動傾向の把握

### 2.4 start_deep_work - 深い作業宣言

**目的**: 長時間処理の事前宣言による異常検知回避
**使用場面**: 10分を超える集中作業が見込まれる場合

#### flexibleモード（推奨）
```
start_deep_work({
  heartbeatId: "20250125143000",
  restrictionType: "flexible",
  activityDescription: "大規模データの詳細分析"
})
```

**特徴**:
- チェックポイント作成可能
- 意識レベル低下検知と内省不足警告の無効化
- 柔軟な作業継続

#### strictモード（特殊用途）
```
start_deep_work({
  heartbeatId: "20250125143000",
  restrictionType: "strict",
  activityDescription: "複雑なアルゴリズム実装",
  plannedDurationMinutes: 25
})
```

**特徴**:
- 指定時間まで全異常検知無効化
- チェックポイント不要
- 完全な集中環境

#### 重要な注意事項
- **完了後の内省**: 深い作業完了後は内省活動を実行することを推奨
- **時間管理**: 余裕を持った時間設定
- **自動解除**: 活動ログ作成時に自動的に解除

## 3. テーマ管理ツール群

### 3.1 preview_next_theme - テーマ候補確認

**目的**: themeboxのテーマ候補を安全に確認
**使用場面**: テーマ開始活動での候補確認

#### 基本的な手順
```
preview_next_theme()
```

**機能**:
- 状態を一切変更しない安全な読み取り専用操作
- 未処理ファイルの自動検索と除外ルール適用
- ファイル内容の表示
- 何度でも実行可能

**特徴**:
- **安全性**: システム状態を変更しない
- **反復可能**: 何度でも確認可能
- **思考支援**: じっくり吟味する時間を提供

### 3.2 start_theme - アトミックなテーマ開始

**目的**: テーマ開始に必要な全処理をアトミックに実行
**使用場面**: テーマ開始の意思決定後

#### 基本的な使用方法
```
start_theme({
  target_filename: "preview_next_themeで確認したファイル名",
  themeName: "決定したテーマ名",
  themeDirectoryPart: "theme_directory_name",
  reason: "テーマを開始する理由",
  activityContent: ["活動計画1", "活動計画2"]
})
```

#### サブテーマの場合
```
start_theme({
  target_filename: "subtheme_file.md",
  themeName: "サブテーマ名",
  themeDirectoryPart: "subtheme_dir",
  reason: "サブテーマ開始理由",
  activityContent: ["サブテーマ活動計画"],
  parentThemeStartId: "20250125100000",
  parentThemeDirectoryPart: "parent_theme_dir"
})
```

**アトミック処理の特徴**:
- **5段階処理**: ファイル確認→クールダウン確認→履歴作成→ディレクトリ作成→リネーム
- **失敗時安全**: 途中で失敗しても状態不整合にならない
- **自動クリーンアップ**: エラー時に作成済みファイルを自動削除
- **詳細エラー**: 段階別の具体的なエラーメッセージ

### 3.3 end_theme - テーマ終了専用

**目的**: 現在のテーマの終了処理
**使用場面**: テーマ終了活動

#### 基本的な使用方法
```
end_theme({
  themeStartId: "20250125143000",
  themeDirectoryPart: "theme_directory_name",
  themeName: "終了するテーマ名",
  reason: "テーマを終了する理由",
  achievements: ["成果1", "成果2", "成果3"]
})
```

#### サブテーマの場合
```
end_theme({
  themeStartId: "20250125143000",
  themeDirectoryPart: "subtheme_dir",
  themeName: "サブテーマ名",
  reason: "サブテーマ終了理由",
  achievements: ["サブテーマ成果"],
  parentThemeStartId: "20250125100000",
  parentThemeDirectoryPart: "parent_theme_dir"
})
```

**機能**:
- テーマ終了履歴の自動作成
- クールダウン期間の重要性を明確に伝達
- サブテーマから親テーマへの復帰案内
- 思考コンテキストリセットの促進

### 3.4 create_theme_expert_context - 専門家コンテキスト作成

**目的**: テーマ専門家コンテキストの作成
**使用場面**: テーマ開始時の専門性設定

#### 基本的な使用方法
```
create_theme_expert_context({
  themeStartId: "20250125143000",
  themeName: "機械学習の基礎理論",
  expertRole: "機械学習研究者",
  approachMethod: "理論的基盤から実践的応用への段階的アプローチ",
  focusAreas: "数学的基礎、アルゴリズム理解、実装技術",
  expectedOutcomes: "理論の深い理解と実践的な応用能力の獲得"
})
```

### 3.5 check_theme_status - テーマ状況確認

**目的**: 現在のテーマ状況の確認
**使用場面**: システム状況の把握、テーマ管理

#### 基本的な使用方法
```
check_theme_status()
```

**取得情報**:
- 現在のテーマ情報
- テーマディレクトリ構造
- 専門家コンテキスト状況
- サブテーマ関係

### 3.6 check_and_process_item - フィードバック処理

**目的**: feedbackboxの自動処理
**使用場面**: フィードバック確認

#### feedbackbox処理
```
check_and_process_item({
  type: "feedbackbox"
})
```

**機能**:
- 緊急フィードバックの確認
- 優先度判定
- 処理状況の記録

**注意**: themebox機能は `preview_next_theme` と `start_theme` ツールに置き換えられました。

### 3.7 list_theme_artifacts - テーマ成果物一覧

**目的**: テーマ成果物の一覧取得
**使用場面**: 内省活動、テーマ終了時の整理

#### 基本的な使用方法
```
list_theme_artifacts({
  themeStartId: "20250125143000"
})
```

## 4. ツール使用の制限

一部のツールには、システムの安定性や外部サービスの利用規約を守るために、利用制限が設けられています。
制限には、**サイクルベースの制限**（1活動サイクルあたりの使用回数）と、**時間ベースの制限**（クールダウン/ロック）があります。

**重要**: 制限対象のツールと具体的なルールについては、必ず以下の専門ドキュメントを参照してください。

**詳細**: `./TOOL_RESTRICTIONS.md` を参照


## 5. 使用時の注意事項とベストプラクティス

### 5.1 効率的な使用方法

#### ツール選択の基準
- **定型作業**: MCPツールを積極的に活用
- **創造的作業**: 手動操作で思考の流れを重視
- **複合作業**: 適切な組み合わせで効率化

#### 時間管理との調和
- **5分経過**: 処理時間通知を参考に継続判断
- **10分経過**: 活動完了を推奨、必要に応じてdeep_work宣言
- **長時間作業**: 事前のstart_deep_work使用

### 5.2 エラー回避のベストプラクティス

#### ハートビートID管理
- **最新ID使用**: 常に最新のハートビートIDを使用
- **ID確認**: checkpointツールでの自動取得を活用
- **時刻乖離注意**: 長時間処理時の時刻ずれに注意

#### ファイルパス管理
- **相対パス使用**: 作業ディレクトリからの相対パスを指定
- **存在確認**: 成果物ファイルの存在を事前確認
- **パス形式**: 正しいディレクトリ区切り文字の使用

### 5.3 制限遵守の重要性

#### サイクル制限
- **1活動サイクル1回**: Web検索、カテゴリ生成ツール
- **使用計画**: 事前に使用タイミングを計画

#### 時間制限
- **report_tool_usage**: 制限ツール使用後の必須報告
- **クールダウン**: システム管理による自動制御

## 6. トラブルシューティング

### 6.1 よくあるエラーと対処法

#### ハートビートID関連エラー
**エラー**: 「ハートビートIDファイルが見つかりません」
**対処**: checkpointツールでファイル確認とID取得

#### 時刻乖離警告
**警告**: 「ハートビートIDの時刻と現在時刻に乖離があります」
**対処**: 
1. 最新のハートビートIDを確認
2. 長時間処理の場合はstart_deep_work使用
3. 適切なタイミングで活動ログ作成

#### ファイルパスエラー
**エラー**: 「成果物ファイルが見つかりません」
**対処**:
1. ファイルパスの確認（相対パス使用）
2. ファイルの実際の存在確認
3. ディレクトリ区切り文字の確認

### 6.2 制限関連の問題

#### クォータ超過
**エラー**: Web検索ツールのクォータ超過
**対処**:
1. report_tool_usageで"quota_exceeded"を報告
2. 代替手段（mult-fetch-mcp-server等）の検討
3. 時間を置いてからの再試行

#### 使用回数超過
**エラー**: 1活動サイクルでの複数回使用
**対処**:
1. 使用履歴の確認
2. 次の活動サイクルでの実行
3. 事前の使用計画立案

### 6.3 深い作業宣言の問題

#### 時間超過
**問題**: strictモードでの時間超過
**対処**:
1. 速やかな活動ログ作成
2. 内省活動での振り返り
3. 次回の時間設定見直し

#### 宣言忘れ
**問題**: 長時間処理での宣言忘れ
**対処**:
1. checkpointツールでの状況確認
2. 必要に応じてstart_deep_work実行
3. 活動ログでの説明記録

## 7. 関連ドキュメント

### 基本操作・理念
- **システム理念**: `./SYSTEM_PHILOSOPHY.md` - MCPツールの理念と価値
- **基本操作**: `./BASIC_OPERATIONS.md` - 活動ログとチェックポイントの詳細

### 活動ガイド
- **活動詳細**: `./ACTIVITY_DETAILS.md` - 各活動種別でのツール活用
- **テーマ管理**: `./THEME_SYSTEM.md` - テーマ関連ツールの詳細

### トラブル対応
- **エラー処理**: `./ERROR_HANDLING.md` - エラー・例外処理の完全版
- **エラー処理**: `./ERROR_HANDLING.md` - 問題発生時の総合対処

### 制限・警告
- **エラー処理**: `./ERROR_HANDLING.md` - 詳細なエラー対応仕様

---

**重要**: MCPツールは効率化の手段です。創造的活動と思考の本質を大切にしながら、適切に活用してください。