# 「ハートビート」という用語の使われ方に関する調査と改善提案

## 1. 何をするのか（問題・目的）

`GEMINI.md` および `ai-docs` 配下のドキュメント全体について、「ハートビート」という単語の使われ方が、AIの誤解を招いたり、システムの理念と少しずれていたりする可能性がないかを調査し、改善方針をまとめる。

## 2. なぜやるのか（背景・理由）

「ハートビート」と「活動サイクル」の使い分けはかなり正確に行われているが、いくつかの箇所で、AIの行動主体をより明確にするための改善の余地が見つかった。これらの表現をより正確でAIの主観に沿ったものに改善することで、AIの自律的な判断能力をさらに向上させ、システムの理念をより深く理解させることに繋がる。

## 3. 調査結果の概要

問題点は、大きく分けて以下の2つのカテゴリに分類できる。

1.  **【A】AIの行動単位との不一致**: AIの論理的な行動単位は「活動サイクル」であるべき箇所が、システムの物理的なトリガーである「ハートビート」という言葉で表現されている。
2.  **【B】表現の曖昧さ**: AIがルールを誤解する可能性のある、少し曖昧な表現が使われている。

### 発見された問題箇所の統計
- **カテゴリA**: 16箇所（初回調査5箇所 + 追加発見11箇所）
- **カテゴリB**: 2箇所
- **合計**: 18箇所

### 修正の優先度
- **高優先度**: AIの行動原則・制限の説明（11箇所）
- **中優先度**: ドキュメント構造・エラー処理説明（5箇所）
- **低優先度**: 表現の明確化（2箇所）

---

## 4. 【カテゴリA】AIの行動単位との不一致

AIは「活動サイクル」という単位で思考・行動するため、AIの行動原則や制限を説明する際は、「ハートビート」ではなく「活動サイクル」という言葉を使う方が、AIにとってより直感的で誤解が少ない。

### 4.1 高優先度（AIの行動原則・制限の説明）

| ファイル | 該当箇所 | 現在の記述 | 修正案 |
| :--- | :--- | :--- | :--- |
| `ai-works-lib/GEMINI.md` | `第一条：リズムを守る` | `ハートビートIDを確認し、活動を実行し、必ず活動ログを記録する` | `ハートビートIDを確認し、活動サイクルを実行し、必ず活動ログを記録する` |
| `ai-works-lib/GEMINI.md` | `4. 活動実行フロー` | `ハートビートモードでは以下のステップを順次実行します` | `活動実行フローでは以下のステップを順次実行します` |
| `ai-works-lib/GEMINI.md` | `### 5. 活動ログ記録（必須）` > `目的` | `ハートビートでの活動内容を記録` | `活動サイクルでの活動内容を記録` |
| `ai-works-lib/GEMINI.md` | `自律的活動証明` | `各ハートビートでの活動内容を記録` | `各活動サイクルでの活動内容を記録` |
| `ai-works-lib/ai-docs/BASIC_OPERATIONS.md` | `### 作業範囲の制限` | `一回のハートビートで適切な範囲でファイルを作成・修正` | `一回の活動サイクルで適切な範囲でファイルを作成・修正` |
| `ai-works-lib/ai-docs/BASIC_OPERATIONS.md` | `### 複数種別の活動を実行した場合` | `一つのハートビートで実行した場合は` | `一つの活動サイクルで実行した場合は` |
| `ai-works-lib/ai-docs/BASIC_OPERATIONS.md` | `基本原則` | `一つのハートビートで一つの活動種別を推奨` | `一つの活動サイクルで一つの活動種別を推奨` |
| `ai-works-lib/ai-docs/ADVANCED_FEATURES.md` | `基本原則` | `一つのハートビートで一つの活動種別を推奨` | `一つの活動サイクルで一つの活動種別を推奨` |
| `ai-works-lib/ai-docs/ADVANCED_FEATURES.md` | `次回実行` | `次のハートビートでサブテーマ開始活動を実行` | `次の活動サイクルでサブテーマ開始活動を実行` |
| `ai-works-lib/ai-docs/TOOL_USAGE.md` | `Web検索ツール` | `1ハートビートで1回まで` | `1活動サイクルで1回まで` |
| `ai-works-lib/ai-docs/TOOL_USAGE.md` | `creative-ideation-mcp` | `1ハートビートで1回まで` | `1活動サイクルで1回まで` |

### 4.2 中優先度（ドキュメント構造・エラー処理説明）

