#!/bin/bash

set -e

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

domains=(culturaz.santoandre.sp.gov.br)
domain="${domains[0]}"
email="culturaz@santoandre.sp.gov.br"
staging=0
data_path="./docker-data/certs"
rsa_key_size=4096

if [ -d "$data_path" ] && [ -n "$(find "$data_path" -mindepth 1 -maxdepth 3 -type f 2>/dev/null)" ]; then
  if [ -t 0 ]; then
    read -p "Existing data found for $domain. Continue and replace existing certificate? (y/N) " decision
    if [[ "$decision" != "Y" && "$decision" != "y" ]]; then
      exit
    fi
  else
    echo "Existing data found for $domain. Replacing certificate in non-interactive mode."
  fi
fi

mkdir -p "$data_path/conf" "$data_path/www"

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -o "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem -o "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domain ..."
path="/etc/letsencrypt/live/$domain"
mkdir -p "$data_path/conf/live/$domain"
"${compose_cmd[@]}" -f docker-compose.certbot.yml run --rm -T \
  --entrypoint "sh -c 'openssl req -x509 -nodes -newkey rsa:1024 -days 1 \
    -keyout \"$path/privkey.pem\" \
    -out \"$path/fullchain.pem\" \
    -subj \"/CN=localhost\"'" certbot
echo

echo "### Starting nginx ..."
"${compose_cmd[@]}" -f docker-compose.certbot.yml up --force-recreate -d --remove-orphans nginx
echo

echo "### Deleting dummy certificate for $domain ..."
"${compose_cmd[@]}" -f docker-compose.certbot.yml run --rm -T \
  --entrypoint "sh -c 'rm -Rf /etc/letsencrypt/live/$domain && \
    rm -Rf /etc/letsencrypt/archive/$domain && \
    rm -Rf /etc/letsencrypt/renewal/$domain.conf'" certbot
echo

echo "### Requesting Let's Encrypt certificate for ${domains[*]} ..."
domain_args=""
for d in "${domains[@]}"; do
  domain_args="$domain_args -d $d"
done

if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
else
  email_arg="--email $email"
fi

staging_arg=""
if [ "$staging" != "0" ]; then
  staging_arg="--staging"
fi

"${compose_cmd[@]}" -f docker-compose.certbot.yml run --rm -T \
  --entrypoint "sh -c 'certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal'" certbot
echo

echo "### Iniciando serviço de renovação"
"${compose_cmd[@]}" -f docker-compose.certbot.yml up -d --remove-orphans certbot
echo "### Certificado gerado com sucesso! O serviço de renovação ficou ativo."
