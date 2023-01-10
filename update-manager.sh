#!bin/bash

echo "pull latest code"
/usr/bin/git pull

echo "make directories: for traefik/swarmpit/prometheus/grafana/postgres"
mkdir -p data/postgres data/swarmpit/db-data data/swarmpit/influx-data data/traefik
mkdir -p deployment
mkdir -p data/prometheus data/grafana

# remove current monitor stack
docker stack rm monitor

source .env
TRAEFIK_HASHED_PASSWORD=$(openssl passwd -apr1 $TRAEFIK_PASSWORD)
PROMETHEUS_HASHED_PASSWORD=$(openssl passwd -apr1 $PROMETHEUS_PASSWORD)
TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD//\$/\$\$}
PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD//\$/\$\$}

docker config create prometheus-$(date +"%Y%m%d") prometheus/prometheus.yml
PROMETHEUS_CONF_NAME=prometheus-$(date +"%Y%m%d")

set -o allexport; source .env; TRAEFIK_HASHED_PASSWORD=${TRAEFIK_HASHED_PASSWORD}; set +o allexport; envsubst < ./template/traefik.tmpl.yml > deployment/traefik.yml
set -o allexport; source .env; set +o allexport; envsubst < ./template/swarmpit.tmpl.yml > deployment/swarmpit.yml
set -o allexport; source .env; set +o allexport; envsubst < ./template/portainer.tmpl.yml > deployment/portainer.yml

echo "deploy traefik/swarmpit/portainer"
docker stack deploy -c deployment/traefik.yml traefik
docker stack deploy -c deployment/swarmpit.yml swarmpit
docker stack deploy -c deployment/portainer.yml portainer

echo "deploy monitor service"
set -o allexport; source .env; PROMETHEUS_HASHED_PASSWORD=${PROMETHEUS_HASHED_PASSWORD}; PROMETHEUS_CONF_NAME=${PROMETHEUS_CONF_NAME}; set +o allexport; envsubst < ./template/monitor.tmpl.yml > deployment/monitor.yml
docker stack deploy -c deployment/monitor.yml monitor

echo "Finished updating manager stacks"
