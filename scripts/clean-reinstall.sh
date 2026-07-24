#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ $EUID -eq 0 ]] || { echo "Als root ausführen." >&2; exit 1; }

cat <<'WARNING'
Dieses Skript entfernt alle Daten dieses Nextcloud-/ONLYOFFICE-Projekts,
behält Docker jedoch installiert. Es ist für einen wirklich sauberen Neustart
nach einer abgebrochenen Testinstallation gedacht.
WARNING
read -r -p 'Zum Fortfahren exakt NEUINSTALLATION eingeben: ' answer
[[ $answer == NEUINSTALLATION ]] || { echo "Abgebrochen."; exit 0; }

if command -v docker >/dev/null 2>&1; then
  if [[ -f "$PROJECT_DIR/.env" ]]; then
    docker compose --env-file "$PROJECT_DIR/.env" -f "$PROJECT_DIR/compose.yml" down --remove-orphans --volumes --timeout 120 || true
  fi
  docker rm -f nc-nginx nextcloud nextcloud-cron onlyoffice nc-postgres nc-redis portainer 2>/dev/null || true
  docker network rm nc_frontend nc_database nc_management 2>/dev/null || true
fi
wipe_path() {
  local path=$1
  [[ -e $path ]] || return 0
  find "$path" -xdev -mindepth 1 -delete
  rmdir "$path" 2>/dev/null || true
  [[ ! -e $path ]] || { echo "Konnte $path nicht vollständig löschen." >&2; exit 1; }
}
wipe_path /ssd_data/nextcloud-enterprise
wipe_path /hdd_data/nextcloud-data
wipe_path /hdd_data/onlyoffice-logs
wipe_path /hdd_data/nextcloud-backups
rm -f "$PROJECT_DIR/.env"
echo "Projektdaten entfernt. Jetzt ./install.sh starten."
