# 「活動サイクル」導入に伴う関連用語の整理

## 1. 何をするのか（問題・目的）

「ハートビートサイクル」を「活動サイクル」に、「ハートビート開始/完了」を「活動開始/完了」に改めるという主要な用語変更が完了した。
この変更に伴い、ドキュメント内に残存している関連用語（特に章タイトルやシステムからの通知メッセージなど）を見直し、ドキュメント全体の思想的な一貫性をさらに高める。

## 2. なぜやるのか（背景・理由）

- **一貫性の向上**: 主要な用語を変更したため、関連する周辺用語も統一することで、AIの混乱を防ぎ、ドキュメントの可読性を高める。
- **理念の徹底**: 「ハートビートはトリガー、AIの行動単位は活動」という理念を、より細部まで反映させる。

## 3. 具体的な修正方針

文脈を考慮しつつ、以下の観点で見直しを行う。

- **AIの行動プロセスを説明する箇所**: 「活動」という主体的な言葉を優先する。
- **システムの物理的な動作を説明する箇所**: 「ハートビート」という言葉を維持する。

## 4. どこを修正するのか（対象ファイルと修正案）

### 4.1 修正の分類と優先度

修正対象を以下の3つの優先度に分類し、段階的にアプローチする：

#### 優先度A: 確実に修正（章タイトル等の構造的要素）
#### 優先度B: 慎重に判断（文脈依存の表現）
#### 優先度C: 基本的に維持（技術的制約の説明）

### 4.2 優先度A: 確実に修正すべき箇所

#### 4.2.1. `ai-works-lib/GEMINI.md` - 章タイトルの修正

- **対象**: `## 4. ハートビート実行フロー`（目次含む）
- **修正案**: `## 4. 活動実行フロー`
- **理由**: この章はAI自身の行動プロセスを説明するため、「活動」が適切
- **影響範囲**: 目次の該当箇所も同時に修正

#### 4.2.2. `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md` - 章タイトルの修正

- **対象**: `## 5. ハートビートシステムの意味`（目次含む）
- **修正案**: `## 5. ハートビートと活動サイクルの関係`
- **理由**: 内容がハートビートと活動サイクルの関係性を説明しているため、より正確なタイトル
- **影響範囲**: 目次の該当箇所も同時に修正

### 4.3 優先度B: 慎重に判断が必要な箇所

#### 4.3.1. `ai-works-lib/ai-docs/ERROR_HANDLING.md` - AIの行動指針表現

**文脈別の分類と修正方針**:

##### 修正対象（AIの行動指針）:
- **対象**: `次のハートビートで何を行うかを明確に計画する`
- **修正案**: `次の活動サイクルで何を行うかを明確に計画する`
- **理由**: AIの自律的な行動計画を表すため

- **対象**: `次のハートビートでの内省`（行動推奨の文脈）
- **修正案**: `次の活動サイクルでの内省`
- **理由**: AIの行動選択を表すため

- **対象**: `次のハートビートに作業を引き継ぐ`
- **修正案**: `次の活動サイクルに作業を引き継ぐ`
- **理由**: AIの継続的な活動を表すため

##### 維持対象（技術的制約・システム仕様）:
- **対象**: `次のハートビートで得られる新しいタイムスタンプ`
- **判断**: **維持**
- **理由**: システムの技術的な時間管理機能を表すため

- **対象**: `次のハートビートを待ってから専門家コンテキスト作成を実行`
- **判断**: **維持**
- **理由**: システムの技術的制約を説明するため

#### 4.3.2. `ai-works-lib/ai-docs/SYSTEM_PHILOSOPHY.md` - 小見出しの修正

- **対象**: `### ハートビートシステムとの協調`
- **修正案**: `### システムとの協調的な活動`
- **理由**: AIの主体的な協調行動を表現するため

### 4.4 優先度C: 基本的に維持すべき箇所

#### 4.4.1. MCPツールの技術的制約メッセージ

以下のメッセージは**技術的制約**を説明するため、「ハートビート」を維持：

- `解決方法: 次のハートビートを待ってからテーマ操作を実行してください。`
- `重要: 新しいテーマの開始は、次のハートビートまで待機してください。`
- `解決方法: 次のハートビートを待ってから専門家コンテキスト作成を実行してください。`

**理由**: これらはシステムの技術的制約（1つのハートビートIDでは1つの操作のみ）を説明しており、「ハートビート」という技術用語が正確

#### 4.4.2. その他の技術的説明

