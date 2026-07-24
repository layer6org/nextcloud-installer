#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/lib.sh"
require_root

log "Sicherung vor dem Update"
"$PROJECT_DIR/scripts/backup.sh"

log "Aktuellste Hersteller-Images laden"
compose pull nextcloud nextcloud-cron onlyoffice
compose pull postgres redis nginx portainer

log "Container mit den neuen Images neu erstellen"
compose up -d --remove-orphans

log "Nextcloud-Datenbank und Apps aktualisieren"
for _ in $(seq 1 60); do
  compose exec -T -u www-data nextcloud test -f /var/www/html/occ >/dev/null 2>&1 && break
  sleep 5
done
occ upgrade
occ app:update --all || true
occ maintenance:repair

log "ONLYOFFICE-Verbindung prüfen"
occ onlyoffice:documentserver --check

log "Aktive Versionen"
occ status
compose exec -T onlyoffice bash -lc 'dpkg-query -W -f="ONLYOFFICE ${Version}\n" onlyoffice-documentserver 2>/dev/null || true'
compose ps
