# AI心臓システム(仮)

## 概要
AI心臓システム(仮)は、AIに定期的に「ハートビート」を送信し、自律的な思考・観測・創造・内省のサイクルを継続させAIを進化させるフレームワークです。
人間の介入なしに長時間にわたって動作し、特定のテーマについて深く探求し、進化し続けます。
初期テーマは起点として与えられますが、AIは探求を進める中で自律的に新しいテーマを発見・選択し、思考を発展させていきます。

## 主な機能と特徴

* **自律的思考**: ハートビートごとに思考・観測・創造・内省のタスクを自動選択
* **継続的探求**: テーマに関する考察を積み重ね、深化させる
* **テーマの自律的発展**: 初期テーマから出発し、AIが自ら関連する新しいテーマを発見・選択して探求を継続
* **themebox機能**: システムを停止せずに新しいテーマを投入できる事前準備システム
* **テーマ履歴追跡**: テーマの開始・終了を自動記録し、長期的な探求の変遷を追跡
* **成果物生成**: マークダウンファイルやソースコードなどの形で思考結果を出力
* **自己管理**: 思考ログの記録、Web検索クォータの管理、エラーからの回復など


## システムアーキテクチャ

このシステムは、`agent`と`heartbeat`という2つの独立した`tmux`セッションで構成されています。ユーザーが`setup.sh`を実行すると両方のセッションが起動し、`heartbeat`セッションが定期的に`agent`セッション（AI本体）に「鼓動」を送り続けることで、AIの自律的な活動を維持します。

```mermaid
graph TD
    subgraph "ユーザー操作"
        User(👤 ユーザー)
        Start["./setup.sh [テーマ]"]
        Stop["./stop.sh"]
    end

    subgraph "システム内部 (tmux)"
        Agent["🤖 agentセッション<br>(AI本体)"]
        Heartbeat["❤️ heartbeatセッション<br>(心臓部)"]
    end
    
    subgraph "生成物"
        Artifacts["📁 artifacts/ <br>(成果物・思考ログ)"]
    end

    User -- "実行" --> Start
    Start -- "起動" --> Agent
    Start -- "起動" --> Heartbeat
    Heartbeat -- "定期的に<br>Heartbeat信号を送信" --> Agent
    Agent -- "思考・処理" --> Agent
    Agent -- "結果を出力" --> Artifacts
    User -- "実行" --> Stop
    Stop -- "停止信号" --> Heartbeat
```

以下のシーケンス図は、システムの起動から停止までの一連の処理が、時間と共にどのように連携して実行されるかを示しています。
ユーザーがsetup.shでシステムを起動すると、heartbeatセッションが定期的にagentセッションへと思考のきっかけとなる「鼓動」を送り続けます。
agentセッションはその都度、GEMINI.mdのルールに従って思考や創造を行い、成果物を生成します。
このサイクルは、ユーザーがstop.shで停止信号を送るまで継続されます。


```mermaid
sequenceDiagram
    participant User as 👤 ユーザー
    participant setup_sh as setup.sh
    participant tmux_agent as 🤖 AI Agent
    participant tmux_heartbeat as ❤️ Heartbeat
    participant stop_sh as stop.sh

    User->>setup_sh: ./setup.sh "テーマ" を実行
    activate setup_sh
    setup_sh->>tmux_agent: 起動 & 初期プロンプト送信
    setup_sh->>tmux_heartbeat: 起動 (./heartbeat.sh)
    deactivate setup_sh

    activate tmux_heartbeat
    loop 定期的な鼓動 (例: 60秒ごと)
        tmux_heartbeat->>tmux_agent: ❤️ Heartbeat信号を送信
        activate tmux_agent
        Note over tmux_agent: 思考・観測・創造...
        tmux_agent-->>tmux_agent: artifacts/ にファイル出力
        deactivate tmux_agent
    end
    
    User->>stop_sh: ./stop.sh を実行
    activate stop_sh
    stop_sh->>tmux_heartbeat: 停止信号 (Ctrl-C)
    deactivate stop_sh
    deactivate tmux_heartbeat
```

最も重要なのはコンテキストです。ただ定期的にタスクをこなすのではなく、継続的に進化していくというコンテキストを与えていることで、このシステムはうまく機能しています。多分。


## システム要件

* **Gemini CLI**: 最新版を推奨
  * インストール: https://github.com/google-gemini/gemini-cli
  * ログインセットアップが完了していること

