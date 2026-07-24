#!/usr/bin/env bash
phase_20_network(){
  log "20 – Laufzeitprojekt, Konfiguration und Netzwerke vorbereiten"
  install -d -m 0750 "$PROJECT_DIR"
  rsync -a --delete \
    --exclude='.env' \
    --exclude='certs/origin.crt' \
    --exclude='certs/origin.key' \
    --exclude='lib/' \
    "$SOURCE_DIR/" "$PROJECT_DIR/"

  if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    prompt_default NEXTCLOUD_DOMAIN "Nextcloud-Domain" "cloud.example.com"
    prompt_default ONLYOFFICE_DOMAIN "ONLYOFFICE-Domain" "office.example.com"
    prompt_default PORTAINER_BIND_IP "Portainer-Bind-IP" "127.0.0.1"
    prompt_default NEXTCLOUD_ADMIN_USER "Nextcloud-Administrator" "admin"
    prompt_secret NEXTCLOUD_ADMIN_PASSWORD "Nextcloud-Administratorpasswort"
    POSTGRES_PASSWORD=$(random_secret)
    REDIS_PASSWORD=$(random_secret)
    ONLYOFFICE_JWT_SECRET=$(random_secret)
    cat > "$PROJECT_DIR/.env" <<ENV
TZ=Europe/Berlin
NEXTCLOUD_DOMAIN=$NEXTCLOUD_DOMAIN
ONLYOFFICE_DOMAIN=$ONLYOFFICE_DOMAIN
PORTAINER_BIND_IP=$PORTAINER_BIND_IP
PORTAINER_PORT=9443
NEXTCLOUD_ADMIN_USER=$NEXTCLOUD_ADMIN_USER
NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
ONLYOFFICE_JWT_SECRET=$ONLYOFFICE_JWT_SECRET
TRUSTED_PROXIES=172.16.0.0/12
OVERWRITE_PROTOCOL=https
UPLOAD_LIMIT=10G
PHP_MEMORY_LIMIT=1024M
ENV
    cat "$PROJECT_DIR/versions.env" >> "$PROJECT_DIR/.env"
    chmod 0600 "$PROJECT_DIR/.env"
  fi

  load_env
  install -d -m 0750 \
    /ssd_data/nextcloud-enterprise/{postgres,redis,nextcloud,portainer,onlyoffice/data,onlyoffice/lib} \
    /hdd_data/{nextcloud-data,onlyoffice-logs,nextcloud-backups} \
    "$PROJECT_DIR/certs"

  sed -e "s/__NEXTCLOUD_DOMAIN__/$NEXTCLOUD_DOMAIN/g" -e "s/__UPLOAD_LIMIT__/$UPLOAD_LIMIT/g" \
    "$PROJECT_DIR/nginx/conf.d/nextcloud.conf.template" > "$PROJECT_DIR/nginx/conf.d/nextcloud.conf"
  sed -e "s/__NEXTCLOUD_DOMAIN__/$NEXTCLOUD_DOMAIN/g" -e "s/__ONLYOFFICE_DOMAIN__/$ONLYOFFICE_DOMAIN/g" -e "s/__UPLOAD_LIMIT__/$UPLOAD_LIMIT/g" \
    "$PROJECT_DIR/nginx/conf.d/onlyoffice.conf.template" > "$PROJECT_DIR/nginx/conf.d/onlyoffice.conf"

  if [[ ! -s "$PROJECT_DIR/certs/origin.crt" || ! -s "$PROJECT_DIR/certs/origin.key" ]]; then
    openssl req -x509 -nodes -newkey rsa:3072 -days 825 \
      -keyout "$PROJECT_DIR/certs/origin.key" -out "$PROJECT_DIR/certs/origin.crt" \
      -subj "/CN=$NEXTCLOUD_DOMAIN" \
      -addext "subjectAltName=DNS:$NEXTCLOUD_DOMAIN,DNS:$ONLYOFFICE_DOMAIN"
    chmod 0600 "$PROJECT_DIR/certs/origin.key"
  fi

  compose config -q
  compose pull
  compose up -d postgres redis
}
