#!bin/bash
echo -n "Enter password:"
read PERMISSION_PASSWORD

echo "make directories: for postgres"
mkdir -p data/postgres

echo "port configuring"
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 2377
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 4789
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 7946
echo "$PERMISSION_PASSWORD" | sudo -S ufw reload

echo -n "Enter which chain you want to sync:"
read CHAIN_NAME

echo "change hostname to indexer-${CHAIN_NAME}"
echo "$PERMISSION_PASSWORD" | sudo -S hostname indexer-${CHAIN_NAME}

echo "restart docker"
echo "$PERMISSION_PASSWORD" | sudo -S service docker restart
sleep 10s

echo -n "enter existing docker swarm token:"
read DOCKER_SWARM_TOKEN
echo -n "Enter existing docker swarm manager IP(ONLY IP):"
read DOCKER_SWARM_MANAGER_IP

DOCKER_SWARM_MANAGER_IP="${DOCKER_SWARM_MANAGER_IP}:2377"

docker swarm join --token $DOCKER_SWARM_TOKEN $DOCKER_SWARM_MANAGER_IP

echo "Initialization completed"

