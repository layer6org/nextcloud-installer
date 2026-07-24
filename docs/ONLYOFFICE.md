# ONLYOFFICE-Integration

## Soll-Konfiguration

| Zweck | Adresse |
|---|---|
| Öffentliche Document-Server-Adresse | `https://ONLYOFFICE_DOMAIN/` |
| Interne Adresse aus Nextcloud | `http://onlyoffice/` |
| Interne Nextcloud-Adresse aus ONLYOFFICE | `http://nextcloud/` |

## Erforderliche Einstellungen

Nextcloud:

- öffentliche Domain und `nextcloud` in `trusted_domains`
- `allow_local_remote_servers=true`
- Connector-JWT entspricht dem tatsächlich im Container gesetzten `JWT_SECRET`
- JWT-Header `AuthorizationJwt`

ONLYOFFICE:

- `JWT_ENABLED=true`
- `JWT_IN_BODY=true`
- `ALLOW_PRIVATE_IP_ADDRESS=true`
- gemeinsames Docker-Netz mit Nextcloud

NGINX:

- kein `X-Frame-Options: SAMEORIGIN` für die ONLYOFFICE-Subdomain
- `Content-Security-Policy: frame-ancestors 'self' https://NEXTCLOUD_DOMAIN`
- WebSocket-Upgrade-Header aktiviert

Cloudflare Tunnel:

- eigene Route für die ONLYOFFICE-Subdomain
- HTTPS zum NGINX-Origin
- korrekter HTTP Host Header und Origin Server Name
- keine interaktive Cloudflare-Access-Anmeldung vor ONLYOFFICE

## Prüfung

```bash
cd /opt/nextcloud-enterprise
./scripts/repair-onlyoffice.sh
```

Zusätzliche Einzeltests:

```bash
docker compose exec -T nextcloud curl -fsS http://onlyoffice/healthcheck
docker compose exec -T onlyoffice curl -fsS http://nextcloud/status.php
docker compose exec -T -u www-data nextcloud php occ onlyoffice:documentserver --check
```
