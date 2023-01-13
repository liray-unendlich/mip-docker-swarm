# mip-docker-swarm

MIP テストネットへの対応として、サーバーに以下の構造のサービスを稼働させ、クエリサービスを様々なチェーンで提供しましょう。
![mip-powerpoint](https://user-images.githubusercontent.com/15893314/196847508-ed85f067-45ba-4881-a333-7f25209154ad.png)

今回の構成では、Contabo Cloud VPS XL 1 台を借りて構成を作ることにしました（チェーン数が増えれば増えるほど、負荷が厳しくなる可能性があります。その場合、適宜サーバー数を増やします）。
既に、Gnosisチェーンではメインネットでのクエリ提供が開始されています。このブランチでは、あくまでテストネット用のサービス提供体制とします（管理がややこしいんですが、しょうがないです）。
また、ロードバランサーとして traefik を、docker swarm の WebUI として swarmpit/portainer をインストールします。

手続きは、以下のとおりです。

1. VPS を契約する
1. ENS(goerli), ドメイン(gunu-node.comみたいなやつ)を取得する
1. VPS の初期設定をする（https://ayame.space/2021/03/ubuntu-20-04-initialize/ の Docker 環境の構築直前までぐらいやれば十分）
1. docker をインストールする
1. github レポをクローンする
1. 以下のドキュメントに従い設定する
1. 動くか確認する
1. レポジトリの更新があったときに更新する

ここでは、最初の 1~3 を省略し、4 からやっていきます。
2 についてのみ、注意点があります。
ドメイン紐付けは、次のように行なってください。
| サービス名 | ドメイン | 割当 IP |
| :----------------------------: | :----------------------------: | :----------------------------: |
| traefik | traefik.sld.tld | サーバー（マネージャー）の IP |
| swarmpit | swarmpit.sld.tld | サーバー（マネージャー）の IP |
| portainer | swarmpit.sld.tld | サーバー（マネージャー）の IP |
| prometheus | prometheus.sld.tld | サーバー（マネージャー）の IP |
| grafana | grafana.sld.tld | サーバー（マネージャー）の IP |
| indexer | indexer.sld.tld | サーバー（マネージャー）の IP |

## 4. docker をインストールする

docker は、次のコマンドをサーバー上で実行して、インストールしましょう。

```
curl -fsSL https://get.docker.com/ | sh
```

次に、

```
sudo usermod -aG docker [ユーザー名]
sudo service docker restart
```

を実施し、ターミナルを開きなおしましょう。これにより、非 root ユーザーでも docker を使用できるようになりました。

## 5. github レポをクローンする

このレポのスクリプトでほぼインストールは完了するので、次の順番でコードを入れていきましょう。

```
sudo apt-get install -y git
git clone https://github.com/liray-unendlich/mip-docker-swarm.git
cd mip-docker-swarm
git checkout testnet
cp example.env .env
```

ここまでで、コードのダウンロードが完了しました。
最後の行で、example.env を.env としてコピーしましたので、.env を自分用の設定に変更しましょう。
example.env 自体に、env がそれぞれどのような意味か記載しています。

### 5.1 以前のデータのうち、不要なデータを削除する
これまでのMIPレポジトリと構造が変わったので、これまで動かしていた方は、次のコマンドを使ってデータを削除しましょう。
```
docker stack rm $(docker stack ls --format "{{.Name}}")
rm -r ~/mip-docker-swarm/data/postgres/*
```

## 6. スクリプトを動かして設定

それでは、スクリプトを使って、サーバーごとの初期設定（docker swarm の設定用）を行いましょう。
まず、次のコマンドを、_サーバー_ 上で実施します。

```
chmod +x init-manager.sh
bash init-manager.sh
```

スクリプト実行時、管理者パスワードの入力が必要となります。このスクリプトによって、docker swarm のクラスターが生成され、traefik/swarmpit/portainer/prometheus/grafana をインストールしました。サーバーの動作が適切になされているかを確認するため、Web UI(Swarmpit/Portainer)を確認しましょう。

env(##5)で設定した"swarmpit.sld.tld/portainer.sld.tld"に接続してみましょう。すると、最初にアカウント設定を要求された後、ログインできるようになるはずです。ここでは、複数のサーバーにまたがって同じクラスターのサーバーの処理状況やプロセス状況を確認することが出来ます（下に例画像を張り付けています）。後で初期設定をする、インデックスサーバーの設定のログや、様々な設定を WebUI から変更できます。
![image](https://user-images.githubusercontent.com/15893314/193424568-f43cead3-bdb2-44ff-bb1c-85151d7a7c2e.png)

## 7.インデクサーをgoerliテストネット上で稼働させる
次に、必要なサービスとなる、以下4サービスを稼働させます。
- インデックスノード（クエリノードが必要とするインデックス済みデータを提供する）
- クエリノード（インデックスサービスにクエリデータを提供する）
- インデクサーエージェント（Graph Networkと接続し、インデックスノードの管理を行う）
- インデクサーサービス（Graph Networkと接続し、クエリ提供を行う）
そのサービスを稼働させるために、次のコマンドをサーバー上で実行し、必要な設定ファイルの更新を始めましょう。
```
cp graph-node-config/config.tmpl graph-node-config/config.toml
nano graph-node-config/config.toml
```
このコマンドにより、次の画像のような画面が表示されるはずです。このファイルは、インデックスノード及びクエリノードが、様々なチェーンで適切にデータを取得するための設定ファイルになっています。すなわち、どんなチェーンを、どのようなエンドポイントの組からデータ取得するかを定義しています。こちらから、設定方法をご覧ください（一例も載せています）。


さて、config.tomlが適切に設定出来たら、サーバー上で、次のコマンドを一行ずつ実施します。
```
chmod +x update-indexer.sh
bash update-indexer.sh
```

このコマンドが完了すれば、swarmpit/portainerから次の画像のように設定が出来ていることがわかるはずです。

### Goerliテストネット上でインデクサーを登録する

https://testnet.thegraph.com でインデクサーになるため、200kGRT をステーキングする必要があります。

1. https://testnet.thegraph.com へ行く
1. 上の goerli ETH アドレスを設定した Metamask で接続する
1. 右上のアバターをクリックする
1. Indexing タブをクリックし、Stake ボタンを押す（この時、200kGRT をステーキング）

これが完了すると、インデクサーとしての登録が完了します。※オペレーター設定はオプションなので、テストネットの報酬とは直接関係ありません。

#### オペレーターを設定する

次に、オペレーターとしてサブのウォレットを設定します（インデクサーウォレットとオペレーションウォレットを分ける人はこれをやるとよい）。

1. https://testnet.thegraph.com へ行く
1. 上の goerli ETH アドレスを設定した Metamask で接続する
1. 右上のアバターをクリックする
1. Operators ボタンをクリックし、+ ボタンを押して他のアドレスを追加する

#### サブグラフへのアロケーション
次に、サブグラフをインデックス開始するための手続きを説明します。
portainerより、stack > indexer > indexer-cli と移動し、コンソールを開きましょう。
次のコマンドを一行ずつ入力し、アロケーションを行いましょう。
```
graph indexer allocations create QmW8Cbb2R4ZHWGsrYjNJKRjoKKcPeDTNK6rdipfQQaAhd6 割当てたい枚数 index_node_0
graph indexer allocations create QmWq1pmnhEvx25qxpYYj9Yp6E1xMKMVoUjXVQBxUJmreSe 割当てたい枚数 index_node_0
graph indexer allocations create QmSqJEGHp1PcgvBYKFF2u8vhJZt8JTq18EV7mCuuZZiutX 割当てたい枚数 index_node_0
graph indexer allocations create QmeVXKzGKSyfEQib4MzeZveJgDYJCYDMMHc1pPevWeSbsq 割当てたい枚数 index_node_0
```
このコマンドを実行すると、オペレーターウォレットからTXが発信し、アロケーションが実施されます。この後、grafanaのダッシュボードで確認すると、インデックスが開始しているはずです。

## 9. 使い方に慣れる

今回、以下の docker stack を生成・運用しています。

- Swarmpit(docker swarm の WebUI. このスクリプトでは、config を docker swarm の機能を使用してアップロードしているので、原理的には、docker swarm にサーバーを入れた後は、全て Swarmpit 上からこれからは設定が出来るようになります。ただし、phase0 で要求されている curl コマンドは VPS 上でしか出来ないようにしています（セキュリティを考慮しています）)
- Traefik(URL のハンドリングをしてくれています。SSL 証明書等の発行もまとめてやってくれます。basicauth もやっています)
- Prometheus(index-node, query-node や、それぞれのノードの node-exporter から情報を受け取り、蓄積しています)
- Grafana(prometheus から受け取った情報や、postgreSQL から取り出したデータを可視化します)
- postgreSQL
- index-node(graph-node の役割がインデックスのもの。)
- indexer-agent/service(index-node/query-node を管理し、外部から来たクエリに応答します)

実際にいろんな画面（特に Swarmpit と Grafana）を見てみてください。

## 10. レポジトリの更新に合わせて更新する
今後、サーバーの更新は、原則次の２行のコマンドを1行ごとにサーバー上で実施することで行われます。
※この中には、設定ファイルの更新は含んでいません。
```
bash init-manager.sh
bash update-indexer.sh
```

## 11. もっとカスタムしたいとき

もっとカスタムしたい人向けに、簡単なメモを入れておきます。

### 複数の RPC API を使って接続したい

swarmpit -> configs の中に、`config-日付`というファイルが見つかるはずです。このファイルの中には、下のような情報が記載されています。この config ファイルを直接サービスに読み込ませることで、ファイルを直接サーバーに受け渡しせず、設定が可能になっています。

```
[store]
[store.primary]
connection = "postgresql://DBのユーザー名:DBのパスワード@postgres:5432/DB名"
pool_size = 10

[chains]
ingestor = "index_node_gnosis"

[chains.gnosis]
shard = "primary"
provider = [ { label = "gnosis-full", url = "gnosisのfull nodeアドレス(ankr/chainstack)", features = [] },
             { label = "gnosis-archive", url = "gnosisのarchive nodeアドレス(ankr/chainstack)", features = ["archive"] },
             { label = "gnosis-trace", url = "gnosisのarchive node(traceあり)アドレス(chainstack)", features = ["archive", "trace"] }
           ]

[chains.goerli]
shard = "primary"
provider = [ { label = "goerli-full", url = "goerliのfull nodeアドレス(infura/alchemy/ankr/chainstack)", features = [] },
             { label = "goerli-archive", url = "goerliのarchive nodeアドレス(alchemy/ankr)", features = ["archive"] },
             { label = "goerli-trace", url = "goerliのarchive node(traceあり)アドレス(不明・とりあえず無くてOK)", features = ["archive", "trace"] }
           ]

[deployment]
[[deployment.rule]]
indexers = [ "index_node_gnosis" ]

[general]
query = "query_node_*"

```

ここで、[chains.gnosis]/[chains.goerli]内にある provider を次のように書き換えると、RPC API を追加できます。
ただし、features は次のように選びましょう。
| features | ノード種類 |
| --- | --- |
| [] | フルノード |
| archive | アーカイブノード |
| traces | トレースが有効なノード（アーカイブノード） |

実際にgraph-nodeにこの設定を読み込ませるには、次の手続きでやる必要があります。
1. swarmpitのstacksを選択
2. indexer-gnosisを選択
3. 右上editを選択
4. 全ての`config-日付`を新しいconfigの名前に修正
5. deployを選択

こうすると、トップページ -> Configs -> 追加したもの から、最下部を見るとどのサービスにリンクされるか表示されるので、ここでindex-node/query-nodeが追加されて入れば設定は完了です。

### envファイルの設定事項について
envファイルの設定事項がどんどん増えてきたので、以下に内容を列記します
| 項目名 | 例 | 意味 |
| :----------------------------: | :----------------------------: | :----------------------------: |
| USER_ID | 1000 | LinuxにおけるUser ID |
| GROUP_ID | 1000 | LinuxにおけるGroup ID |
| ROOT_DOMAIN | sld.tld | 他サービスが使用するベースドメイン |
| TRAEFIK_USER | admin | traefikのユーザー名 |
| TRAEFIK_PASSWORD | password | traefikのパスワード |
| TRAEFIK_EMAIL | email@gmail.com | SSL証明書取得用のメールアドレス |
| DB_NAME | graph | ブロックチェーンデータを格納する postgreSQLのデータベース名 |
| DB_USER | user | postgreSQLのユーザー名 |
| DB_PASSWORD | password | postgreSQLのパスワード |
| PROMETHEUS_USER | admin | prometheusのユーザー名 |
| PROMETHEUS_PASSWORD | password | prometheusのパスワード |
| INDEXER_RPC | https://infura.io | インデクサー用のgoerli RPC API(Full Node) |
| INDEXER_ADDRESS | 0x.... | インデクサーのgoerli ETHアドレス |
| INDEXER_MNEMONIC | 12 words | INDEXER_ADDRESS に紐づくmnemonic |
| INDEXER_GEO | "49.414 11.171" | サーバー（マネージャー）の 緯度経度 |
