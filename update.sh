#!/usr/bin/env bash
# Aktualisiert den Stack auf die Image-Versionen aus $PROJECT_DIR/versions.env.
# Für ein neues Installer-Release stattdessen dessen install.sh ausführen
# (sichert automatisch und übernimmt neue versions.env sowie Konfiguration).
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
acquire_lock
load_env
check_nextcloud_upgrade_path

log "Sicherung vor dem Update"
"$(dirname "$0")/backup.sh"

log "Images laden"
compose config -q
compose pull

log "Container neu erstellen"
compose up -d --remove-orphans postgres redis
wait_container_health nc-postgres healthy 240
wait_container_health nc-redis healthy 180
# Das Nextcloud-Image führt das Upgrade beim Start aus; danach ist es healthy.
compose up -d nextcloud
wait_container_health nextcloud healthy 900
compose up -d --remove-orphans

log "Nextcloud-Datenbank und Apps aktualisieren"
occ upgrade
occ app:update --all || warn "Nicht alle Apps konnten aktualisiert werden."
occ maintenance:mode --off >/dev/null 2>&1 || true
nc_post_upgrade

wait_container_health onlyoffice healthy 600
wait_container_health nc-nginx healthy 180

log "Aktive Versionen"
occ status
compose exec -T onlyoffice bash -lc 'dpkg-query -W -f="ONLYOFFICE ${Version}\n" onlyoffice-documentserver 2>/dev/null || true'

"$(dirname "$0")/doctor.sh"
