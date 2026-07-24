#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require_root
BACKUP=${1:-}
[[ -d $BACKUP ]] || { echo "Aufruf: $0 /hdd_data/nextcloud-backups/JJJJMMTT-HHMMSS"; exit 1; }
(cd "$BACKUP" && sha256sum -c SHA256SUMS)
compose down
rsync -aHAX --delete "$BACKUP/nextcloud-app/" /ssd_data/nextcloud-enterprise/nextcloud/
rsync -aHAX --delete "$BACKUP/nextcloud-data/" /hdd_data/nextcloud-data/
rsync -aHAX --delete "$BACKUP/onlyoffice/" /ssd_data/nextcloud-enterprise/onlyoffice/
compose up -d postgres redis
for _ in $(seq 1 30); do compose exec -T postgres pg_isready -U "$POSTGRES_USER" && break; sleep 2; done
compose exec -T postgres dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB"
compose exec -T postgres createdb -U "$POSTGRES_USER" "$POSTGRES_DB"
cat "$BACKUP/nextcloud.pgdump" | compose exec -T postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists
compose up -d
compose exec -T -u www-data nextcloud php occ maintenance:repair
compose exec -T -u www-data nextcloud php occ maintenance:mode --off || true
compose ps
