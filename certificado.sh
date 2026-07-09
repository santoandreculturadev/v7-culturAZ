#!/bin/bash
set -e

# Verifica Docker e Compose v2
if ! command -v docker >/dev/null 2>&1; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo 'Error: docker compose (plugin v2) is not available.' >&2
  echo 'Tip: sudo apt-get install -y docker-compose-plugin' >&2
  exit 1
fi

# Domínio da instalação (pode ter mais de um)
domains=(culturaz.santoandre.sp.gov.br)
primary_domain="${domains[0]}"

# Informe um e-mail válido
email="culturaz@santoandre.sp.gov.br"

# Evita limite durante testes (1 = staging; 0 = produção)
staging=0

data_path="./docker-data/certbot"
rsa_key_size=4096

# Pastas/paths internos do container certbot
le_live_path="/etc/letsencrypt/live/mapasculturais"

if [ -d "$data_path" ]; then
  read -p "Existing data found for ${primary_domain}. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit 0
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
    > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
    > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for ${primary_domain} ..."
mkdir -p "$data_path/conf/live/mapasculturais"

# NOTE: --remove-orphans NÃO existe em "docker compose run". Por isso removemos.
docker compose -f docker-compose.certbot.yml run --rm \
  --entrypoint /bin/sh certbot -c \
  "mkdir -p '${le_live_path}' && \
   openssl req -x509 -nodes -newkey rsa:1024 -days 1 \
     -keyout '${le_live_path}/privkey.pem' \
     -out '${le_live_path}/fullchain.pem' \
     -subj '/CN=localhost'"
echo

echo "### Starting nginx ..."
docker compose -f docker-compose.certbot.yml up --force-recreate -d --remove-orphans nginx
echo

echo "### Deleting dummy certificate for ${primary_domain} ..."
docker compose -f docker-compose.certbot.yml run --rm \
  --entrypoint /bin/sh certbot -c \
  "rm -rf /etc/letsencrypt/live/mapasculturais && \
   rm -rf /etc/letsencrypt/archive/mapasculturais && \
   rm -rf /etc/letsencrypt/renewal/mapasculturais.conf"
echo

echo "### Requesting Let's Encrypt certificate for ${primary_domain} ..."
domain_args=""
for d in "${domains[@]}"; do
  domain_args="$domain_args -d $d"
done

case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *)  email_arg="--email $email" ;;
esac

staging_arg=""
if [ "$staging" != "0" ]; then
  staging_arg="--staging"
fi

docker compose -f docker-compose.certbot.yml run --rm \
  --entrypoint /bin/sh certbot -c \
  "certbot certonly --webroot -w /var/www/certbot \
     $staging_arg \
     $email_arg \
     $domain_args \
     --rsa-key-size $rsa_key_size \
     --agree-tos \
     --force-renewal"
echo

echo "### baixando serviços"
docker compose -f docker-compose.certbot.yml down --remove-orphans

# Organiza pastas como seu fluxo original
rm -rf docker-data/certs
mv docker-data/certbot docker-data/certs

# Se existir a pasta do domínio em live/, renomeia para mapasculturais
if [ -d "docker-data/certs/conf/live/${primary_domain}" ]; then
  rm -rf "docker-data/certs/conf/live/mapasculturais"
  mv "docker-data/certs/conf/live/${primary_domain}" "docker-data/certs/conf/live/mapasculturais"
else
  echo "WARNING: expected folder docker-data/certs/conf/live/${primary_domain} not found."
  echo "Check if certbot actually issued the cert (DNS/HTTP-01 reachability)."
fi
