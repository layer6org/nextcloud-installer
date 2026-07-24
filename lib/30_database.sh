#!/usr/bin/env bash
phase_30_database(){
  log "30 – PostgreSQL und Redis validieren"
  wait_container_health nc-postgres healthy 240
  wait_container_health nc-redis healthy 180
  compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null
  compose exec -T redis redis-cli -a "$REDIS_PASSWORD" ping | grep -qx PONG

  if ! json_installed; then
    local count
    count=$(compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
      "select count(*) from pg_tables where schemaname='public';" | tr -d '[:space:]')
    [[ "$count" == 0 ]] || die "Nextcloud ist nicht installiert, die Datenbank enthält aber $count Tabellen. repair.sh verwenden."
  fi
}
