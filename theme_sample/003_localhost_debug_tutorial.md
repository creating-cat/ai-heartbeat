# テーマ：localhostのデバッグ方法チュートリアル

## 目的：
各種ツールを利用したlocalhostのデバッグ方法を体験し理解する。

## ステップ１

* `projects/localhost_test`ディレクトリを作成し、そこに適当な簡易ローカルサイトを作成し、viteでサーバを起動し、`http://localhost:xxxx` でアクセスできる状態を作る
  * 簡易ではありますが、ローカルサイトには少なくともhtmlとcssとjsの要素は含めておいてください。
  * サーバーはバックグラウンドで起動するようにすることを忘れないでください。

## ステップ２

* WebFetchツールを使用して簡易ローカルサイトへアクセスしてみる。
  * おそらく失敗します。失敗する理由を考察してみてください。

## ステップ3

* mult-fetch-mcp-serverのfetch_htmlツールを使用して簡易ローカルサイトへアクセスしてみる。
  * おそらく成功します。取得できた内容について考察してみてください。

## ステップ4

* mult-fetch-mcp-serverのfetch_plaintextツールを使用して簡易ローカルサイトへアクセスしてみる。
  * おそらく成功します。取得できた内容についてfetch_htmlとの比較も含めて考察してみてください。

## ステップ5

* puppeteerのpuppeteer_connect_active_tabで接続し、puppeteer_navigateでlocalhostに移動してみてください。
  * 失敗する場合は、ユーザーがリモートデバッグモードでChromeを起動していない可能性が高いです。この場合は使用を諦めて最後のステップへ進んでください。
  * 成功した場合は、さらにpuppeteer_screenshotやpuppeteer_evaluateを使用してページ内容などを取得できたりするかや、jsの処理を実行できるかなどを試してみて、その結果を考察してみてください。

## 最終ステップ

* サーバーのプロセスを終了し、これまでの全体的な結果を元に、localhostのデバッグ方法について考察する。



一連の活動が終わったら、このテーマを終了してください。
