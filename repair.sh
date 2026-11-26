#!/usr/bin/env bash
# Wendet Compose-, NGINX-, Nextcloud- und ONLYOFFICE-Konfiguration erneut an.
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
acquire_lock
load_env

log "Laufzeitdateien und NGINX-Konfiguration erneuern"
saved_versions=$(mktemp); cp "$PROJECT_DIR/versions.env" "$saved_versions"
sync_runtime_files
cp "$saved_versions" "$PROJECT_DIR/versions.env"; rm -f "$saved_versions"
render_nginx_configs
compose config -q

log "Datenbank und Cache starten"
compose up -d postgres redis
wait_container_health nc-postgres healthy 240
wait_container_health nc-redis healthy 180

compose up -d nextcloud portainer
wait_http_in_container nextcloud http://127.0.0.1/status.php 600
if ! nc_installed_on_disk; then
  count=$(db_table_count)
  [[ "$count" == 0 ]] || die "Nicht installierte Nextcloud mit nichtleerer Datenbank; automatische Reparatur abgebrochen (restore.sh verwenden)."
  nc_maintenance_install
fi
occ maintenance:mode --off >/dev/null 2>&1 || true
compose exec -T nextcloud rm -f /var/www/html/config/autoconfig.php
configure_nextcloud

compose up -d onlyoffice
wait_container_health onlyoffice healthy 360
configure_onlyoffice

compose up -d --force-recreate nextcloud onlyoffice
wait_container_health nextcloud healthy 300
wait_container_health onlyoffice healthy 360
compose up -d --force-recreate nginx
compose up -d nextcloud-cron
wait_container_health nc-nginx healthy 180
compose exec -T nextcloud getent hosts onlyoffice >/dev/null
compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true
occ onlyoffice:documentserver --check
"$(dirname "$0")/doctor.sh"
