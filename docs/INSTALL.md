# Installation

1. DNS/Cloudflare für die Nextcloud- und ONLYOFFICE-Domain vorbereiten.
2. Projekt nach `/opt/nextcloud-enterprise` kopieren.
3. `chmod +x install.sh scripts/*.sh uninstall.sh`
4. Als root `./install.sh` ausführen.
5. Das selbstsignierte Zertifikat in `certs/` durch ein Cloudflare Origin Certificate ersetzen und `docker compose restart nginx` ausführen.
6. Portainer unter `https://LAN-IP:9443` initialisieren.

Portainer wird absichtlich nicht über NGINX oder Cloudflare veröffentlicht. Das Docker-Socket-Mount verleiht Portainer faktisch administrative Kontrolle über den Docker-Host; Portainer daher nur vertrauenswürdigen Administratoren zugänglich machen.

## ONLYOFFICE dauerhaft korrekt anbinden

Der Installer setzt automatisch:

- `ALLOW_PRIVATE_IP_ADDRESS=true` im Document Server,
- `nextcloud` als interne Trusted Domain,
- `allow_local_remote_servers=true`,
- identischen JWT-Schlüssel und `AuthorizationJwt` als Header,
- interne URLs `http://onlyoffice/` und `http://nextcloud/`,
- eine iframe-taugliche NGINX-Konfiguration für die getrennten Subdomains.

Für eine bestehende Installation kann die gesamte Korrektur mit folgendem Befehl erneut angewendet werden:

```bash
cd /opt/nextcloud-enterprise
./scripts/repair-onlyoffice.sh
```
