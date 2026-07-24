#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
[[ -f "$PROJECT_DIR/.env" ]] || { echo '.env fehlt.' >&2; exit 1; }

errors=0
pass() { echo "OK: $1"; }
fail() { echo "FEHLER: $1" >&2; errors=$((errors+1)); }
run_check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

run_check 'Compose-Konfiguration gültig' compose config --quiet

running_services="$(compose ps --status running --services 2>/dev/null || true)"
for service in postgres redis nextcloud nextcloud-cron onlyoffice nginx portainer; do
  if grep -qx "$service" <<<"$running_services"; then pass "Container $service läuft"; else fail "Container $service läuft nicht"; fi
done

if compose exec -T -u www-data nextcloud php occ status --output=json 2>/dev/null | jq -e '.installed == true' >/dev/null; then
  pass 'Nextcloud ist installiert'
else
  fail 'Nextcloud ist nicht vollständig installiert'
fi


trusted_domains="$(compose exec -T -u www-data nextcloud php occ config:system:get trusted_domains 2>/dev/null || true)"
if grep -Fxq "$NEXTCLOUD_DOMAIN" <<<"$trusted_domains"; then
  pass "Öffentliche Nextcloud-Domain ist vertrauenswürdig"
else
  fail "$NEXTCLOUD_DOMAIN fehlt in trusted_domains"
fi
if grep -Fxq "nextcloud" <<<"$trusted_domains"; then
  pass "Interner Nextcloud-Hostname ist vertrauenswürdig"
else
  fail "Interner Hostname nextcloud fehlt in trusted_domains"
fi

nextcloud_code="$(curl -ksS -o /tmp/nc-domain-validate.html -w '%{http_code}' --resolve "$NEXTCLOUD_DOMAIN:443:127.0.0.1" "https://$NEXTCLOUD_DOMAIN/status.php" || true)"
if [[ $nextcloud_code == 200 ]] && jq -e '.installed == true' /tmp/nc-domain-validate.html >/dev/null 2>&1; then
  pass "Öffentliche Nextcloud-Domain liefert den korrekten Status"
else
  fail "Öffentliche Nextcloud-Domain fehlerhaft (HTTP ${nextcloud_code:-keine Antwort})"
fi
rm -f /tmp/nc-domain-validate.html

if compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck 2>/dev/null | grep -qx true; then
  pass 'Nextcloud erreicht ONLYOFFICE intern'
else
  fail 'Nextcloud erreicht ONLYOFFICE intern nicht'
fi

if compose exec -T onlyoffice curl -fsS http://nextcloud/status.php 2>/dev/null | jq -e '.installed == true' >/dev/null; then
  pass 'ONLYOFFICE erreicht Nextcloud intern'
else
  fail 'ONLYOFFICE erreicht Nextcloud intern nicht'
fi

if compose exec -T -u www-data nextcloud php occ onlyoffice:documentserver --check >/dev/null 2>&1; then
  pass 'ONLYOFFICE-Connector erfolgreich'
else
  fail 'ONLYOFFICE-Connector fehlgeschlagen'
fi

root_code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve "$ONLYOFFICE_DOMAIN:443:127.0.0.1" "https://$ONLYOFFICE_DOMAIN/" || true)"
if [[ $root_code == 404 ]]; then
  pass 'ONLYOFFICE-Welcome-Seite ist blockiert'
else
  fail "ONLYOFFICE-Rootseite liefert HTTP ${root_code:-keine Antwort} statt 404"
fi

if curl -fsSk "https://$ONLYOFFICE_DOMAIN/healthcheck" 2>/dev/null | grep -qx true; then
  pass 'Öffentlicher ONLYOFFICE-Healthcheck erfolgreich'
else
  fail 'Öffentlicher ONLYOFFICE-Healthcheck fehlgeschlagen'
fi

if compose exec -T nginx nginx -t >/dev/null 2>&1; then
  pass 'NGINX-Konfiguration gültig'
else
  fail 'NGINX-Konfiguration ungültig'
fi

if (( errors > 0 )); then
  echo "Validierung mit $errors Fehler(n) fehlgeschlagen." >&2
  exit 1
fi
echo 'End-to-End-Validierung erfolgreich.'
