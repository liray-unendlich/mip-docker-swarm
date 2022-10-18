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
docker network create --driver=overlay monitor

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

docker config create prometheus-$(date +"%Y%m%d") prometheus/prometheus.yml
PROMETHEUS_CONF_NAME=prometheus-$(date +"%Y%m%d")

set -o allexport; source .env; TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD}; set +o allexport; envsubst < ./template/traefik.tmpl.yml > deployment/traefik.yml
set -o allexport; source .env; ; set +o allexport; envsubst < ./template/swarmpit.tmpl.yml > deployment/swarmpit.yml

echo "deploy traefik/swarmpit"
docker stack deploy -c deployment/traefik.yml traefik
docker stack deploy -c deployment/swarmpit.yml swarmpit

echo "deploy monitor service"
set -o allexport; source .env; PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD}; PROMETHEUS_CONF_NAME=${PROMETHEUS_CONF_NAME}; set +o allexport; envsubst < ./template/monitor.tmpl.yml > deployment/monitor.yml
docker stack deploy -c deployment/monitor.yml monitor

# show swarm token
echo "Copy below token for initializing new worker."
echo "You can show this token again with: docker swarm join-token worker"

docker swarm join-token worker

echo "Finished initializing manager node(indexer-manager)"
