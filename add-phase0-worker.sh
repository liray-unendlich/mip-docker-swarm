#!bin/bash
### TODO check initalize phase is finished
echo "start add worker process"
read -p "Enter new chain name: " CHAIN_NAME
echo "Entered chain name is: ${CHAIN_NAME}"

read -p "Enter new chain RPC URL: " CHAIN_RPC
echo "Entered chain RPC URL is: ${CHAIN_RPC}"

echo "deploy configuration files"
set -o allexport; source .env; CHAIN_0_NAME=$CHAIN_NAME; CHAIN_0_RPC=$CHAIN_RPC; set +o allexport; envsubst < graphnode-config/config.tmpl > graphnode-config/config-${CHAIN_NAME}.toml
docker config create --label chain=${CHAIN_NAME} --label rev=$(date +"%Y%m%d") config-${CHAIN_NAME}.toml graphnode-config/config-${CHAIN_NAME}.toml

echo "generate docker swarm configuration files(deployment/indexer-${CHAIN_NAME}.yml)"
set -o allexport; source .env; CHAIN_0_NAME=$CHAIN_NAME; CHAIN_0_RPC=$CHAIN_RPC; set +o allexport; envsubst < graph-node.tmpl.yml > deployment/indexer-${CHAIN_NAME}.yml
#(echo -e "version: '3.8'"; CHAIN_0_NAME=$CHAIN_NAME; CHAIN_0_RPC=$CHAIN_RPC; docker compose -f graph-node.tmpl.yml --env-file .env config) > deployment/indexer-${CHAIN_NAME}.yml
#sed -i -e '2d' deployment/indexer-${CHAIN_NAME}.yml

echo "deploy stack indexer-${CHAIN_NAME}"
docker stack deploy -c deployment/indexer-${CHAIN_NAME}.yml indexer-${CHAIN_NAME}

echo "indexer-${CHAIN_NAME} stack was deployed"
