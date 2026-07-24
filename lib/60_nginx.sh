#!/usr/bin/env bash
phase_60_nginx(){
  log "60 – NGINX und Nextcloud-Cron starten"
  compose up -d nginx nextcloud-cron --remove-orphans
  wait_container_health nc-nginx healthy 180
  container_running nextcloud-cron || die "nextcloud-cron läuft nicht."
  ss -lnt | grep -Eq '(:80|:443)[[:space:]]' || die "Host-Ports 80/443 sind nicht geöffnet."
}
