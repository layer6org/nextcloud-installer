#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root; load_env
DEST=${1:-/hdd_data/nextcloud-backups/$(date +%Y%m%d-%H%M%S)}
mkdir -p "$DEST"
occ maintenance:mode --on
trap 'occ maintenance:mode --off >/dev/null 2>&1 || true' EXIT
compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip -c > "$DEST/database.sql.gz"
tar -C / -czf "$DEST/nextcloud-config.tgz" opt/nextcloud-enterprise ssd_data/nextcloud-enterprise/nextcloud/config
tar -C / -czf "$DEST/nextcloud-data.tgz" hdd_data/nextcloud-data
cp "$PROJECT_DIR/version.json" "$DEST/"
occ maintenance:mode --off
trap - EXIT
echo "Backup: $DEST"
