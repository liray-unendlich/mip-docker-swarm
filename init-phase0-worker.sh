#!bin/bash
echo -n "Enter password:"
read PERMISSION_PASSWORD

echo "make directories: for postgres"
mkdir -p data/postgres deployment

echo "port configuring"
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 2377
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 4789
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 7946
echo "$PERMISSION_PASSWORD" | sudo -S ufw reload

source .env

echo "change hostname to indexer-${CHAIN_1_NAME}"
echo "$PERMISSION_PASSWORD" | sudo -S hostname indexer-${CHAIN_1_NAME}

echo "restart docker"
echo "$PERMISSION_PASSWORD" | sudo -S service docker restart
sleep 10s

echo -n "enter existing docker swarm token:"
read DOCKER_SWARM_TOKEN
echo -n "Enter existing docker swarm manager IP:"
read DOCKER_SWARM_MANAGER_IP

docker swarm join --token $DOCKER_SWARM_TOKEN $DOCKER_SWARM_MANAGER_IP

echo "Initialization completed"

echo "deploy ${CHAIN_1_NAME} indexer"
set -o allexport; source .env; set +o allexport; envsubst < graphnode-config/config.tmpl > graphnode-config/config-${CHAIN_1_NAME}.toml
(echo -e "version: '3.8'"; docker compose -f graph.yml --env-file .env config) > deployment/indexer-${CHAIN_1_NAME}.yml

sed -i -e '2d' deployment/indexer-${CHAIN_1_NAME}.yml
docker stack deploy -c deployment/indexer-${CHAIN_1_NAME}.yml indexer-${CHAIN_1_NAME}

echo "Finished deployment"
