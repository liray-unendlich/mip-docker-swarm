#!bin/bash

echo "pull latest code"
/usr/bin/git pull

echo "read .env"
source .env

echo "Did you completed to edit/update and rename your graph-node configuration file under graph-node-config/config.tmpl to graph-node-config/config.toml? Y/N:"

if [ -z "$INDEXER_RPC" ]; then
  echo -n "Enter mainnet RPC API(Full Node) URL:"
  read INDEXER_RPC
  sed -i -e "$ a INDEXER_RPC=${INDEXER_RPC}" .env
fi

if [ -z "$INDEXER_ADDRESS" ]; then
  echo -n "Enter indexer address on mainnet:"
  read INDEXER_ADDRESS
  sed -i -e "$ a INDEXER_ADDRESS=${INDEXER_ADDRESS}" .env
fi

if [ -z "$INDEXER_MNEMONIC" ]; then
  echo -n "Enter indexer mnemonic on mainnet:"
  read INDEXER_MNEMONIC
  sed -i -e "$ a INDEXER_MNEMONIC=\"${INDEXER_MNEMONIC}\"" .env
fi

if [ -z "$INDEXER_GEO" ]; then
  echo -n "Enter your server location in LONGITUDE LATITUDE: like xx.xx yy.yy:"
  read INDEXER_GEO
  sed -i -e "$ a INDEXER_GEO=\"${INDEXER_GEO}\"" .env
fi

echo "Deploying configuration files"
docker config create config-$(date +"%Y%m%d") graph-node-config/config.toml
CHAIN_CONF_NAME=config-$(date +"%Y%m%d")

echo "Generating docker swarm configuration files(deployment/indexer.yml)"
set -o allexport; source .env; CHAIN_CONF_NAME=${CHAIN_CONF_NAME}; set +o allexport; envsubst < ./template/graph-node.tmpl.yml > deployment/graph-node.yml
cp ./template/default.tmpl.agora deployment/default.agora

echo "Deploying/updating graph-node stack"
docker stack deploy -c deployment/graph-node.yml graph-node

# Wait 15 seconds to complete deploying and generate new database with postgres
sleep 15s
docker exec -e PGPASSWORD=${DB_PASSWORD} -it $(docker ps | grep postgres: | grep graph-node | cut -c 1-12) psql -U ${DB_USER} -d ${DB_NAME} -c "CREATE DATABASE indexer;"

echo "Deploying/updating indexer stack"
set -o allexport; source .env; set +o allexport; envsubst < ./template/indexer.tmpl.yml > deployment/indexer.yml
docker stack deploy -c deployment/indexer.yml indexer

# Wait 15 seconds and try to connect indexer-agent
sleep 15s
docker exec -it $(docker ps | grep indexer-cli | cut -c 1-12) graph indexer connect http://indexer-agent:8000
echo "indexer-service stack was deployed"
