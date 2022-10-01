# mip-docker-swarm
MIPテストネットへの対応として、チェーンごとの別サーバー化が必要なので、全ノードをうまーく統合管理できるよう、docker swarmを活用することにしました
(最初はkubernetesでやろうとしたけどまだ慣れているこっちから作ることにしました）。

構造は画像のとおり。
![thegraph-mip-pic01](https://user-images.githubusercontent.com/15893314/193045327-07b08c45-a31e-4640-a26a-a95fe28f9a4c.png)

今回の構成では、Contabo Cloud VPS XLをチェーン数分＋マネージャーノード1台を借りて構成を作ることにしました（私は、ということなので皆さんはnotionから見て大丈夫な性能で十分です）。
最初のブランチphase0では、必要となるインデックスノード、クエリノードのみをホストします。
また、ネットワーク処理としてtraefikを、docker swarmのWebUIとしてswarmpitをインストールしています。

手続きは、以下のとおりです。
1. VPSを契約する（最低2台）
1. ENS(goerli), ドメインを取得する
1. VPSの初期設定をする（https://ayame.space/2021/03/ubuntu-20-04-initialize/ のDocker環境の構築直前までぐらいやれば十分）
1. dockerをインストールする
1. githubレポをクローンする
1. スクリプトをいくらか動かして設定をする
1. 動くか確認する

ここでは、最初の1~3を省略し、4からやっていきます。
2についてのみ、注意点があります。
ドメイン紐付けは、次のように行なってください。
| サービス名 | ドメイン | 割当IP |
| :----------------------------: | :----------------------------: | :----------------------------: |
| traefik | traefik.sld.tld | サーバー（マネージャー）のIP |
| swarmpit | swarmpit.sld.tld | サーバー（マネージャー）のIP |
| prometheus | prometheus.sld.tld | サーバー（マネージャー）のIP |
| grafana | grafana.sld.tld | サーバー（マネージャー）のIP |
| query | query.sld.tld | サーバー（マネージャー）のIP |

## 4. dockerをインストールする
dockerは、次の手続きでインストールしましょう。ここから、*サーバーごとに実施することを明記したコマンドを除き、使用するサーバー全て*で同じことを行ってください。
```
curl -fsSL https://get.docker.com/ | sh
```
この後、
```
sudo usermod -aG docker [ユーザー名]
sudo service docker restart
```
を実施し、ターミナルを開きなおしましょう。
これにより、非rootユーザーでもdockerを使用できます。

## 5. githubレポをクローンする
このレポのスクリプトでほぼインストールは完了するので、次の順番でコードを入れていきましょう。
```
sudo apt-get install -y git
git clone https://github.com/liray-unendlich/mip-docker-swarm.git
cd mip-docker-swarm
cp example.env .env
```
ここまでで、コードのダウンロードが完了しました。
最後の行で、example.envを.envとしてコピーしましたので、.envを自分用の設定に変更しましょう。
example.env自体に、envがそれぞれどのような意味か記載しています。

## 6. スクリプトを動かして設定する
それでは、スクリプトを使って、サーバーごとの初期設定（docker swarmの設定用）を行いましょう。
まず、次のコマンドを、_サーバー（マネージャー）_ に対して実施します。
```
chmod +x init-phase0-manager.sh
bash init-phase0-manager.sh
```
スクリプト実行時、管理者パスワードの入力が必要となります。また、最後には他サーバーが同じクラスターに入るためのトークンが出力されるので、メモしましょう(このトークンは、`docker swarm join-token worker`によって再表示できます）。

このスクリプトによって、docker swarmのクラスターが生成され、traefik/swarmpit/prometheus/grafanaをインストールしました。

次に、サーバー（各チェーン用）の初期設定を実施しましょう。以下のコマンドを _サーバー（各チェーン用）_ で実行してください。※サーバー（各チェーン用）で、3~5を実施した後に実施してください。
```
chmod +x init-phase0-worker.sh
bash init-phase0-worker.sh
```
このスクリプトでは、
- 同期するチェーン（ホスト名に使用します）
- クラスター追加トークン（上のサーバー（マネージャー）スクリプトの終了時に表示されたトークン）
を入力する必要があります。

ここまでで、最低二つのサーバーが同じクラスター上に統合されました。実際に、統合されていることを確認するため、Web UI(Swarmpit)を確認しましょう。

env(##5)で設定した"swarmpit.sld.tld"に接続してみましょう。すると、最初にアカウント設定を要求された後、ログインできるようになるはずです。ここでは、複数のサーバーにまたがって同じクラスターのサーバーの処理状況やプロセス状況を確認することが出来ます（下に例画像を張り付けています）。後で初期設定をする、インデックスサーバーの設定のログや、様々な設定をWebUIから変更できます。

次に、実際にphase0を完了するため、インデックスサーバーのインストールを行います。

## 7. phase0のためのインデックスサーバーを設定する
次のコマンドを、サーバー（マネージャー）上で実施してください。
```
chmod +x add-phase0-worker.sh
bash add-phase0-worker.sh
```
このスクリプトでは、
- インデックスするチェーン名（6で設定したサーバーと同じ。例えばgnosis）
- チェーンのRPC（アーカイブノードが必要）のURL
を入力する必要があります。このスクリプトが完了すると、6で確認したswarmpitで、インデックスサービスの状態を見ることが出来るはずです。

## 8. 使い方に慣れる
今回、以下のdocker stackを生成・運用しています。
- Swarmpit(docker swarmのWebUI. このスクリプトでは、configをdocker swarmの機能を使用してアップロードしているので、原理的には、docker swarmにサーバーを入れた後は、全てSwarmpit上からこれからは設定が出来るようになります。ただし、phase0で要求されているcurlコマンドはVPS上でしか出来ないようにしています（セキュリティを考慮しています）)
- Traefik(URLのハンドリングをしてくれています。SSL証明書等の発行もまとめてやってくれます。basicauthもやっています)
- Prometheus(index-node, query-nodeや、それぞれのノードのnode-exporterから情報を受け取り、蓄積しています)
- Grafana(prometheusから受け取った情報や、postgreSQLから取り出したデータを可視化します)
- postgreSQL
- index-node(graph-nodeの役割がインデックスのもの。)

実際にいろんな画面（特にSwarmpitとGrafana）を見てみてください。

## 9. phase0のミッションを確認する
phase0では、次のミッションがあります。
- prometheusにbasicauthを実装する
- prometheusのSSLエンドポイントを提供する
- query-nodeのSSLエンドポイントを提供する
- gnosis chain上で、複数のサブグラフをインデックスする
https://thegraphfoundation.notion.site/The-Graph-MIPs-Phase-0-Indexer-Setup-f411f375f2ab4d6bbb9df55481cb3bec <br>
をご確認ください。

このうち、prometheusのbasicauth実装/prometheusのSSLエンドポイント/query-nodeのSSLエンドポイントは既に完了しています。(.envに記載されているそれぞれのユーザー名・パスワードが該当する情報です)そのため、最後のgnosis chain上でのサブグラフインデックスのみ、実施していきましょう。

サブグラフのインデックスは、サーバー（gnosis）上で次のコマンドを実施することで行うことが出来ます。
```
docker exec -it $(docker ps | grep index-node | cut -c 1-12) bash
apt install -y curl
```
```
curl --location --request POST 'http://localhost:8020' --header 'Content-Type: application/json' --data-raw '{"method":"subgraph_create","jsonrpc":"2.0","params":{"name":"*Subgraph Name*"},"id":""}'
```
```
curl --location --request POST 'http://localhost:8020' --header 'Content-Type: application/json' --data-raw '{"method":"subgraph_deploy","jsonrpc":"2.0","params":{"name":"*Subgraph Name*","ipfs_hash":"*IPFS Hash*"},"id":""}'
```
この時、*Subgraph Name*, *IPFS Hash* は下の表からそれぞれ入力ください。

| Subgraph Name | IPFS Hash |
| --- | --- |
| Sushiswap-Gnosis | QmW8Cbb2R4ZHWGsrYjNJKRjoKKcPeDTNK6rdipfQQaAhd6 |
| Connext-NXTPv1-Gnosis | QmWq1pmnhEvx25qxpYYj9Yp6E1xMKMVoUjXVQBxUJmreSe |
| 1Hive-GardenGC | QmSqJEGHp1PcgvBYKFF2u8vhJZt8JTq18EV7mCuuZZiutX |
| Giveth-Economy-Gnosis | QmeVXKzGKSyfEQib4MzeZveJgDYJCYDMMHc1pPevWeSbsq |

同期が完了するタイミングは、Grafanaのdashboardである、"Indexing Status Overview" で確認してください。

同期が進んでおり、
query.sld.tld/subgraphs/name/1Hive-GardenGC/graphql
への接続が出来れば（GraphQLのページが表示されればOK）問題なく設定が出来ています。
