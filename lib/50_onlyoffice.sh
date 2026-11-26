#!/usr/bin/env bash
phase_50_onlyoffice(){
  log "50 – ONLYOFFICE installieren, verbinden und prüfen"
  compose up -d onlyoffice
  wait_container_health onlyoffice healthy 360
  compose exec -T nextcloud getent hosts onlyoffice >/dev/null || die "Docker-DNS-Alias onlyoffice fehlt."
  compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true

  configure_onlyoffice
  occ app:list --output=json | jq -e '.enabled.onlyoffice != null' >/dev/null
  occ onlyoffice:documentserver --check
}
