#!/usr/bin/env bash
# Vollständige, konsistente Sicherung (Format 2):
#   database.pgdump   PostgreSQL im Custom-Format (pg_dump -Fc)
#   db-roles.sql      Datenbankrollen inkl. des von Nextcloud angelegten DB-Benutzers
#   project.tgz       /opt/nextcloud-enterprise inkl. .env und Zertifikaten (enthält Secrets!)
#   nextcloud-app.tgz Nextcloud-Webroot inkl. config/, custom_apps/ und themes/
#   nextcloud-data.tgz Nutzdaten
#   onlyoffice.tgz    ONLYOFFICE-Daten
#   SHA256SUMS, FORMAT, version.json
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
acquire_lock
load_env
umask 077

DEST=${1:-$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)}
[[ ! -e $DEST ]] || die "Ziel existiert bereits: $DEST"
install -d -m 0700 "$BACKUP_ROOT"
install -d -m 0700 "$DEST.partial"

maintenance_off(){ occ maintenance:mode --off >/dev/null 2>&1 || true; }
on_exit(){ local rc=$?; maintenance_off; (( rc == 0 )) || warn "Backup fehlgeschlagen; unvollständiges Verzeichnis: $DEST.partial"; }
trap on_exit EXIT
# GNU tar liefert Exit 1, wenn sich Dateien während des Lesens ändern (z. B. ONLYOFFICE-Cache).
tar_dir(){ local rc=0; tar -C / --warning=no-file-changed -czf "$1" "$2" || rc=$?; (( rc <= 1 )) || die "tar fehlgeschlagen: $2"; }

log "Wartungsmodus aktivieren"
occ maintenance:mode --on

log "PostgreSQL sichern"
compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc > "$DEST.partial/database.pgdump"
compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" --roles-only > "$DEST.partial/db-roles.sql"

log "Konfiguration, Anwendung und Daten sichern"
tar_dir "$DEST.partial/project.tgz" "${PROJECT_DIR#/}"
tar_dir "$DEST.partial/nextcloud-app.tgz" "${NC_APP_DIR#/}"
tar_dir "$DEST.partial/nextcloud-data.tgz" "${NC_DATA_DIR#/}"
tar_dir "$DEST.partial/onlyoffice.tgz" "${SSD_ROOT#/}/onlyoffice"

maintenance_off
log "Wartungsmodus beendet – Prüfsummen erzeugen"

cp "$PROJECT_DIR/version.json" "$DEST.partial/"
echo 2 > "$DEST.partial/FORMAT"
(cd "$DEST.partial" && sha256sum database.pgdump db-roles.sql project.tgz nextcloud-app.tgz nextcloud-data.tgz onlyoffice.tgz > SHA256SUMS)
mv "$DEST.partial" "$DEST"
trap - EXIT

# Aufbewahrung: nur vollständige Backups nach Namensschema löschen.
if [[ $BACKUP_RETENTION_DAYS =~ ^[0-9]+$ ]] && (( BACKUP_RETENTION_DAYS > 0 )); then
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended \
    -regex '.*/[0-9]{8}-[0-9]{6}' -mtime +"$BACKUP_RETENTION_DAYS" -print -exec rm -rf {} +
fi

log "Backup abgeschlossen: $DEST"
warn "Backups auf demselben Server ersetzen keine Offsite-Sicherung. $DEST enthält alle Secrets (.env)."
