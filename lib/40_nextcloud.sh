#!/usr/bin/env bash
phase_40_nextcloud(){
  log "40 – Nextcloud installieren und konfigurieren"
  local fresh=0
  nc_installed_on_disk || fresh=1
  compose up -d nextcloud portainer
  wait_http_in_container nextcloud http://127.0.0.1/status.php 600

  if (( fresh )); then
    nc_maintenance_install
  else
    # Das Image führt Upgrades beim Start selbst aus; hier nur absichern.
    occ upgrade || true
    occ maintenance:mode --off >/dev/null 2>&1 || true
  fi

  json_installed || die "Nextcloud wurde nicht vollständig installiert."
  compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php || die "autoconfig.php existiert weiterhin."

  configure_nextcloud
  nc_post_upgrade

  compose restart nextcloud
  wait_container_health nextcloud healthy 300
}
