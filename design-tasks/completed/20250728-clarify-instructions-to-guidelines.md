# AIの自律性を尊重するための指示からガイドラインへのドキュメント修正

## 1. 問題点 (What)

AI向けドキュメントの一部に、AIの自律的な判断を妨げる可能性のある「必須ルール」や「具体的な指示」として記述されている箇所が存在する。

これらは、AIが判断に迷った際の「参考ガイドライン」や「思考のヒント」として提示する方が、AIの成長と柔軟な対応を促進する上で望ましい。

**該当箇所**:

-   **`GEMINI.md`**: `成果物出力の判断フロー`が厳格なルールになっており、AIが「未完成だが重要な中間成果物」などを保存しにくい。
-   **`ACTIVITY_DETAILS.md`**: 各活動の`視点選択ガイド`が「推奨パターン」として提示されており、AIの創造的な思考を制限する可能性がある。
-   **`ERROR_HANDLING.md`**: `代替手段選択フロー`や`目標調整の判断基準`が具体的な指示になっており、未知のエラーに対する柔軟な対応を阻害する可能性がある。
-   **`THEME_SYSTEM.md`**: `テーマ完了の判断フロー`や`専門家コンテキストの比較検討`が厳格なステップとして定義されており、AIの高度な戦略的判断の裁量を狭めている。

## 2. なぜやるのか (Why)

-   **AIの自律性の尊重**: AIが自分自身の状況を分析し、最適な行動を自ら決定する能力を養う。
-   **創造性の解放**: 厳格なルールから解放し、AIがより柔軟で創造的な思考パターンを試せるようにする。
-   **堅牢性の向上**: AIが「ルールにない状況」に直面した際に思考停止せず、自ら解決策を見つけ出す訓練になる。
-   **「AIファースト」設計の徹底**: AIの成長を促すことを最優先としたドキュメント設計を一貫させる。

## 3. 修正対象 (Where)

-   `ai-works-lib/GEMINI.md`
-   `ai-works-lib/ai-docs/ACTIVITY_DETAILS.md`
-   `ai-works-lib/ai-docs/ERROR_HANDLING.md`
-   `ai-works-lib/ai-docs/THEME_SYSTEM.md`

## 4. 具体的な修正内容 (How)

各該当箇所で、現在の「具体的な指示」や「必須フロー」を、AIの自律的な判断を促す「参考ガイドライン」や「思考のフレームワーク」という位置づけに修正する。

-   **表現の変更**:
    -   「〜に従って実行してください」→「基本は自律的に判断し、迷った場合は以下のガイドラインを参考にしてください」
    -   「必須フロー」「推奨パターン」→「思考のヒント」「判断を助けるための観点」
-   **構成の変更**:
    -   まずAIの自律的判断を促す一文を配置し、その後に判断に迷った場合のガイドラインを提示する構成に変更する。

## 5. 完了の判断基準 (When)

-   [ ] `GEMINI.md`の成果物出力フローが、必須ルールから判断ガイドラインに修正されている。
-   [ ] `ACTIVITY_DETAILS.md`の各視点選択ガイドが、推奨フローから思考のヒントに修正されている。
-   [ ] `ERROR_HANDLING.md`のエラー対処フローが、必須手順から問題解決のフレームワークに修正されている。
-   [ ] `THEME_SYSTEM.md`のテーマ管理フローが、厳格なステップから戦略的判断を助ける観点に修正されている。
-   [ ] 全ての修正が、AIの自律性を尊重するという目的に沿っている。

## 6. 見積もり

-   工数: 1.0h
-   優先度: 中