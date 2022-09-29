#!bin/sh
### TODO check initalize phase is finished
echo "start add worker process"
read -p "Enter new chain name: " CHAIN_1_NAME
#echo "CHAIN_1_NAME=${CHAIN_1_NAME}" >> .env
echo "Entered chain name is: ${CHAIN_1_NAME}"

read -p "Enter new chain RPC URL: " CHAIN_1_RPC
#echo "CHAIN_1_RPC=${CHAIN_1_RPC}" >> .env
echo "Entered chain RPC URL is: ${CHAIN_1_RPC}"

echo "generate docker swarm configuration files(deployment/indexer-${CHAIN_1_NAME}.yml)"
(echo -e "version: '3.8'"; CHAIN_0_NAME=$CHAIN_1_NAME; CHAIN_0_RPC=$CHAIN_1_RPC; docker compose -f graph.yml --env-file .env config) > deployment/indexer-${CHAIN_1_NAME}.yml
sed -i -e '2d' deployment/indexer-${CHAIN_1_NAME}.yml

echo "deploy configuration files"
source .env; CHAIN_0_NAME=$CHAIN_1_NAME; CHAIN_0_RPC=$CHAIN_1_RPC; set -o allexport; set +o allexport; envsubst < graphnode-config/config.tmpl > graphnode-config/config-${CHAIN_1_NAME}.toml
docker config create --label chain=${CHAIN_1_NAME} --label rev=$(date +"%Y%m%d") config-${CHAIN_1_NAME}.toml graphnode-config/config-${CHAIN_1_NAME}.toml

echo "deploy stack indexer-${CHAIN_1_NAME}"
docker stack deploy -c deployment/indexer-${CHAIN_1_NAME}.yml indexer-${CHAIN_1_NAME}

echo "indexer-${CHAIN_1_NAME} stack was deployed"
