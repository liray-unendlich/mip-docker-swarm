#!bin/bash

mkdir -p data/postgres

echo "pull latest code"
/usr/bin/git pull

echo "Enter several parameters for indexer-agent/service setup"
echo -n "Enter goerli RPC API URL:"
read INDEXER_RPC

echo -n "Enter indexer address on goerli:"
read INDEXER_ADDRESS

echo -n "Enter indexer mnemonic on goerli:"
read INDEXER_MNEMONIC

echo -n "Enter your server location in LONGITUDE LATITUDE: like xx.xx yy.yy"
read INDEXER_GEO

echo "build indexer-cli image. It might take 10mins."
docker build -t indexer-cli-console:0.1 ./indexer-console/.

source .env
CONSOLE_HASHED_PASSWORD=$(openssl passwd -apr1 $CONSOLE_PASSWORD)
CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD//\$/\$\$}

set -o allexport; source .env; CONSOLE_HASHED_PASSWORD=${CONSOLE_HASHED_PASSWORD}; set +o allexport; envsubst < indexer-console.tmpl.yml > deployment/indexer-console.yml

echo "deploy indexer-console"
docker stack deploy -c deployment/indexer-console.yml indexer-console

