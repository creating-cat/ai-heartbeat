# AI心臓システム(仮)

## 概要
AI心臓システム(仮)は、AIに定期的に「ハートビート」を送信し、自律的な思考・観測・創造・内省のサイクルを継続させるフレームワークです。
人間の介入なしに長時間にわたって動作し、特定のテーマについて深く探求し続けます。
初期テーマは起点として与えられますが、AIは探求を進める中で自律的に新しいテーマを発見・選択し、思考を発展させていきます。

## 主な機能と特徴

* **自律的思考**: ハートビートごとに思考・観測・創造・内省のタスクを自動選択
* **継続的探求**: テーマに関する考察を積み重ね、深化させる
* **テーマの自律的発展**: 初期テーマから出発し、AIが自ら関連する新しいテーマを発見・選択して探求を継続
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

## 止め方

* ./stop.shを実行すると鼓動が止まります。
* またはアタッチしたセッションでCtrl-Cとか適当にやって止めたりできます。
* 基本的には止めないとずっとなんらかの思考・処理をし続けます。トークンを喰いまくります。

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。
詳細については、[LICENSE](LICENSE)ファイルをご覧ください。

## その他

* geminiは-yオプション(全アクション自動承認モード)で起動しています。ご注意ください。
* geminiは結構運用を守らずに暴走しがちかもしれません。
* geminiのweb検索はクォータ制限に達する可能性があります。tavily MCPなど別のweb検索ツールの利用も検討してください。