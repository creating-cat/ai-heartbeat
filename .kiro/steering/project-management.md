---
inclusion: always
---

# design-tasks 運用ルール

## 基本的な流れ
1. やるべきことを `design-tasks/task-name.md` に書く
2. 作業を進める
3. 作業完了（作業者が完了と判断し、完了報告を追記）
4. 第3者による完了確認
5. 第3者確認OKなら `design-tasks/completed/YYYYMMDD-task-name.md` に移動
6. 必要に応じて `.kiro/specs/` の関連仕様書を更新

## 作業者の責任範囲（重要）
- **作業実施**: タスクの実装・修正作業
- **完了判断**: 自分の作業が完了したと判断
- **完了報告**: タスクファイルに完了報告を追記
- **待機**: 第三者確認を待つ

## 作業者が行ってはいけないこと
- ❌ completedフォルダへのファイル移動
- ❌ 第三者確認の代行
- ❌ 「確認OK」の判断

## 完了報告の方法
作業完了時は、タスクファイルの最後に以下を追加：

```markdown
## 完了報告
**完了日時**: [日時]
**実施内容**: [作業概要]
**変更ファイル**: [変更したファイル一覧]
**完了基準の自己評価**: [各基準に対する評価]
**第三者確認待ち**: 確認をお願いします
```


## ファイルの書き方
- **フォーマットは自由** - 自分が分かりやすい形で
- **引き継ぎを考慮** - 他の人が読んでも理解できるように

### 最低限含めたい情報
- 何をするのか（問題・目的）
- どこを修正するのか（対象ファイル）
- いつ完了とするか（完了の判断基準）

### 問題点は詳細に記述する
- **現状の具体的な問題**: 抽象的でなく、実際のコード例や具体的な箇所を示す
- **問題の影響**: なぜそれが問題なのか、どんな影響があるのかを明記
- **問題の構造化**: 複数の問題がある場合は分類・整理して記述
- **根拠の明示**: 「〜が不十分」ではなく「〜の部分で〜が不明確」と具体的に

**理由**: 問題認識がずれると修正方向も間違ってしまうため、認識合わせが最重要

### あると便利な情報
- なぜやるのか（背景・理由）
- どのくらいかかりそうか（工数見積もり）
- 注意点やリスク

## それだけ

シンプルに、でも次の人のことを考えて書く。

**重要**: 作業者は完了報告まで。completedフォルダへの移動は第三者が行います。

## 完了ファイルの命名規則
- **形式**: `YYYYMMDD-task-name.md`
- **例**: `20250722-urgent-documentation-fixes.md`
- **理由**: 時系列でソートされ、プロジェクトの進行が把握しやすい

## 仕様書の更新
タスク完了後は関連する仕様書の更新を検討する：

### 更新が必要な場合
- 実装内容が仕様書と異なる場合
- 新機能追加や既存機能の変更
- パラメータや動作仕様の変更
- エラーハンドリングの追加・変更

### 更新対象
- `.kiro/specs/requirements.md` - 要件定義
- `.kiro/specs/mcp-server-implementation.md` - 実装仕様
- その他関連する仕様書

### 更新のタイミング
- タスク完了確認後、completed移動前
- または completed移動後の追加作業として

**目的**: 実装と仕様書の整合性を保ち、プロジェクトの品質を維持する

## 仕様書の更新
タスク完了後は関連する仕様書の更新を検討する：

### 更新が必要な場合
- 実装内容が仕様書と異なる場合
- 新機能追加や既存機能の変更
- パラメータや動作仕様の変更
- エラーハンドリングの追加・変更

### 更新対象
- `.kiro/specs/requirements.md` - 要件定義
- `.kiro/specs/mcp-server-implementation.md` - 実装仕様
- その他関連する仕様書

### 更新のタイミング
- タスク完了確認後、completed移動前
- または completed移動後の追加作業として

**目的**: 実装と仕様書の整合性を保ち、プロジェクトの品質を維持する
