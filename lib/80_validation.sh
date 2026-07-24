#!/usr/bin/env bash
phase_80_validation(){
  log "80 – Vollständige Abschlussvalidierung"
  for c in nc-postgres nc-redis nextcloud nextcloud-cron onlyoffice nc-nginx portainer; do
    container_running "$c" || die "$c läuft nicht."
  done
  wait_container_health nc-postgres healthy 60
  wait_container_health nc-redis healthy 60
  wait_container_health nextcloud healthy 120
  wait_container_health onlyoffice healthy 120
  wait_container_health nc-nginx healthy 60
  json_installed || die "Nextcloud meldet installed=false."
  compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php || die "autoconfig.php existiert."
  compose exec -T nextcloud getent hosts onlyoffice >/dev/null
  compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true
  curl -kfsS --resolve "$NEXTCLOUD_DOMAIN:443:127.0.0.1" "https://$NEXTCLOUD_DOMAIN/status.php" | jq -e '.installed == true' >/dev/null
  curl -kfsS --resolve "$ONLYOFFICE_DOMAIN:443:127.0.0.1" "https://$ONLYOFFICE_DOMAIN/healthcheck" | grep -qx true
  occ onlyoffice:documentserver --check
}
