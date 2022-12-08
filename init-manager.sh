#!bin/bash
echo "Starting initialization script of your indexer. Our setup procedure includes SSO authentication system."
echo -n "Please enter your sudo password:"
read PERMISSION_PASSWORD

echo "Setting up directories under data/: for prometheus/grafana/postgres/authelia"
mkdir -p data/postgres data/authelia/postgres data/authelia/config data/authelia/redis
mkdir -p deployment
mkdir -p data/prometheus data/grafana

echo "Configuring ports"
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 2377
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 4789
echo "$PERMISSION_PASSWORD" | sudo -S ufw allow 7946
echo "$PERMISSION_PASSWORD" | sudo -S ufw reload

echo "Initializing docker swarm"
docker swarm init

echo "Creating overlay network: traefik/monitor"
docker network create --driver=overlay traefik-public
docker network create --driver=overlay monitor

echo "Generating docker swarm configuration files(deployment/*.yml)"
NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')
docker node update --label-add traefik-public.traefik-public-certificates=true $NODE_ID
source .env

docker config create prometheus-$(date +"%Y%m%d") prometheus/prometheus.yml
PROMETHEUS_CONF_NAME=prometheus-$(date +"%Y%m%d")

set -o allexport; source .env; set +o allexport; envsubst < ./template/authelia.tmpl.yml > deployment/authelia.yml
set -o allexport; source .env; PROMETHEUS_CONF_NAME=${PROMETHEUS_CONF_NAME}; set +o allexport; envsubst < ./template/monitor.tmpl.yml > deployment/monitor.yml
set -o allexport; source .env; set +o allexport; envsubst < ./template/portainer.tmpl.yml > deployment/portainer.yml
set -o allexport; source .env; set +o allexport; envsubst < ./template/traefik.tmpl.yml > deployment/traefik.yml

echo "Generating authelia secret files and deploying on docker swarm network"
# Set up temporaly folder 'secrets' in deployment/
mkdir deployment/secrets
# Generate JWT_SECRET
openssl rand -hex 32 > deployment/secrets/jwt_secret
docker secret create jwt_secret deployment/secrets/jwt_secret
# Generate SESSION_SECRET
openssl rand -hex 32 > deployment/secrets/session_secret
docker secret create session_secret deployment/secrets/session_secret
# Generate STORAGE_POSTGRES_PASSWORD
openssl rand -hex 32 > deployment/secrets/storage_postgres_password
docker secret create storage_postgres_password deployment/secrets/storage_postgres_password
# Generate STORAGE_ENCRYPTION_KEY
openssl rand -hex 32 > deployment/secrets/storage_encryption_key
docker secret create storage_encryption_key deployment/secrets/storage_encryption_key
# Generate OIDC_HMAC_SECRET
openssl rand -hex 32 > deployment/secrets/oidc_hmac_secret
docker secret create oidc_hmac_secret deployment/secrets/oidc_hmac_secret
# Generate OIDC_ISSUER_PRIVATE_KEY
openssl genrsa -out deployment/secrets/oidc_issuer_private_key 4096
docker secret create oidc_issuer_private_key deployment/secrets/oidc_issuer_private_key
# Generate portainer client secret
PORTAINER_CLIENT_SECRET=$(openssl rand -hex 32)

# Delete secrets/*
rm -r deployment/secrets

# Generate configuration.yml
set -o allexport; source .env; PORTAINER_CLIENT_SECRET="\"\$plaintext\$"${PORTAINER_CLIENT_SECRET}\"; set +o allexport; envsubst < ./authelia/configuration.tmpl.yml > data/authelia/config/configuration.yml

# Generate password hash and set up users_database.yml
TEMP_HASHED_PASSWORD=$(docker run authelia/authelia:latest authelia crypto hash generate argon2 --password ${AUTHELIA_PASSWORD})
AUTHELIA_HASHED_PASSWORD=${TEMP_HASHED_PASSWORD#Digest: }
set -o allexport; source .env; AUTHELIA_HASHED_PASSWORD=${AUTHELIA_HASHED_PASSWORD}; set +o allexport; envsubst < ./authelia/users_database.tmpl.yml > data/authelia/config/users_database.yml

echo "deploy traefik/authelia/portainer"
docker stack deploy -c deployment/traefik.yml traefik
docker stack deploy -c deployment/authelia.yml authelia
docker stack deploy -c deployment/portainer.yml portainer

echo "deploy monitor stack"
set -o allexport; source .env; set +o allexport; envsubst < ./template/monitor.tmpl.yml > deployment/monitor.yml
docker stack deploy -c deployment/monitor.yml monitor

# Generate and show portainer's oauth client secret
echo -n "Please copy below secret string for editing your oauth configuration in portainer:"
echo ${PORTAINER_CLIENT_SECRET:12:64}

echo "If you forget portainer's client secret, use this command: cat data/authelia/config/configuration.yml and check bottom section"

echo "Finished initializing manager node(indexer-manager)"
