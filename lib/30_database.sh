#!/usr/bin/env bash
phase_30_database(){
  log "30 – PostgreSQL und Redis validieren"
  wait_container_health nc-postgres healthy 240
  wait_container_health nc-redis healthy 180
  compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null
  compose exec -T redis redis-cli ping | grep -qx PONG

  # Zustand aus config.php ermitteln – der Nextcloud-Container läuft hier noch nicht.
  if ! nc_installed_on_disk; then
    local count
    count=$(db_table_count)
    [[ "$count" == 0 ]] || die "Nextcloud ist laut config.php nicht installiert, die Datenbank enthält aber $count Tabellen. Mit restore.sh ein Backup einspielen oder mit uninstall.sh bereinigen."
  fi
}
