#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root; load_env
fail=0
check(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then printf '%-32s OK\n' "$name"; else printf '%-32s FEHLER\n' "$name"; fail=1; fi; }
check "Docker" docker info
check "Compose-Konfiguration" compose config -q
check "PostgreSQL healthy" test "$(docker inspect nc-postgres --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy
check "Redis healthy" test "$(docker inspect nc-redis --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy
check "Nextcloud installiert" json_installed
check "autoconfig.php entfernt" compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php
check "Nextcloud healthy" test "$(docker inspect nextcloud --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy
check "ONLYOFFICE healthy" test "$(docker inspect onlyoffice --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy
check "Docker-DNS onlyoffice" compose exec -T nextcloud getent hosts onlyoffice
check "ONLYOFFICE intern" bash -c "$(declare -f compose); compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true"
check "NGINX-Konfiguration" compose exec -T nginx nginx -t
check "NGINX healthy" test "$(docker inspect nc-nginx --format '{{.State.Health.Status}}' 2>/dev/null)" = healthy
check "Cron läuft" container_running nextcloud-cron
check "Nextcloud HTTPS lokal" bash -c "curl -kfsS --resolve '$NEXTCLOUD_DOMAIN:443:127.0.0.1' 'https://$NEXTCLOUD_DOMAIN/status.php' | jq -e '.installed == true'"
check "ONLYOFFICE HTTPS lokal" bash -c "curl -kfsS --resolve '$ONLYOFFICE_DOMAIN:443:127.0.0.1' 'https://$ONLYOFFICE_DOMAIN/healthcheck' | grep -qx true"
check "ONLYOFFICE-Verbindung" occ onlyoffice:documentserver --check
(( fail == 0 )) && echo "Gesamtstatus: HEALTHY" || { echo "Gesamtstatus: FEHLER"; exit 1; }
