#!/usr/bin/env bash
# Stellt ein Backup wieder her. Unterstützt:
#   Format 2 (ab 5.2.0):   database.pgdump, db-roles.sql, project.tgz, nextcloud-app.tgz, nextcloud-data.tgz, onlyoffice.tgz
#   Altformat Root-Skript: database.sql.gz, nextcloud-config.tgz, nextcloud-data.tgz
#   Altformat scripts/:    nextcloud.pgdump, project-config.tgz, nextcloud-app/, nextcloud-data/, onlyoffice/
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
acquire_lock
need docker; need rsync

ASSUME_YES=0
SRC=""
for arg in "$@"; do
  case $arg in
    --yes|-y) ASSUME_YES=1 ;;
    -*) die "Unbekannte Option: $arg" ;;
    *) SRC=$arg ;;
  esac
done
[[ -n $SRC && -d $SRC ]] || die "Aufruf: restore.sh [--yes] /pfad/zum/backup"
SRC=$(cd "$SRC" && pwd)

if [[ -f $SRC/database.pgdump && -f $SRC/project.tgz && -f $SRC/nextcloud-app.tgz && -f $SRC/nextcloud-data.tgz ]]; then
  FORMAT=v2
elif [[ -f $SRC/database.sql.gz && -f $SRC/nextcloud-config.tgz && -f $SRC/nextcloud-data.tgz ]]; then
  FORMAT=legacy-root
elif [[ -f $SRC/nextcloud.pgdump && -f $SRC/project-config.tgz && -d $SRC/nextcloud-app && -d $SRC/nextcloud-data ]]; then
  FORMAT=legacy-scripts
else
  die "Backup unvollständig oder unbekanntes Format: $SRC"
fi
log "Backup-Format: $FORMAT"

if [[ -f $SRC/SHA256SUMS ]]; then
  (cd "$SRC" && sha256sum -c --quiet SHA256SUMS) || die "Prüfsummen stimmen nicht."
else
  warn "Keine SHA256SUMS vorhanden – Integrität ungeprüft."
fi

if (( ! ASSUME_YES )); then
  [[ -t 0 ]] || die "Bestätigung erforderlich; für automatisierte Läufe --yes verwenden."
  echo "ACHTUNG: Datenbank, Nextcloud-Anwendung, Nutzdaten und Konfiguration werden durch"
  echo "         den Stand aus $SRC ERSETZT. Neuere Dateien gehen verloren."
  read -r -p "Zum Fortfahren exakt WIEDERHERSTELLEN eingeben: " answer
  [[ $answer == WIEDERHERSTELLEN ]] || { echo "Abgebrochen."; exit 0; }
fi

