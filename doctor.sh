#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_env
trap - ERR
fail=0
check(){ local name=$1; shift; if "$@" >/dev/null 2>&1; then printf '%-40s OK\n' "$name"; else printf '%-40s FEHLER\n' "$name"; fail=1; fi; }
healthy(){ [[ $(docker inspect "$1" --format '{{.State.Health.Status}}' 2>/dev/null) == healthy ]]; }

c_oo_internal(){ compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true; }
c_nc_from_oo(){ compose exec -T onlyoffice curl -fsS http://nextcloud/status.php | jq -e '.installed == true'; }
c_trusted(){ occ config:system:get trusted_domains | grep -Fxq "$1"; }
c_nc_https(){ curl -kfsS --resolve "$NEXTCLOUD_DOMAIN:443:127.0.0.1" "https://$NEXTCLOUD_DOMAIN/status.php" | jq -e '.installed == true'; }
c_oo_https(){ curl -kfsS --resolve "$ONLYOFFICE_DOMAIN:443:127.0.0.1" "https://$ONLYOFFICE_DOMAIN/healthcheck" | grep -qx true; }
c_oo_root_404(){ [[ $(curl -ksS -o /dev/null -w '%{http_code}' --resolve "$ONLYOFFICE_DOMAIN:443:127.0.0.1" "https://$ONLYOFFICE_DOMAIN/") == 404 ]]; }
c_port(){ ss -H -ltn "sport = :$1" | grep -q .; }
c_no_autoconfig(){ compose exec -T nextcloud test ! -e /var/www/html/config/autoconfig.php; }
c_env_perms(){ [[ $(stat -c %a "$PROJECT_DIR/.env") == 600 ]]; }
c_no_plain_admin_pw(){ ! grep -q '^NEXTCLOUD_ADMIN_PASSWORD=' "$PROJECT_DIR/.env"; }

check "Docker" docker info
check "Compose-Konfiguration" compose config -q
check "PostgreSQL healthy" healthy nc-postgres
check "Redis healthy" healthy nc-redis
check "Nextcloud installiert" json_installed
check "autoconfig.php entfernt" c_no_autoconfig
check "Nextcloud healthy" healthy nextcloud
check "ONLYOFFICE healthy" healthy onlyoffice
check "Portainer läuft" container_running portainer
check "trusted_domains: $NEXTCLOUD_DOMAIN" c_trusted "$NEXTCLOUD_DOMAIN"
check "trusted_domains: nextcloud" c_trusted nextcloud
check "Docker-DNS onlyoffice" compose exec -T nextcloud getent hosts onlyoffice
check "Nextcloud → ONLYOFFICE intern" c_oo_internal
check "ONLYOFFICE → Nextcloud intern" c_nc_from_oo
check "NGINX-Konfiguration" compose exec -T nginx nginx -t
check "NGINX healthy" healthy nc-nginx
check "Host-Port 80" c_port 80
check "Host-Port 443" c_port 443
check "Cron läuft" container_running nextcloud-cron
check "Nextcloud HTTPS lokal" c_nc_https
check "ONLYOFFICE HTTPS lokal" c_oo_https
check "ONLYOFFICE-Startseite blockiert (404)" c_oo_root_404
check "ONLYOFFICE-Verbindung" occ onlyoffice:documentserver --check
check ".env nur für root (0600)" c_env_perms
check "Kein Klartext-Adminpasswort in .env" c_no_plain_admin_pw

if (( fail == 0 )); then echo "Gesamtstatus: HEALTHY"; else echo "Gesamtstatus: FEHLER"; exit 1; fi
