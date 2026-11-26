# Installation

1. `/ssd_data` und `/hdd_data` einhängen (der Installer prüft das).
2. DNS bzw. Cloudflare für die Nextcloud- und die ONLYOFFICE-Domain vorbereiten (siehe [CLOUDFLARE.md](CLOUDFLARE.md)).
3. Installer außerhalb von `/opt` entpacken (z. B. unter `/tmp`) und als root `./install.sh` ausführen.
4. Abfragen beantworten:

   | Abfrage | Bedeutung |
   |---|---|
   | Nextcloud-/ONLYOFFICE-Domain | zwei unterschiedliche FQDNs |
   | Bind-IP für NGINX | `127.0.0.1`, wenn `cloudflared` auf diesem Host läuft; sonst die LAN-IP oder `0.0.0.0` |
   | Adresse(n) von cloudflared | IP/Netz, dem `CF-Connecting-IP` geglaubt wird; bei lokalem `cloudflared` das Docker-Netz `172.16.0.0/12` |
   | Portainer-Bind-IP | Standard `127.0.0.1` (Zugriff per SSH-Tunnel); für das Admin-LAN dessen LAN-IP eintragen |
   | Administrator, Passwort | Passwort mind. 12 Zeichen; es wird nicht gespeichert |

5. Das selbstsignierte Zertifikat in `/opt/nextcloud-enterprise/certs/` durch ein Cloudflare Origin Certificate ersetzen und `/opt/nextcloud-enterprise-tools/repair.sh` ausführen.
6. Portainer unter `https://PORTAINER-BIND-IP:9443` innerhalb von fünf Minuten initialisieren (bei `127.0.0.1`: `ssh -L 9443:127.0.0.1:9443 server`).
7. Optional: tägliches Backup aktivieren – `systemctl enable --now nextcloud-backup.timer`.
8. Optional: Authentifizierungsrichtlinie anwenden – siehe [AUTHENTICATION.md](AUTHENTICATION.md).

Portainer wird absichtlich nicht über NGINX oder Cloudflare veröffentlicht. Das Docker-Socket-Mount verleiht Portainer faktisch administrative Kontrolle über den Docker-Host.

## Secrets

`/opt/nextcloud-enterprise/.env` (Modus 0600) enthält Datenbank-, Redis- und JWT-Secrets. Image-Versionen stehen getrennt in `versions.env`. Das Adminpasswort wird nur während einer Neuinstallation im Speicher gehalten; ältere `.env`-Dateien werden beim nächsten Lauf automatisch bereinigt.

## ONLYOFFICE dauerhaft korrekt anbinden

Der Installer setzt automatisch:

- `ALLOW_PRIVATE_IP_ADDRESS=true` im Document Server,
- `nextcloud` als interne Trusted Domain,
- `allow_local_remote_servers=true`,
- identischen JWT-Schlüssel und `AuthorizationJwt` als Header,
- interne URLs `http://onlyoffice/` und `http://nextcloud/`,
- eine iframe-taugliche NGINX-Konfiguration für die getrennten Subdomains.

Für eine bestehende Installation wird die gesamte Konfiguration mit `/opt/nextcloud-enterprise-tools/repair.sh` erneut angewendet.
