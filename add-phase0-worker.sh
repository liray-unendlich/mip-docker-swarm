#!bin/bash
### TODO check initalize phase is finished
echo "start add worker process"
read -p "Enter new chain name: " CHAIN_NAME
echo "Entered chain name is: ${CHAIN_NAME}"

source .env

if [ -z "CHAIN_${!CHAIN_NAME}_RPC" ]; then
  echo -n "Enter new chain RPC(Archive) URL:"
  read CHAIN_${!CHAIN_NAME}_RPC
  sed -i -e "$ a CHAIN_${!CHAIN_NAME}_RPC=${CHAIN_${!CHAIN_NAME}_RPC}" .env
  echo "Entered `CHAIN_${!CHAIN_NAME}_RPC` is: `${CHAIN_${!CHAIN_NAME}_RPC}`"
fi

echo "deploy configuration files"
set -o allexport; source .env; CHAIN_NAME=$CHAIN_NAME; CHAIN_RPC=${CHAIN_${!CHAIN_NAME}_RPC}; set +o allexport; envsubst < graphnode-config/config.tmpl > graph-node-config/config-$(date +"%Y%m%d").toml
docker config create config-${CHAIN_NAME}-$(date +"%Y%m%d") graph-node-config/config-$(date +"%Y%m%d").toml
CHAIN_CONF_NAME=config-$(date +"%Y%m%d")

echo "generate docker swarm configuration files(deployment/indexer-${CHAIN_NAME}.yml)"
set -o allexport; source .env; CHAIN_NAME=$CHAIN_NAME; CHAIN_RPC=$CHAIN_RPC; CHAIN_CONF_NAME=${CHAIN_CONF_NAME}; set +o allexport; envsubst < ./template/graph-node.tmpl.yml > deployment/indexer-${CHAIN_NAME}.yml
#(echo -e "version: '3.8'"; CHAIN_0_NAME=$CHAIN_NAME; CHAIN_0_RPC=$CHAIN_RPC; docker compose -f graph-node.tmpl.yml --env-file .env config) > deployment/indexer-${CHAIN_NAME}.yml
#sed -i -e '2d' deployment/indexer-${CHAIN_NAME}.yml

echo "deploy stack indexer-${CHAIN_NAME}"
docker stack deploy -c deployment/indexer-${CHAIN_NAME}.yml indexer-${CHAIN_NAME}

echo "indexer-${CHAIN_NAME} stack was deployed"
