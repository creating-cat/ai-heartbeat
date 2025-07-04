# AI心臓システム(仮)

## 概要
* AIに定期的に鼓動を送り続けて、なんらかの思考や処理を続けさせる仕組み

## 前提

* gemini cliがインストールされて、ログインセットアップが完了している
  * https://github.com/google-gemini/gemini-cli

* tmuxがインストールされている
  * https://github.com/tmux/tmux/wiki/Installing

## 実行方法

```
./setup.sh [思考・処理させる内容]
```

例:

```
./setup.sh "テーマ: お笑いの本質について"
```

## 実行結果
* artifacts配下にいろんなmdファイルが生成されると思います。
* artifacts/{テーマ名}/histories/配下に思考ログが格納されます。

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

## 各ファイルの詳細

[FILES_OVERVIEW.md](FILES_OVERVIEW.md)参照


## その他
* geminiのweb検索はすぐにクォータ制限に引っかかって枯渇する可能性があります。tavily MCPなど別のweb検索ツールがあるといいかもしれません。