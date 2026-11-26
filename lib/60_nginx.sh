#!/usr/bin/env bash
phase_60_nginx(){
  log "60 – NGINX und Nextcloud-Cron starten"
  compose up -d --remove-orphans nginx nextcloud-cron
  wait_container_health nc-nginx healthy 180
  container_running nextcloud-cron || die "nextcloud-cron läuft nicht."
  local port
  for port in 80 443; do
    ss -H -ltn "sport = :$port" | grep -q . || die "Host-Port $port ist nicht geöffnet."
  done
}
