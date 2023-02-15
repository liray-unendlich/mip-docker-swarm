#!bin/bash

echo "pull latest code"
/usr/bin/git pull

echo "read .env"
source .env

echo "Create new database for indexer-arbitrum"
docker exec -e PGPASSWORD=${DB_PASSWORD} -it $(docker ps | grep postgres: | grep graph-node | cut -c 1-12) psql -U ${DB_USER} -d ${DB_NAME} -c "CREATE DATABASE \"indexer-arb\";"

echo "Deploying/updating indexer stack"
set -o allexport; source .env; set +o allexport; envsubst < ./template/indexer-arbitrum.tmpl.yml > deployment/indexer-arbitrum.yml
docker stack deploy -c deployment/indexer-arbitrum.yml indexer-arbitrum

# Wait 15 seconds and try to connect indexer-agent
sleep 15s
docker exec -it $(docker ps | grep indexer-arbitrum_indexer-cli | cut -c 1-12) graph indexer connect http://indexer-agent:8000
echo "indexer-arbitrum stack was deployed"
