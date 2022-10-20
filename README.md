# mip-docker-swarm

MIP テストネットへの対応として、チェーンごとの別サーバー化が必要なので、全ノードをうまーく統合管理できるよう、docker swarm を活用することにしました
(最初は kubernetes でやろうとしたけどまだ慣れているこっちから作ることにしました）。

構造は画像のとおり。
![mip-powerpoint](https://user-images.githubusercontent.com/15893314/196847508-ed85f067-45ba-4881-a333-7f25209154ad.png)


今回の構成では、Contabo Cloud VPS XL をチェーン数分＋マネージャーノード 1 台を借りて構成を作ることにしました（私は、ということなので皆さんは notion から見て大丈夫な性能で十分です）。
最初のブランチ phase0 では、必要となるインデックスノード、クエリノードのみをホストします。
また、ネットワーク処理として traefik を、docker swarm の WebUI として swarmpit をインストールしています。

手続きは、以下のとおりです。

1. VPS を契約する（最低 2 台）
1. ENS(goerli), ドメインを取得する
1. VPS の初期設定をする（https://ayame.space/2021/03/ubuntu-20-04-initialize/ の Docker 環境の構築直前までぐらいやれば十分）
1. docker をインストールする
1. github レポをクローンする
1. スクリプトをいくらか動かして設定をする
1. 動くか確認する

ここでは、最初の 1~3 を省略し、4 からやっていきます。
2 についてのみ、注意点があります。
ドメイン紐付けは、次のように行なってください。
| サービス名 | ドメイン | 割当 IP |
| :----------------------------: | :----------------------------: | :----------------------------: |
| traefik | traefik.sld.tld | サーバー（マネージャー）の IP |
| swarmpit | swarmpit.sld.tld | サーバー（マネージャー）の IP |
| prometheus | prometheus.sld.tld | サーバー（マネージャー）の IP |
| grafana | grafana.sld.tld | サーバー（マネージャー）の IP |
| query | query.sld.tld | サーバー（マネージャー）の IP |
| indexer | indexer.sld.tld | サーバー（マネージャー）の IP |
| console | console.sld.tld | サーバー（マネージャー）の IP |

## 4. docker をインストールする

docker は、次の手続きでインストールしましょう。ここから、*サーバーごとに実施することを明記したコマンドを除き、使用するサーバー全て*で同じことを行ってください。

```
curl -fsSL https://get.docker.com/ | sh
```

この後、

```
sudo usermod -aG docker [ユーザー名]
sudo service docker restart
```

を実施し、ターミナルを開きなおしましょう。
これにより、非 root ユーザーでも docker を使用できます。

## 5. github レポをクローンする

このレポのスクリプトでほぼインストールは完了するので、次の順番でコードを入れていきましょう。

```
sudo apt-get install -y git
git clone https://github.com/liray-unendlich/mip-docker-swarm.git
cd mip-docker-swarm
git checkout phase1
cp example.env .env
```

ここまでで、コードのダウンロードが完了しました。
最後の行で、example.env を.env としてコピーしましたので、.env を自分用の設定に変更しましょう。
example.env 自体に、env がそれぞれどのような意味か記載しています。

## 6. スクリプトを動かして設定する(Phase0 やってない人はここから！)

それでは、スクリプトを使って、サーバーごとの初期設定（docker swarm の設定用）を行いましょう。
まず、次のコマンドを、_サーバー（マネージャー）_ に対して実施します。

```
chmod +x init-manager.sh
bash init-manager.sh
```

スクリプト実行時、管理者パスワードの入力が必要となります。また、最後には他サーバーが同じクラスターに入るためのトークンが出力されるので、メモしましょう(このトークンは、`docker swarm join-token worker`によって再表示できます）。

このスクリプトによって、docker swarm のクラスターが生成され、traefik/swarmpit/prometheus/grafana をインストールしました。

次に、サーバー（各チェーン用）の初期設定を実施しましょう。以下のコマンドを _サーバー（各チェーン用）_ で実行してください。※サーバー（各チェーン用）で、3~5 を実施した後に実施してください。

```
chmod +x init-worker.sh
bash init-worker.sh
```

このスクリプトでは、

- 同期するチェーン（ホスト名に使用します）
- クラスター追加トークン（上のサーバー（マネージャー）スクリプトの終了時に表示されたトークン）
- マネージャーサーバーの IP
  を入力する必要があります。

ここまでで、最低二つのサーバーが同じクラスター上に統合されました。実際に、統合されていることを確認するため、Web UI(Swarmpit)を確認しましょう。

env(##5)で設定した"swarmpit.sld.tld"に接続してみましょう。すると、最初にアカウント設定を要求された後、ログインできるようになるはずです。ここでは、複数のサーバーにまたがって同じクラスターのサーバーの処理状況やプロセス状況を確認することが出来ます（下に例画像を張り付けています）。後で初期設定をする、インデックスサーバーの設定のログや、様々な設定を WebUI から変更できます。
![image](https://user-images.githubusercontent.com/15893314/193424568-f43cead3-bdb2-44ff-bb1c-85151d7a7c2e.png)

## 7. phase1 の設定をする（Phase0 やった人はここから！）

次に、実際に phase1 を完了するため、インデックスサーバーのインストールを行いましょう。以下のコマンドを _サーバー（マネージャー）_ で実施してください。

```
git pull
git checkout phase1
chmod +x update-manager.sh phase1.sh
bash update-manager.sh
bash phase1.sh
```

phase1.sh の実行時、次の情報を入力する必要があります（.env に記載していれば不要です。一度 phase1.sh 実行時に入力すれば、.env に記載します）。それぞれの意味は、最下部に説明文を入れました。

- goerli の フルノード RPC API URL アドレス(infuraとか)
- インデクサーのアドレスとして使用する goerli ETH アドレス
- 該当アドレスの mnemonic
- インデクサーのサーバーの緯度、経度（（xx.xx yy.yy）の形式で入力してください）
- インデクサーのドメイン
- コンソールのドメイン（インデクサーを操作するためのコンソール。console.sld.tldで接続できます）
- コンソールのユーザー名
- コンソールのパスワード
- goerli のアーカイブノード RPC API URL アドレス(alchemy/ankr)
- 同期するチェーン名（gnosis と入力してください）

最初の phase1.sh 実行時は 10 分~15 分程度の時間がかかります。
完了すると、indexer-gnosis/indexer という stack が swarmpit に生成されます。また、grafana の dashboard が更新されているはず・・・です！

このスクリプトが完了すると、6 で確認した swarmpit で、インデックスサービスの状態を見ることが出来るはずです。
![image](https://user-images.githubusercontent.com/15893314/193424539-076714c2-8dfb-4078-9cc7-2d6d60f4aa78.png)
これにて、phase1 の途中までが完了します。

## 8. phase1 のミッションを確認する

phase1 では、次のミッションがあります。

- 新しい goerli ETH アドレスを作る（Mission1）
- The Graph のテストネットインデクサーになる（Mission2）
- インデクサーとしての活動を開始し、収益化を開始する（Mission3）

https://thegraphfoundation.notion.site/Phase-1-Indexer-Account-Setup-Protocol-Interaction-eba1c9d696fe4f9ba0e11de441914f0e

をご確認ください。

収益化については、また別途で記載します・・・・

### phase1 Mission1をクリアする
#### アドレスをフォームから提出する
phase1 Mission1はフォーム(https://thegraph.typeform.com/to/LyTtvRqP )からgoerli ETH アドレスを提出することで完了できます

### phase1 Mission2 をクリアする（2022/10/22以降）
下は、2022/10/22以降に開始してください。
#### インデクサー登録する

https://testnet.thegraph.com でインデクサーになるため、200kGRT をステーキングする必要があります。

1. https://testnet.thegraph.com へ行く
1. 上の goerli ETH アドレスを設定した Metamask で接続する
1. 右上のアバターをクリックする
1. Indexing タブをクリックし、Stake ボタンを押す（この時、200kGRT をステーキング）

これが完了すると、インデクサーとしての登録が完了します。※オペレーター設定はオプションなので、Mission 2 とは直接関係ありません。

#### オペレーターを設定する

次に、オペレーターとしてサブのウォレットを設定します（インデクサーウォレットとオペレーションウォレットを分ける人はこれをやるとよい）。

1. https://testnet.thegraph.com へ行く
1. 上の goerli ETH アドレスを設定した Metamask で接続する
1. 右上のアバターをクリックする
1. Operators ボタンをクリックし、+ ボタンを押して他のアドレスを追加する

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

## 10. もっとカスタムしたいとき

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
| サービス名 | 例 | 意味 |
| :----------------------------: | :----------------------------: | :----------------------------: |
| TRAEFIK_DOMAIN | traefik.sld.tld | traefik（ロードバランサー）のドメイン |
| TRAEFIK_USER | admin | traefikのユーザー名 |
| TRAEFIK_PASSWORD | password | traefikのパスワード |
| TRAEFIK_EMAIL | email@gmail.com | SSL証明書取得用のメールアドレス |
| SWARMPIT_DOMAIN | swarmpit.sld.tld | swarmpit（docker swarmのWebUI）のドメイン |
| DB_NAME | graph | ブロックチェーンデータを格納する postgreSQLのデータベース名 |
| DB_USER | user | postgreSQLのユーザー名 |
| DB_PASSWORD | password | postgreSQLのパスワード |
| GRAPH_NODE_VERSION | v0.28.0 | graph-node(index-node/query-node)のバージョン |
| GRAPH_NODE_LOG_LEVEL | DEBUG | graph-node(index-node/query-node)のログレベル |
| QUERY_NODE_DOMAIN | query.sld.tld | query-node（クエリ提供ノード）のドメイン |
| PROMETHEUS_DOMAIN | prometheus.sld.tld | prometheus（クライアントモニタ）のドメイン |
| PROMETHEUS_USER | user | prometheusのユーザー名 |
| PROMETHEUS_PASSWORD | password | prometheusのパスワード |
| GRAFANA_DOMAIN | grafana.sld.tld | grafana（監視ダッシュボード）の ドメイン |
| INDEXER_RPC | https://infura.io | インデクサー用のgoerli RPC API(Full Node) |
| INDEXER_ADDRESS | 0x.... | インデクサーのgoerli ETHアドレス |
| INDEXER_MNEMONIC | 12 words | INDEXER_ADDRESS に紐づくmnemonic |
| INDEXER_GEO | 49.414 11.171 | サーバー（マネージャー）の 緯度経度 |
| INDEXER_DOMAIN | indexer.sld.tld | インデクサーのドメイン |
| CONSOLE_DOMAIN | console.sld.tld | インデクサー操作用のコンソールのドメイン |
| CONSOLE_USER | user | コンソールのユーザー名 |
| CONSOLE_PASSWORD | password | コンソールのパスワード |
| CHAIN_GOERLI_RPC | https://infura.io | goerli RPC API(Archive Node), ankr/alchemy |
| CHAIN_GNOSIS_RPC | https://infura.io | gnosis RPC API(Archive Node), ankr/chainstack |

