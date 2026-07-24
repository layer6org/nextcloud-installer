#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root; load_env
log "Compose-Konfiguration und Netzwerke neu anwenden"
compose config -q
compose up -d postgres redis nextcloud onlyoffice portainer
wait_container_health nc-postgres healthy 240
wait_container_health nc-redis healthy 180
wait_container_health onlyoffice healthy 360
if ! json_installed; then
  count=$(compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from pg_tables where schemaname='public';" | tr -d '[:space:]')
  [[ "$count" == 0 ]] || die "Nicht installierte Nextcloud mit nichtleerer Datenbank; automatische Reparatur abgebrochen."
  wait_http_in_container nextcloud http://127.0.0.1/status.php 180
  compose exec -T nextcloud rm -f /var/www/html/config/autoconfig.php
  occ maintenance:install --database=pgsql --database-host=postgres --database-name="$POSTGRES_DB" --database-user="$POSTGRES_USER" --database-pass="$POSTGRES_PASSWORD" --admin-user="$NEXTCLOUD_ADMIN_USER" --admin-pass="$NEXTCLOUD_ADMIN_PASSWORD" --data-dir=/var/www/html/data
fi
compose exec -T nextcloud rm -f /var/www/html/config/autoconfig.php
occ config:system:set trusted_domains 0 --value="$NEXTCLOUD_DOMAIN"
occ config:system:set trusted_domains 1 --value=nextcloud
occ config:system:set overwritehost --value="$NEXTCLOUD_DOMAIN"
occ config:system:set overwriteprotocol --value=https
occ config:system:set overwrite.cli.url --value="https://$NEXTCLOUD_DOMAIN"
occ config:system:set allow_local_remote_servers --type=boolean --value=true
occ app:install onlyoffice || true
occ app:enable onlyoffice
occ config:app:set onlyoffice DocumentServerUrl --value="https://$ONLYOFFICE_DOMAIN/"
occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
occ config:app:set onlyoffice StorageUrl --value="http://nextcloud/"
occ config:app:set onlyoffice jwt_secret --value="$ONLYOFFICE_JWT_SECRET"
occ config:app:set onlyoffice jwt_header --value=AuthorizationJwt
occ config:app:set onlyoffice jwt_in_body --value=true
compose up -d --force-recreate nextcloud onlyoffice
wait_container_health nextcloud healthy 300
wait_container_health onlyoffice healthy 360
compose up -d nginx nextcloud-cron
wait_container_health nc-nginx healthy 180
compose exec -T nextcloud getent hosts onlyoffice
compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true
occ onlyoffice:documentserver --check
"$(dirname "$0")/doctor.sh"
