#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
cd "$PROJECT_DIR"
[[ -f .env ]] || { echo "Fehler: $PROJECT_DIR/.env fehlt."; exit 1; }
set -a
source .env
set +a

: "${NEXTCLOUD_DOMAIN:?NEXTCLOUD_DOMAIN fehlt in .env}"
: "${ONLYOFFICE_DOMAIN:?ONLYOFFICE_DOMAIN fehlt in .env}"
: "${UPLOAD_LIMIT:=10G}"

log "ONLYOFFICE-NGINX-Konfiguration iframe-tauglich erzeugen"
sed -e "s/__ONLYOFFICE_DOMAIN__/$ONLYOFFICE_DOMAIN/g" \
    -e "s/__NEXTCLOUD_DOMAIN__/$NEXTCLOUD_DOMAIN/g" \
    -e "s/__UPLOAD_LIMIT__/$UPLOAD_LIMIT/g" \
  nginx/conf.d/onlyoffice.conf.template > nginx/conf.d/onlyoffice.conf

log "Compose-Konfiguration validieren"
compose config --quiet

log "ONLYOFFICE und NGINX neu erstellen"
compose up -d --force-recreate onlyoffice nginx

log "Tatsächlichen JWT-Schlüssel aus dem Container übernehmen"
JWT_SECRET="$(docker inspect onlyoffice --format='{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^JWT_SECRET=//p')"
JWT_HEADER="$(docker inspect onlyoffice --format='{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^JWT_HEADER=//p')"
[[ -n "$JWT_SECRET" ]] || { echo "Fehler: ONLYOFFICE JWT_SECRET fehlt."; exit 1; }
JWT_HEADER="${JWT_HEADER:-AuthorizationJwt}"

occ config:system:set trusted_domains 0 --value="$NEXTCLOUD_DOMAIN"
occ config:system:set trusted_domains 1 --value="nextcloud"
occ config:system:set overwritehost --value="$NEXTCLOUD_DOMAIN"
occ config:system:set overwriteprotocol --value="https"
occ config:system:set overwrite.cli.url --value="https://$NEXTCLOUD_DOMAIN"
occ config:system:set allow_local_remote_servers --type=boolean --value=true
occ config:app:set onlyoffice DocumentServerUrl --value="https://$ONLYOFFICE_DOMAIN/"
occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
occ config:app:set onlyoffice StorageUrl --value="http://nextcloud/"
occ config:app:set onlyoffice jwt_secret --value="$JWT_SECRET"
occ config:app:set onlyoffice jwt_header --value="$JWT_HEADER"
occ config:app:delete onlyoffice settings_error >/dev/null 2>&1 || true

log "NGINX-Konfiguration prüfen"
compose exec -T nginx nginx -t

log "Interne Kommunikationswege prüfen"
compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true
compose exec -T onlyoffice curl -fsS http://nextcloud/status.php | jq -e '.installed == true' >/dev/null

log "ONLYOFFICE-Connector prüfen"
occ onlyoffice:documentserver --check

cat <<MSG

Reparatur abgeschlossen.
Prüfe jetzt im Browser: https://$ONLYOFFICE_DOMAIN/healthcheck
Erwartete Ausgabe: true

Cloudflare Tunnel für $ONLYOFFICE_DOMAIN:
- Service: https://ORIGIN-IP:443
- HTTP Host Header: $ONLYOFFICE_DOMAIN
- Origin Server Name: $ONLYOFFICE_DOMAIN
- Keine interaktive Cloudflare-Access-Anmeldung vor ONLYOFFICE
MSG