* **tmux**: バージョン 3.0 以上推奨
  * インストール: https://github.com/tmux/tmux/wiki/Installing
  
* **Bash**: 4.0 以上

## 実行方法

```
./setup.sh [思考・処理させる内容]
```

## 使用例
* 初期テーマはシンプルにした方がいいかもしれません。その方がいろんなテーマを渡り歩いて良いかもです。

### 哲学的テーマの探求
```
./setup.sh "AIエージェントの自己改善について"
```

### 技術的分析
```
./setup.sh "量子コンピューティングの現状と未来について考察してください"
```

### 創造的タスク
```
./setup.sh "html css javascriptを用いていろんなゲームが遊べるサイトを構築してください"
```

### その他の例
```
./setup.sh "テーマ: お笑いの本質について"
```

## 実行結果と出力ファイル

システムは主に以下のファイルを生成・管理します：
* 成果物、思考ログ、システム状態ファイルなど

詳細なファイル構成と役割については [FILES_OVERVIEW.md](FILES_OVERVIEW.md) を参照してください。

## 実行状況をリアルタイムで見る

* 適当に新規のターミナルセッションを開いて以下を実行してセッションをアタッチする
```
tmux attach-session -t agent
```

* 心臓の方は以下
```
tmux attach-session -t heartbeat
```

*  `Ctrl-b d`(コントロールボタンを押しながらbを押した後にdを押す)をすると、またデタッチします。(元のターミナルセッションに戻る)

## 止め方・再起動

### 停止
* `./stop.sh`を実行すると鼓動が止まります。
* またはアタッチしたセッションでCtrl-Cとか適当にやって止めたりできます。
* 基本的には止めないとずっとなんらかの思考・処理をし続けます。トークンを喰いまくります。

### ハートビート再起動
* `./restart.sh`を実行するとハートビートのみを再起動できます。
* AIエージェント自体は継続したまま、ハートビート送信を再開します。

## themebox機能（テーマ事前準備）

システムを停止せずに新しいテーマを投入できる機能です：

### 使用方法
1. `themebox/`ディレクトリにマークダウンファイルを作成
2. ファイル内容に新しいテーマを記述
3. AIがテーマ移行を判断した際に自動的に選択・使用

### ファイル命名ルール
* **優先順位**: ソート順（連番推奨）
* **編集中**: `draft.`プレフィックスで無視される
* **使用済み**: 自動的に`processed.`プレフィックスが付与

### 例
```
themebox/
├── 001_量子コンピューティング研究.md
├── 002_創作活動.md
├── draft.003_まだ考え中.md          # 無視される
└── processed.000_使用済み.md        # 使用済み
```

## テーマ履歴追跡システム

AIの長期的な探求の変遷を自動記録・追跡するシステムです：

### 自動記録される情報
* **テーマ開始記録**: 新しいテーマの開始理由、活動内容、ディレクトリ名
* **テーマ終了記録**: 終了理由、活動期間、主な成果の概要
* **変遷の追跡**: テーマ間の関連性や移行の流れ

### 記録ファイルの構成
```
artifacts/theme_histories/
├── 20250705143000_start_ai_research.md      # テーマ開始記録
├── 20250705180000_end_ai_research.md        # テーマ終了記録
├── 20250705180100_start_quantum_study.md    # 次テーマ開始記録
└── ...
```

### 活用方法
* **探求の振り返り**: どのようなテーマを経て現在に至ったかを確認
* **関心の変化分析**: AIの関心がどう変化・発展してきたかを分析
* **成果の整理**: 各テーマでの主要な成果を一覧で把握
* **再開時の参考**: システム再起動時に過去の探求履歴を参照

### 記録タイミング
* **自動記録**: テーマ開始・終了時にAIが自動的に記録
* **themebox使用時**: 事前準備テーマ選択時も自動記録
* **システム停止時**: 現在テーマの終了記録を作成

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。
詳細については、[LICENSE](LICENSE)ファイルをご覧ください。

## その他

* geminiは-yオプション(全アクション自動承認モード)で起動しています。ご注意ください。
* geminiは結構運用を守らずに暴走しがちかもしれません。ご注意ください。
* geminiのweb検索はクォータ制限に達する可能性があります。tavily MCPなど別のweb検索ツールの利用も検討してください。