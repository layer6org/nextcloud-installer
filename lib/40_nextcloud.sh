#!/usr/bin/env bash
phase_40_nextcloud(){
  log "40 – Nextcloud installieren und konfigurieren"
  compose up -d nextcloud portainer
  wait_http_in_container nextcloud http://127.0.0.1/status.php 240

  if ! json_installed; then
    compose exec -T nextcloud rm -f /var/www/html/config/autoconfig.php
    compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php
    occ maintenance:install \
      --database=pgsql --database-host=postgres \
      --database-name="$POSTGRES_DB" --database-user="$POSTGRES_USER" \
      --database-pass="$POSTGRES_PASSWORD" \
      --admin-user="$NEXTCLOUD_ADMIN_USER" --admin-pass="$NEXTCLOUD_ADMIN_PASSWORD" \
      --data-dir=/var/www/html/data
  fi

  json_installed || die "Nextcloud wurde nicht vollständig installiert."
  compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php || die "autoconfig.php existiert weiterhin."

  occ background:cron
  occ config:system:set trusted_domains 0 --value="$NEXTCLOUD_DOMAIN"
  occ config:system:set trusted_domains 1 --value=nextcloud
  occ config:system:set overwritehost --value="$NEXTCLOUD_DOMAIN"
  occ config:system:set overwriteprotocol --value=https
  occ config:system:set overwrite.cli.url --value="https://$NEXTCLOUD_DOMAIN"
  occ config:system:set allow_local_remote_servers --type=boolean --value=true
  occ config:system:set trusted_proxies 0 --value="$TRUSTED_PROXIES"
  occ config:system:set default_phone_region --value=DE
  occ config:system:set maintenance_window_start --type=integer --value=1
  occ config:system:set redis host --value=redis
  occ config:system:set redis password --value="$REDIS_PASSWORD"
  occ config:system:set redis port --type=integer --value=6379
  occ config:system:set memcache.local --value='\\OC\\Memcache\\APCu'
  occ config:system:set memcache.locking --value='\\OC\\Memcache\\Redis'
  occ config:system:set memcache.distributed --value='\\OC\\Memcache\\Redis'

  compose restart nextcloud
  wait_container_health nextcloud healthy 300
}
