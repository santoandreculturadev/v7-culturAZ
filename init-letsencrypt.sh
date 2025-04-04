#!/bin/bash

set -e

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(culturaz.santoandre.sp.gov.br)
domain="mapasculturais"
email="culturaz@santoandre.sp.gov.br"
staging=0
data_path="./docker-data/certbot"
rsa_key_size=4096

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domain. Continue and replace existing certificate? (y/N) " decision
  if [[ "$decision" != "Y" && "$decision" != "y" ]]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf -o "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem -o "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domain ..."
path="/etc/letsencrypt/live/$domain"
mkdir -p "$data_path/conf/live/$domain"
docker-compose -f docker-compose.certbot.yml run --rm \
  --entrypoint "sh -c 'openssl req -x509 -nodes -newkey rsa:1024 -days 1 \
    -keyout \"$path/privkey.pem\" \
    -out \"$path/fullchain.pem\" \
    -subj \"/CN=localhost\"'" certbot
echo

echo "### Starting nginx ..."
docker-compose -f docker-compose.certbot.yml up --force-recreate -d --remove-orphans nginx
echo

echo "### Deleting dummy certificate for $domain ..."
docker-compose -f docker-compose.certbot.yml run --rm \
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
if [ $staging != "0" ]; then
  staging_arg="--staging"
fi

docker-compose -f docker-compose.certbot.yml run --rm \
  --entrypoint "sh -c 'certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal'" certbot
echo

echo "### Parando serviços"
docker-compose -f docker-compose.certbot.yml down

rm -rf docker-data/certs
mv docker-data/certbot docker-data/certs
mv docker-data/certs/conf/live/"${domains[0]}" docker-data/certs/conf/live/$domain

echo "### Certificado gerado e organizado com sucesso!"
