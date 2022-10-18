#!bin/bash

echo "pull latest code"
/usr/bin/git pull

echo "read .env"
source .env

echo "You might need to enter several parameters for indexer-agent/service setup"

if [ -z "$INDEXER_RPC" ]; then
  echo -n "Enter goerli RPC API(Full Node) URL:"
  read INDEXER_RPC
  sed -i -e "$ a INDEXER_RPC=${INDEXER_RPC}" .env
fi

if [ -z "$INDEXER_ADDRESS" ]; then
  echo -n "Enter indexer address on goerli:"
  read INDEXER_ADDRESS
  sed -i -e "$ a INDEXER_ADDRESS=${INDEXER_ADDRESS}" .env
fi

if [ -z "$INDEXER_MNEMONIC" ]; then
  echo -n "Enter indexer mnemonic on goerli:"
  read INDEXER_MNEMONIC
  sed -i -e "$ a INDEXER_MNEMONIC=\"${INDEXER_MNEMONIC}\"" .env
fi

if [ -z "$INDEXER_GEO" ]; then
  echo -n "Enter your server location in LONGITUDE LATITUDE: like xx.xx yy.yy:"
  read INDEXER_GEO
  sed -i -e "$ a INDEXER_GEO=\"${INDEXER_GEO}\"" .env
fi

if [ -z "$INDEXER_DOMAIN" ]; then
  echo -n "Enter your indexer domain:"
  read INDEXER_DOMAIN
  sed -i -e "$ a INDEXER_DOMAIN=${INDEXER_DOMAIN}" .env
fi

if [ -z "$CONSOLE_DOMAIN" ]; then
  echo -n "Enter your console domain:"
  read CONSOLE_DOMAIN
  sed -i -e "$ a CONSOLE_DOMAIN=${CONSOLE_DOMAIN}" .env
fi

if [ -z "$CONSOLE_USER" ]; then
  echo -n "Enter your console user:"
  read CONSOLE_USER
  sed -i -e "$ a CONSOLE_USER=${CONSOLE_USER}" .env
fi

if [ -z "$CONSOLE_PASSWORD" ]; then
  echo -n "Enter your console password:"
  read CONSOLE_PASSWORD
  sed -i -e "$ a CONSOLE_PASSWORD=${CONSOLE_PASSWORD}" .env
fi

echo "You also might need to enter RPC API URL for goerli(archive)"

if [ -z "$CHAIN_GOERLI_RPC" ]; then
  echo -n "Enter goerli RPC API(Archive Node) URL:"
  read CHAIN_GOERLI_RPC
  sed -i -e "$ a CHAIN_GOERLI_RPC=${CHAIN_GOERLI_RPC}" .env
fi

echo -n "Please enter current/favor indexing chain(enter gnosis):"
read CHAIN_NAME
NEW_RPC="CHAIN_${CHAIN_NAME^^}_RPC"

if [ -z "${!NEW_RPC}" ]; then
  echo -n "Enter new ${CHAIN_NAME} RPC(Archive) URL:"
  eval read $NEW_RPC
  sed -i -e "$ a ${NEW_RPC}=${!NEW_RPC}" .env
  echo "Entered ${CHAIN_NAME} RPC URL is: ${!NEW_RPC}"
fi

CONSOLE_HASHED_PASSWORD=$(openssl passwd -apr1 $CONSOLE_PASSWORD)
CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD//\$/\$\$}

echo "deploy configuration files"
set -o allexport; source .env; CHAIN_NAME=$CHAIN_NAME; CHAIN_RPC=${!NEW_RPC}; set +o allexport; envsubst < graph-node-config/config.tmpl > graph-node-config/config-$(date +"%Y%m%d").toml
docker config create config-$(date +"%Y%m%d") graph-node-config/config-$(date +"%Y%m%d").toml
CHAIN_CONF_NAME=config-$(date +"%Y%m%d")

echo "generate docker swarm configuration files(deployment/indexer-${CHAIN_NAME}.yml)"
set -o allexport; source .env; CHAIN_NAME=$CHAIN_NAME; CHAIN_RPC=${!NEW_RPC}; CHAIN_CONF_NAME=${CHAIN_CONF_NAME}; set +o allexport; envsubst < ./template/graph-node.tmpl.yml > deployment/indexer-${CHAIN_NAME}.yml
set -o allexport; source .env; CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD}; CHAIN_CONF_NAME=${CHAIN_CONF_NAME}; set +o allexport; envsubst < ./template/indexer.tmpl.yml > deployment/indexer.yml

echo "deploy indexer-${CHAIN_NAME}"
docker stack deploy -c deployment/indexer-${CHAIN_NAME}.yml indexer-${CHAIN_NAME}

echo "indexer-${CHAIN_NAME} stack was deployed"
sleep 30s

echo "deploy indexer-agent/service and console"
docker stack deploy -c deployment/indexer.yml indexer

echo "link indexer ui"
docker exec -it $(docker ps | grep indexer-cli | cut -c 1-12) graph indexer connect http://indexer-agent:8000

echo "indexer stack was deployed"

