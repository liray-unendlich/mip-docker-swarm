# mip-docker-swarm
MIPテストネットへの対応として、チェーンごとの別サーバー化が必要なので、全ノードをうまーく統合管理できるよう、docker swarmを活用することにしました
(最初はkubernetesでやろうとしたけどまだ慣れているこっちから作ることにしました）。

構造は画像のとおり。
![thegraph-mip-pic01](https://user-images.githubusercontent.com/15893314/193045327-07b08c45-a31e-4640-a26a-a95fe28f9a4c.png)

今回の構成では、1台のVPSサーバーに上の構造を全て埋め込むことにしました。ロードバランサーとしてtraefikを、docker swarmのWebUIとしてportainerをインストールしています。また、管理サービスへのログインをSSO化するため、autheliaを認証サービサーとして使用しています。

手続きは、以下のとおりです。
1. VPSを契約する
2. ENS(goerli), ドメインを取得する
3. VPSの初期設定をする（https://ayame.space/2021/03/ubuntu-20-04-initialize/ のDocker環境の構築直前までぐらいやれば十分）
4. SMTPを設定する
5. dockerをインストールする
6. githubレポをクローンする
7. .envを編集する
8. スクリプトで設定をする
9. 動くか確認する

ここでは、最初の1~3を省略し、4からやっていきます。
2についてのみ、注意点があります。
ドメイン紐付けは、次のように行なってください。
| サービス名 | ドメイン | 割当IP |
| :----------------------------: | :----------------------------: | :----------------------------: |
| traefik | traefik.sld.tld | サーバーのIP |
| authelia | authelia.sld.tld | サーバーのIP |
| portainer | portainer.sld.tld | サーバーのIP |
| prometheus | prometheus.sld.tld | サーバーのIP |
| grafana | grafana.sld.tld | サーバーのIP |
| indexer | indexer.sld.tld | サーバーのIP |

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
git checkout mainnet
cp example.env .env
```
ここまでで、コードのダウンロードが完了しました。
最後の行で、example.envを.envとしてコピーしましたので、.envを自分用の設定に変更しましょう。
example.env自体に、envがそれぞれどのような意味か記載しています。

## 6. スクリプトを動かして設定する
それでは、スクリプトを使って、サーバーの初期設定（docker swarmの設定用）を行いましょう。
まず、次のコマンドを、_サーバー_ 上で実施します。
```
chmod +x init-manager.sh
bash init-manager.sh
```
スクリプト実行時、管理者パスワードの入力が必要となります。また、最後には他サーバーが同じクラスターに入るためのトークンが出力されるので、メモしましょう(このトークンは、`docker swarm join-token worker`によって再表示できます）。

このスクリプトによって、docker swarmのクラスターが生成され、traefik/portainer/authelia/prometheus/grafanaがインストールされました。実際に、SSO及びその他の動作が適切に動いているか、確認しましょう。
1. authelia.sld.tld にアクセスする
   authelia.sld.tldにアクセスすると、ログイン画面が表示されます。この時、.envに入力したアカウントのID/パスワードでログインしてください。すると、次に2段階認証の設定を求められますので、お好みの方法で設定してください。
2. portainer.sld.tld にアクセスする
   最初は、adminアカウントの生成が必要になります。その後で、https://www.authelia.com/integration/openid-connect/portainer/ を確認し、SSO設定が必要になります。
3. grafana/prometheus.sld.tld にアクセスする
   portainerにSSOでアクセスできるようになったら、grafana/prometheusにアクセスしましょう。autheliaの設定が正常に行われていれば、認証を行ったブラウザでのみ接続できるはずです。

portainerでは、複数のサーバーにまたがって同じクラスターのサーバーの処理状況やプロセス状況を確認することが出来ます（下に例画像を張り付けています）。後で初期設定をする、インデックスサーバーの設定のログや、様々な設定をWebUIから変更できます。
![image](https://user-images.githubusercontent.com/15893314/193424568-f43cead3-bdb2-44ff-bb1c-85151d7a7c2e.png)

次に、インデックスサーバーのインストールを行います。

## 7. インデックスサーバーを設定する
次のコマンドを、サーバー上で実施してください。
```
cp graph-node-config/config.tmpl /graph-node-config/config.toml
```
これを実施した後に、[こちら](#複数のRPC APIを使って接続したい) を見ていただき、config.tomlを修正してください。

その後、次のコマンドをサーバー上で実施して、インデクサーサービスを起動させます。
```
chmod +x update-indexer.sh
bash update-indexer.sh
```
このスクリプトが完了すると、6で確認したportainerで、インデックスサービスの状態を見ることが出来るはずです。
![image](https://user-images.githubusercontent.com/15893314/193424539-076714c2-8dfb-4078-9cc7-2d6d60f4aa78.png)

## 8. 使い方に慣れる
今回、以下のdocker stackを生成・運用しています。
- Authelia(SSOの認証サービサー. Portainer/Traefik/Prometheus/Grafanaに対して、SSOを通して認証を行います。indexerのみ、対象から除外です)
- Portainer(docker swarmのWebUI. このスクリプトでは、configをdocker swarmの機能を使用してアップロードしているので、原理的には、docker swarmにサーバーを入れた後は、全てPortainer上から設定が出来るようになります。)
- Traefik(URLのハンドリングをしてくれています。SSL証明書等の発行もまとめてやってくれます。)
- Prometheus(index-node, query-nodeや、node-exporterから情報を受け取り、蓄積しています)
- Grafana(prometheusから受け取った情報や、postgreSQLから取り出したデータを可視化します)
- postgreSQL
- Indexer(クエリの提供、インデックスを実行します)

実際にいろんな画面（特にPortainerとGrafana）を見てみてください。

## 9. GRTを割り当てる
今の設定では、portainer上で、indexer-cliのbashを実行することで、ブラウザ上からインデクサーのインデックス処理、クエリ処理等の設定が出来るようになっています。
indexer-cli上で、次のコマンドで、次のことが出来ます。説明は面倒（というか自分も完全には理解できていない）なので [ドキュメント](https://thegraph.com/docs/en/network/indexing/#indexer-management-using-indexer-cli) を見てください。
- graph indexer status                     indexerのステータスチェック
- graph indexer rules stop (never)         Never index a deployment (and stop indexing it if necessary)
- graph indexer rules start (always)       Always index a deployment (and start indexing it if necessary)
- graph indexer rules set                  Set one or more indexing rules
- graph indexer rules prepare (offchain)   Offchain index a deployment (and start indexing it if necessary)
- graph indexer rules maybe                Index a deployment based on rules
- graph indexer rules get                  Get one or more indexing rules
- graph indexer rules delete               Remove one or many indexing rules
- graph indexer rules clear (reset)        Clear one or more indexing rules
- graph indexer cost set variables         Update cost model variables
- graph indexer cost set model             Update a cost model
- graph indexer cost get                   Get cost models and/or variables for one or all subgraphs
- graph indexer connect                    Connect to indexer management API
- graph indexer allocations reallocate     Reallocate to subgraph deployment
- graph indexer allocations get            List one or more allocations
- graph indexer allocations create         Create an allocation
- graph indexer allocations close          Close an allocation
- graph indexer allocations                Manage indexer allocations
- graph indexer actions queue              Queue an action item
- graph indexer actions get                List one or more actions
- graph indexer actions execute            Execute approved items in the action queue
- graph indexer actions delete             Delete an item in the queue
- graph indexer actions cancel             Cancel an item in the queue
- graph indexer actions approve            Approve an action item

## 10. もっとカスタムしたい人
もっとカスタムしたい人向けに、簡単なメモを入れておきます。

### 複数のRPC APIを使って接続したい
swarmpit -> configs の中に、`config-gnosis-日付`というファイルが見つかるはずです。このファイルの中には、下のような情報が記載されています。このconfigファイルを直接サービスに読み込ませることで、ファイルを直接サーバーに受け渡しせず、設定が可能になっています。
```
[store]
[store.primary]
connection = "postgresql://DBのユーザー名:DBのパスワード@postgres:5432/DB名"
pool_size = 10
[chains]
ingestor = "index_node_gnosis"
# Ethereum Mainnetの設定
[chains.mainnet]
shard = "primary"
provider = [
             { label = "mainnet", url = "CHAINSTACKのURL", features = ["archive", "traces"] }
           ]
# Gnosis Mainnetの設定
[chains.gnosis]
shard = "primary"
provider = [
             { label = "gnosis", url = "CHAINSTACKのURL", features = ["archive", "traces"] }
           ]
[deployment]
[[deployment.rule]]
indexers = [ "index_node_gnosis" ]
[general]
query = "query_node_gnosis"
```

ここで、[chains.gnosis]内にあるproviderを次のように書き換えると、RPC APIを追加できます。
ただし、featuresは次のように選びましょう。
| features | ノード種類 |
| --- | --- |
| [] | フルノード |
| archive | アーカイブノード |
| traces | トレースが有効なノード（アーカイブノード） |

```
provider = [
             { label = "gnosis", url = "フルノードのURL", features = [] },
             { label = "gnosis", url = "ANKRのURL", features = ["archive"] },
             { label = "gnosis", url = "CHAINSTACKのURL", features = ["archive", "traces"] }
           ]
```
以上、様々な設定をしてみてください。
