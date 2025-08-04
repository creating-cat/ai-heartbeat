# AI心臓システム はじめてのガイド

このガイドでは、AI心臓システムを実際に動かして結果を確認するまでの最短ルートを説明します。

## 前提条件

以下がインストール済みであることを確認してください：

- **Gemini CLI** (ログイン済み)
- **tmux** 
- **Node.js** (18.0以上)

```bash
# 確認コマンド
gemini --version
tmux -V
node --version
```

## ステップ1: MCPツールのセットアップ

```bash
cd mcp/ai-heartbeat-mcp
npm install
npm run build
```

**注意**: エラーが出てもシステムの基本機能は動作します。

## ステップ2: サンプルテーマで起動

```bash
./setup.sh "未来の図書館がどのようなものになるかについて考察してみてください"
```

起動が成功すると、以下のようなメッセージが表示されます：
```
[SUCCESS] AI心臓システムが起動しました
[INFO] Agent session: agent
[INFO] Heartbeat session: heartbeat
```

## ステップ3: 実行状況を確認

### AIの活動をリアルタイムで見る

```bash
# 新しいターミナルを開いて実行
tmux attach-session -t agent -r
```

AIが思考・創造活動を行っている様子が表示されます。

**セッションから抜ける**: `Ctrl-b d` (Ctrl+bを押した後にd)

### ハートビートの状況を確認

```bash
# 別のターミナルで実行
tmux attach-session -t heartbeat -r
```

60秒ごとにハートビートが送信される様子が確認できます。

### ログファイルで確認

```bash
# ハートビートログをリアルタイム監視
tail -f logs/heartbeat_*.log
```

## ステップ4: 生成された成果物を確認

AIが活動を開始すると、以下の場所にファイルが生成されます：

```bash
# 現在のテーマディレクトリを確認
ls -la ai-works/artifacts/

# 活動ログを確認
ls -la ai-works/artifacts/*/histories/

# 最新の活動ログを読む
cat ai-works/artifacts/*/histories/*.md | tail -50
```

### 典型的な出力例

```
ai-works/artifacts/
└── 20250104143000_future_library/
    ├── histories/
    │   ├── 20250104143000.md  # 最初の活動ログ
    │   ├── 20250104144000.md  # 2回目の活動ログ
    │   └── 20250104145000.md  # 3回目の活動ログ
    ├── library_vision_2040.md      # 未来図書館のビジョン
    ├── technology_integration.md   # 技術統合の分析
    └── user_experience_design.md   # ユーザー体験の設計
```

## ステップ5: AIの思考内容を確認

活動ログファイルを開いて、AIがどのような思考を行っているかを確認してみましょう：

```bash
# 最新の活動ログを表示
find ai-works/artifacts/ -name "*.md" -path "*/histories/*" | sort | tail -1 | xargs cat
```

活動ログには以下のような内容が記録されています：
- AIが選択した活動の種類（思考・観測・創造・内省）
- 具体的な思考内容や分析結果
- 生成した成果物の説明
- 次の活動への計画

## ステップ6: システムを停止

```bash
./stop.sh
```

## 🎉 成功！次にできること

システムが正常に動作することを確認できました。次は以下を試してみてください：

### 独自のテーマで実行
```bash
./setup.sh "あなたが探求したいテーマ"
```

### 別のテーマで実行
```bash
./setup.sh "機械学習の最新動向について分析してください"
```



## 📚 さらに詳しく学ぶ

- **[USER_GUIDE.md](USER_GUIDE.md)**: 各種機能の詳細な使い方とトラブルシューティング
- **[SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md)**: システムの技術的詳細

## ❓ 問題が発生した場合

何か問題が発生した場合は、**[USER_GUIDE.md のトラブルシューティング](USER_GUIDE.md#トラブルシューティング)** を参照してください。症状別の詳細な解決方法が記載されています。