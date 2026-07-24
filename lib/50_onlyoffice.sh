#!/usr/bin/env bash
phase_50_onlyoffice(){
  log "50 – ONLYOFFICE installieren, verbinden und prüfen"
  compose up -d onlyoffice
  wait_container_health onlyoffice healthy 360
  compose exec -T nextcloud getent hosts onlyoffice >/dev/null || die "Docker-DNS-Alias onlyoffice fehlt."
  compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck | grep -qx true

  occ app:install onlyoffice || true
  occ app:enable onlyoffice
  occ config:app:set onlyoffice DocumentServerUrl --value="https://$ONLYOFFICE_DOMAIN/"
  occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
  occ config:app:set onlyoffice StorageUrl --value="http://nextcloud/"
  occ config:app:set onlyoffice jwt_secret --value="$ONLYOFFICE_JWT_SECRET"
  occ config:app:set onlyoffice jwt_header --value=AuthorizationJwt
  occ config:app:set onlyoffice jwt_in_body --value=true
  occ app:list --output=json | jq -e '.enabled.onlyoffice != null' >/dev/null
  occ onlyoffice:documentserver --check
}