| ファイル | 該当箇所 | 現在の記述 | 修正案 |
| :--- | :--- | :--- | :--- |
| `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md` | `理念の自律的実践` | `各ハートビートの活動ログを記録した後` | `各活動サイクルの活動ログを記録した後` |
| `ai-works-lib/ai-docs/THEME_SYSTEM.md` | `階層構造` | `ハートビートレベル（個別の活動実行）` | `活動サイクルレベル（個別の活動実行）` |
| `ai-works-lib/ai-docs/ERROR_HANDLING.md` | `重要なポイント` | `各ハートビート毎に必ず何らかのファイル出力を行う` | `各活動サイクル毎に必ず何らかのファイル出力を行う` |
| `ai-works-lib/ai-docs/ERROR_HANDLING.md` | `活動の区切り` | `そのハートビートにおける活動の「完了報告」` | `その活動サイクルにおける活動の「完了報告」` |
| `ai-works-lib/ai-docs/ERROR_HANDLING.md` | `対処方針` | `そのハートビートでの作業を完全に停止する` | `その活動サイクルでの作業を完全に停止する` |

---

## 5. 【カテゴリB】表現の曖昧さ

AIがルールを厳密に解釈した際に、意図とは異なる行動を取る可能性を秘めた表現。

| ファイル | 該当箇所 | 現在の記述 | 修正案 |
| :--- | :--- | :--- | :--- |
| `ai-works-lib/ai-docs/THEME_SYSTEM.md` | `1.1 実行条件の詳細判定` | `テーマ終了活動の直後など、ハートビートの途中でこの状態になった場合は、次のハートビートまで待機してください。` | `テーマ終了活動の直後など、活動サイクルの途中でこの状態になった場合は、現在の活動サイクルを完了してから、次の活動サイクルでテーマ開始活動を実行してください。` |
| `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md` | `ハートビートIDの役割` | `活動ログを記録する際には、その時点での最新のハートビートIDを使用する。` | `活動ログを記録する際には、活動ログ記録をトリガーした最新のハートビートのIDを使用する。` |

---

## 6. 実行手順

### 6.1 第1段階: 高優先度（AIの行動原則・制限）
- GEMINI.mdの基本的な行動原則説明（4箇所）
- BASIC_OPERATIONS.mdの活動制限説明（3箇所）
- ADVANCED_FEATURES.mdの活動原則説明（2箇所）
- TOOL_USAGE.mdのツール制限説明（2箇所）

### 6.2 第2段階: 中優先度（構造・エラー処理）
- SYSTEM_PHILOSOPHY.mdの模範例説明（1箇所）
- THEME_SYSTEM.mdの階層構造説明（1箇所）
- ERROR_HANDLING.mdのエラー処理説明（3箇所）

### 6.3 第3段階: 低優先度（表現の明確化）
- THEME_SYSTEM.mdの曖昧な表現（1箇所）
- SYSTEM_PHILOSOPHY.mdの曖昧な表現（1箇所）

## 7. 修正方針

### 7.1 カテゴリA: 用語の統一
- **基本方針**: AIの行動単位を表す「ハートビート」を「活動サイクル」に置き換える
- **判断基準**: AIの主観的な行動・判断・制限を説明する文脈かどうか
- **例外**: システムの技術的制約や物理的時間を説明する文脈では「ハートビート」を維持

### 7.2 カテゴリB: 表現の明確化
- **基本方針**: AIが誤解する可能性のある曖昧な表現を具体的で明確な記述に修正
- **重点**: タイミング、条件、手順の明確化
- **目標**: AIが迷わず正確に理解できる表現への改善

## 8. いつ完了とするか（完了の判断基準）

### 8.1 第1段階完了基準
- AIの基本的な行動原則・制限説明で「活動サイクル」が統一使用されている
- 特に重要な GEMINI.md と BASIC_OPERATIONS.md の修正が完了している

### 8.2 第2段階完了基準
- ドキュメント構造説明とエラー処理説明で用語が統一されている
- AIの理解に影響する中程度の問題が解決されている

### 8.3 最終完了基準
- 上記18箇所の修正対象が全て修正されている
- AIの行動原則が、よりAIの主観に沿った、誤解の余地のない表現で統一されている
- ドキュメント全体でAIの行動単位として「活動サイクル」が一貫して使用されている
- 曖昧な表現が具体的で明確な記述に改善されている

## 9. 期待される効果

### 9.1 AIの理解向上
- AIが自分の行動単位を正確に理解できる
- システムの物理的制約と論理的行動の区別が明確になる
- 誤解に基づく不適切な行動の減少

### 9.2 システムの一貫性向上
- ドキュメント全体での用語使用の統一
- AIファースト設計の理念の徹底
- 技術的正確性と理解しやすさの両立

### 9.3 長期的な品質向上
- AIの自律的判断能力の向上
- システムとの協調性の改善
- 継続的な学習効率の向上

