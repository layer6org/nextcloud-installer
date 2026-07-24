#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require_root
STAMP=$(date +%Y%m%d-%H%M%S)
DEST="/hdd_data/nextcloud-backups/$STAMP"
mkdir -p "$DEST"
cleanup() { compose exec -T -u www-data nextcloud php occ maintenance:mode --off >/dev/null 2>&1 || true; }
trap cleanup EXIT
log "Maintenance-Modus aktivieren"
compose exec -T -u www-data nextcloud php occ maintenance:mode --on
log "PostgreSQL sichern"
compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$DEST/nextcloud.pgdump"
log "Konfiguration und Anwendungsdaten sichern"
tar -C "$PROJECT_DIR" -czf "$DEST/project-config.tgz" --exclude=.git --exclude=certs/origin.key .
rsync -aHAX --delete /ssd_data/nextcloud-enterprise/nextcloud/ "$DEST/nextcloud-app/"
rsync -aHAX --delete /hdd_data/nextcloud-data/ "$DEST/nextcloud-data/"
rsync -aHAX --delete /ssd_data/nextcloud-enterprise/onlyoffice/ "$DEST/onlyoffice/"
sha256sum "$DEST/nextcloud.pgdump" "$DEST/project-config.tgz" > "$DEST/SHA256SUMS"
cleanup
trap - EXIT
find /hdd_data/nextcloud-backups -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +
log "Backup abgeschlossen: $DEST"