- **動作モード名**: 「ハートビートモード」→ **維持**
- **システム機能名**: 各種「ハートビート○○」→ **維持**
- **技術的時間軸**: 物理的時間経過の説明→ **維持**

### 4.5 修正時の重要な判断基準

#### 4.5.1 AIの主観性 vs システム技術性
- **AIの行動・判断・計画**: 「活動サイクル」を使用
- **システムの制約・機能・時間**: 「ハートビート」を維持

#### 4.5.2 文脈の識別方法
- **行動促進**: 「～してください」「～を計画する」→ 活動サイクル
- **制約説明**: 「～はできません」「～を待つ必要があります」→ ハートビート
- **時間軸**: 物理的時間の経過→ ハートビート

#### 4.5.3 一貫性の確保
- 同じドキュメント内で類似の文脈は統一した表現を使用
- AIの理解しやすさを最優先に判断
- 技術的正確性も同時に確保

## 5. 実行手順

### 5.1 第1段階: 優先度A（確実に修正）
- 章タイトルの修正（GEMINI.md、SYSTEM_PHILOSOPHY.md）
- 目次の対応する箇所も同時に修正
- 構造的な一貫性の確保

### 5.2 第2段階: 優先度B（慎重に判断）
- ERROR_HANDLING.mdの各箇所を文脈別に分類
- AIの行動指針は「活動サイクル」に変更
- システム技術的説明は「ハートビート」を維持
- SYSTEM_PHILOSOPHY.mdの小見出し修正

### 5.3 第3段階: 優先度C（維持確認）
- MCPツールメッセージの適切性確認
- 技術的制約説明の「ハートビート」維持を確認
- 必要に応じて説明の明確化

## 6. いつ完了とするか（完了の判断基準）

### 6.1 第1段階完了基準
- 主要な章タイトルが新しい用語体系と一致
- 目次との整合性が確保されている
- 構造的な一貫性が向上している

### 6.2 第2段階完了基準
- ERROR_HANDLING.mdで文脈に応じた適切な用語使い分けが完了
- AIの行動指針が「活動サイクル」で統一
- システム技術的説明が「ハートビート」で統一
- SYSTEM_PHILOSOPHY.mdの表現が改善されている

### 6.3 最終完了基準
- ドキュメント全体で用語の一貫性が保たれている
- AIの主観的行動は「活動サイクル」、システム技術的説明は「ハートビート」で明確に使い分けられている
- AIがシステムの理念をより深く、矛盾なく理解できる状態になっている
- 章タイトルと内容の整合性が向上している

## 7. 発見された詳細な修正対象

### 7.1 ERROR_HANDLING.mdの具体的な箇所（12箇所程度）

#### 修正対象（AIの行動指針）:
1. 「次のハートビートで何を行うかを明確に計画する」（2箇所）
2. 「次のハートビートに作業を引き継ぐ」
3. 「次のハートビートでの内省」（行動推奨文脈）
4. 「次のハートビートでの継続方法を明記」
5. 「次のハートビートでの対処」

#### 維持対象（技術的制約）:
1. 「次のハートビートで得られる新しいタイムスタンプ」
2. 「次のハートビートで、1つのテーマ操作のみを実行」
3. 「次のハートビートを待ってから」（制約説明）

### 7.2 MCPツールの具体的な箇所（3箇所）

#### 維持対象（すべて技術的制約）:
1. `createThemeExpertContextTool.ts`: 「次のハートビートを待ってから専門家コンテキスト作成を実行してください」
2. `themeLogTool.ts`: 「次のハートビートを待ってからテーマ操作を実行してください」
3. `themeLogTool.ts`: 「新しいテーマの開始は、次のハートビートまで待機してください」

### 7.3 追加で検討すべき関連表現

#### 将来的な検討事項:
- 「ハートビートモード」という動作モード名の扱い
- 「ハートビートID」の説明における一貫性
- 他のドキュメントでの類似表現の統一

## 8. 修正作業での注意点

### 8.1 文脈判断のポイント
- **主語の確認**: AIが主語→活動サイクル、システムが主語→ハートビート
- **動詞の性質**: 行動促進系→活動サイクル、制約説明系→ハートビート
- **対象読者**: AIの理解促進→活動サイクル、技術仕様説明→ハートビート

### 8.2 一貫性確保の方法
- 同じ文書内での類似表現は統一
- 修正前後での意味の変化を慎重に確認
- AIの混乱を招く可能性がある表現は避ける

### 8.3 品質確保
- 修正後の文章の自然さを確認
- 技術的正確性を損なわないよう注意
- AIにとっての理解しやすさを最優先に判断

