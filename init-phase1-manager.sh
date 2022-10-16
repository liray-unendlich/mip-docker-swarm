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
fi

if [ -z "$INDEXER_ADDRESS" ]; then
  echo -n "Enter indexer address on goerli:"
  read INDEXER_ADDRESS
fi

if [ -z "$INDEXER_MNEMONIC" ]; then
  echo -n "Enter indexer mnemonic on goerli:"
  read INDEXER_MNEMONIC
fi

if [ -z "$INDEXER_GEO" ]; then
  echo -n "Enter your server location in LONGITUDE LATITUDE: like xx.xx yy.yy:"
  read INDEXER_GEO
fi

echo "build indexer-cli image. It might take 10mins."
docker build -t indexer-cli-console:0.1 ./indexer-console/.

CONSOLE_HASHED_PASSWORD=$(openssl passwd -apr1 $CONSOLE_PASSWORD)
CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD//\$/\$\$}

set -o allexport; source .env; CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD}; set +o allexport; envsubst < indexer-console.tmpl.yml > deployment/indexer-console.yml

echo "deploy indexer-console"
docker stack deploy -c deployment/indexer-console.yml indexer-console

