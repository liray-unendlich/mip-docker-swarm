#!bin/bash
echo -n "Enter password:"
read PERMISSION_PASSWORD

echo "make directories: for traefik/swarmpit/prometheus/grafana/postgres"
mkdir -p data/postgres data/swarmpit/db-data data/swarmpit/influx-data data/traefik
mkdir -p deployment
mkdir -p data/prometheus data/grafana

echo "port configuring"
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 2377
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 4789
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 7946
echo "$PERMISSION_PASSWORD" | sudo -S ufw reload

echo "change hostname to indexer-manager"
echo "$PERMISSION_PASSWORD" | sudo -S hostname indexer-manager

echo "initialize docker swarm"
docker swarm init

echo "create overlay network: traefik/monitor"
docker network create --driver=overlay traefik-public
docker network create --drive=overlay monitor

echo "generate docker swarm configuration files(deployment/*.yml)"
NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')
docker node update --label-add traefik-public.traefik-public-certificates=true $NODE_ID
docker node update --label-add swarmpit.db-data=true $NODE_ID
docker node update --label-add swarmpit.influx-data=true $NODE_ID
source .env
TRAEFIK_HASHED_PASSWORD=$(openssl passwd -apr1 $TRAEFIK_PASSWORD)
PROMETHEUS_HASHED_PASSWORD=$(openssl passwd -apr1 $PROMETHEUS_PASSWORD)
TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD//\$/\$\$}
PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD//\$/\$\$}
sed -i -e "$ a TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD}" .env
sed -i -e "$ a PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD}" .env

(TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD}; echo -e "version: '3.8'"; docker compose -f traefik.yml --env-file .env config) > deployment/traefik.yml
(PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD}; echo -e "version: '3.8'"; docker compose -f swarmpit.yml --env-file .env config) > deployment/swarmpit.yml
sed -i -e '2d' deployment/traefik.yml
sed -i -e '2d' deployment/swarmpit.yml
sed -i -e "$ d" .env
sed -i -e "$ d" .env

echo "deploy traefik/swarmpit"
docker stack deploy -c deployment/traefik.yml traefik
docker stack deploy -c deployment/swarmpit.yml swarmpit

echo "deploy monitor service"
(echo -e "version: '3.8'"; docker compose -f monitor.yml --env-file .env config) > deployment/monitor.yml
sed -i -e '2d' deployment/monitor.yml
docker stack deploy -c deployment/monitor.yml monitor

# show swarm token
echo "Copy below token for initializing new worker."
echo "You can show this token again with: `docker swarm join-token worker`"

docker swarm join-token worker

echo "Finished initializing manager node(indexer-manager)"
