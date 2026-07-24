#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root
SRC=${1:?Aufruf: restore.sh /pfad/zum/backup}
[[ -f "$SRC/database.sql.gz" && -f "$SRC/nextcloud-config.tgz" && -f "$SRC/nextcloud-data.tgz" ]] || die "Backup unvollständig."
tar -C / -xzf "$SRC/nextcloud-config.tgz"
load_env
compose up -d postgres redis
wait_container_health nc-postgres healthy 240
gzip -dc "$SRC/database.sql.gz" | compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
tar -C / -xzf "$SRC/nextcloud-data.tgz"
compose up -d
wait_container_health nextcloud healthy 600
occ maintenance:repair
"$(dirname "$0")/doctor.sh"
