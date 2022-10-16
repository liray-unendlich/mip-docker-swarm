#!bin/bash

mkdir -p data/postgres

echo "pull latest code"
/usr/bin/git pull

echo "read .env"
source .env

echo "You might need to enter several parameters for indexer-agent/service setup"

if [ -z "$INDEXER_RPC" ]; then
  echo -n "Enter goerli RPC API URL:"
  read INDEXER_RPC
  sed -e "$ a INDEXER_RPC=${INDEXER_RPC}" .env
fi

if [ -z "$INDEXER_ADDRESS" ]; then
  echo -n "Enter indexer address on goerli:"
  read INDEXER_ADDRESS
  sed -e "$ a INDEXER_RPC=${INDEXER_RPC}" .env
fi

if [ -z "$INDEXER_MNEMONIC" ]; then
  echo -n "Enter indexer mnemonic on goerli:"
  read INDEXER_MNEMONIC
  sed -e "$ a INDEXER_MNEMONIC=${INDEXER_MNEMONIC}" .env
fi

if [ -z "$INDEXER_GEO" ]; then
  echo -n "Enter your server location in LONGITUDE LATITUDE: like xx.xx yy.yy:"
  read INDEXER_GEO
  sed -e "$ a INDEXER_GEO=${INDEXER_GEO}" .env
fi

if [ -z "$INDEXER_DOMAIN" ]; then
  echo -n "Enter your indexer domain:"
  read INDEXER_DOMAIN
  sed -e "$ a INDEXER_DOMAIN=${INDEXER_DOMAIN}" .env
fi

if [ -z "$CONSOLE_DOMAIN" ]; then
  echo -n "Enter your console domain:"
  read CONSOLE_DOMAIN
  sed -e "$ a CONSOLE_DOMAIN=${CONSOLE_DOMAIN}" .env
fi

if [ -z "$CONSOLE_PASSWORD" ]; then
  echo -n "Enter your console password:"
  read CONSOLE_PASSWORD
  sed -e "$ a CONSOLE_DOMAIN=${CONSOLE_PASSWORD}" .env
fi

echo "build indexer-cli image. It might take 10mins."
docker build -t indexer-cli-console:0.1 ./indexer-console/.

CONSOLE_HASHED_PASSWORD=$(openssl passwd -apr1 $CONSOLE_PASSWORD)
CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD//\$/\$\$}

set -o allexport; source .env; CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD}; set +o allexport; envsubst < indexer-console.tmpl.yml > deployment/indexer-console.yml

set -o allexport; source .env; set +o allexport; envsubst < indexer.tmpl.yml > deployment/indexer.yml

echo "deploy indexer and console"
docker stack deploy -c deployment/indexer.yml indexer
docker stack deploy -c deployment/indexer-console.yml indexer-console