wipe_dir(){
  local d=$1
  [[ -n $d && $d == /*/* ]] || die "Unsicherer Pfad: '$d'"
  install -d -m 0750 "$d"
  find "$d" -xdev -mindepth 1 -delete
}
extract_into_root(){ tar -C / -xzf "$1"; }

log "Dienste anhalten"
if [[ -f $PROJECT_DIR/compose.yml && -f $PROJECT_DIR/.env ]]; then
  compose stop nginx nextcloud-cron nextcloud onlyoffice 2>/dev/null || true
else
  docker stop nc-nginx nextcloud-cron nextcloud onlyoffice 2>/dev/null || true
fi

log "Projektkonfiguration wiederherstellen"
case $FORMAT in
  v2)             extract_into_root "$SRC/project.tgz" ;;
  legacy-root)    extract_into_root "$SRC/nextcloud-config.tgz" ;;  # enthält auch nextcloud/config
  legacy-scripts) install -d -m 0750 "$PROJECT_DIR"; tar -C "$PROJECT_DIR" -xzf "$SRC/project-config.tgz" ;;
esac
[[ -f $PROJECT_DIR/.env ]] || die "Backup enthält keine .env."
# Image-Versionen des Backups behalten (müssen zum gesicherten Datenstand passen),
# Compose-/NGINX-Dateien aber auf den aktuellen Werkzeugstand bringen.
saved_versions=$(mktemp)
if [[ -f $PROJECT_DIR/versions.env ]]; then
  cp "$PROJECT_DIR/versions.env" "$saved_versions"
else
  grep -E '^(NEXTCLOUD|POSTGRES|REDIS|ONLYOFFICE|NGINX|PORTAINER)_IMAGE=' "$PROJECT_DIR/.env" > "$saved_versions" || true
fi
sync_runtime_files
if [[ -s $saved_versions ]]; then cp "$saved_versions" "$PROJECT_DIR/versions.env"; fi
rm -f "$saved_versions"
load_env
render_nginx_configs
compose stop nginx nextcloud-cron nextcloud onlyoffice 2>/dev/null || true

log "Nextcloud-Anwendung wiederherstellen"
case $FORMAT in
  v2)             wipe_dir "$NC_APP_DIR"; extract_into_root "$SRC/nextcloud-app.tgz" ;;
  legacy-scripts) rsync -aHAX --delete "$SRC/nextcloud-app/" "$NC_APP_DIR/" ;;
  legacy-root)    warn "Altformat ohne custom_apps – Apps werden nach dem Restore neu installiert." ;;
esac

log "Nutzdaten wiederherstellen"
case $FORMAT in
  v2|legacy-root) wipe_dir "$NC_DATA_DIR"; extract_into_root "$SRC/nextcloud-data.tgz" ;;
  legacy-scripts) rsync -aHAX --delete "$SRC/nextcloud-data/" "$NC_DATA_DIR/" ;;
esac

log "ONLYOFFICE-Daten wiederherstellen"
case $FORMAT in
  v2)             if [[ -f $SRC/onlyoffice.tgz ]]; then wipe_dir "$SSD_ROOT/onlyoffice"; extract_into_root "$SRC/onlyoffice.tgz"; fi ;;
  legacy-scripts) if [[ -d $SRC/onlyoffice ]]; then rsync -aHAX --delete "$SRC/onlyoffice/" "$SSD_ROOT/onlyoffice/"; fi ;;
  legacy-root)    : ;;
esac

log "Datenbank wiederherstellen"
compose up -d postgres redis
wait_container_health nc-postgres healthy 240
psql_admin(){ compose exec -T postgres psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 "$@"; }

if [[ -f $SRC/db-roles.sql ]]; then
  # Bereits vorhandene Rollen erzeugen erwartbare Fehler; diese sind unkritisch.
  compose exec -T postgres psql -U "$POSTGRES_USER" -d postgres -q < "$SRC/db-roles.sql" >/dev/null 2>&1 || true
fi
# Nextcloud legt bei der Installation einen eigenen DB-Benutzer (z. B. oc_admin) an.
# Fehlt er (Altformat, neuer Host), wird er aus config.php wiederhergestellt.
dbuser=$(sed -nE "s/^[[:space:]]*'dbuser'[[:space:]]*=>[[:space:]]*'([^']*)'.*/\1/p" "$NC_CONFIG_FILE" | head -n1)
dbpass=$(sed -nE "s/^[[:space:]]*'dbpassword'[[:space:]]*=>[[:space:]]*'([^']*)'.*/\1/p" "$NC_CONFIG_FILE" | head -n1)
if [[ -n $dbuser && $dbuser != "$POSTGRES_USER" ]]; then
  exists=$(psql_admin -Atc "select 1 from pg_roles where rolname = '${dbuser//\'/\'\'}'" | tr -d '[:space:]')
  if [[ $exists != 1 ]]; then
    log "DB-Rolle $dbuser anlegen"
    psql_admin -v u="$dbuser" -v p="$dbpass" <<'SQL'
CREATE ROLE :"u" LOGIN CREATEDB PASSWORD :'p';
SQL
  elif [[ -n $dbpass ]]; then
    # Passwort an config.php angleichen (z. B. Restore auf einen frisch installierten Host).
    psql_admin -v u="$dbuser" -v p="$dbpass" <<'SQL'
ALTER ROLE :"u" WITH LOGIN PASSWORD :'p';
SQL
  fi
fi

compose exec -T postgres dropdb -U "$POSTGRES_USER" --if-exists --force "$POSTGRES_DB"
case $FORMAT in
  v2|legacy-scripts)
    dump="$SRC/database.pgdump"
    if [[ $FORMAT == legacy-scripts ]]; then dump="$SRC/nextcloud.pgdump"; fi
    compose exec -T postgres pg_restore -U "$POSTGRES_USER" -d postgres --create --exit-on-error < "$dump"
    ;;
  legacy-root)
    owner=${dbuser:-$POSTGRES_USER}
    compose exec -T postgres createdb -U "$POSTGRES_USER" -O "$owner" "$POSTGRES_DB"
    gzip -dc "$SRC/database.sql.gz" | compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q
    ;;
esac

log "Stack starten"
compose up -d
wait_container_health nextcloud healthy 600
occ maintenance:mode --off
occ maintenance:data-fingerprint
if [[ $FORMAT == legacy-root ]]; then
  configure_onlyoffice
  occ app:install twofactor_totp >/dev/null 2>&1 || true
fi
occ maintenance:repair
wait_container_health onlyoffice healthy 360
wait_container_health nc-nginx healthy 180

log "Wiederherstellung abgeschlossen – Gesundheitsprüfung"
"$(dirname "$0")/doctor.sh"
