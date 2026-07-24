# Cloudflare Zero Trust

Empfohlen:

- Zwei Public Hostnames bzw. Tunnel-Routen für Nextcloud und ONLYOFFICE.
- Origin-Ziel jeweils `https://SERVER-IP:443` mit passendem Host-Header.
- Cloudflare Origin Certificate in `certs/origin.crt` und `certs/origin.key` ablegen.
- Nextcloud-Zugriff durch Access Policy schützen.
- ONLYOFFICE muss für Browser und Nextcloud erreichbar sein; die Access-Policy darf die Editor-Requests nicht durch eine interaktive Anmeldung blockieren. Eine Service-Token- oder Bypass-Regel für die erforderlichen ONLYOFFICE-Pfade kann notwendig sein.
- Die Host-Firewall sollte 80/443 nur aus dem LAN bzw. vom lokalen `cloudflared`-Prozess erreichbar machen. Port 9443 nur aus dem administrativen LAN/VLAN erlauben.

## Wichtige Einstellung für den ONLYOFFICE-Editor

`office.example.com` wird innerhalb von Nextcloud in einem iframe geladen. Deshalb:

- Auf der ONLYOFFICE-Domain keine interaktive Cloudflare-Access-Anmeldung erzwingen. Andernfalls landet die Access-Anmeldeseite im iframe und der Editor kann nicht starten.
- Die Tunnelroute muss auf den NGINX-Origin zeigen, typischerweise `https://SERVER-IP:443`.
- `HTTP Host Header` und `Origin Server Name` müssen auf die ONLYOFFICE-Domain gesetzt sein.
- Die mitgelieferte ONLYOFFICE-NGINX-Konfiguration setzt bewusst **kein** `X-Frame-Options: SAMEORIGIN`. Stattdessen erlaubt `Content-Security-Policy: frame-ancestors` ausschließlich die konfigurierte Nextcloud-Domain.

Schnelltest vom Client:

```bash
curl -I https://office.example.com/healthcheck
```

Die Antwort muss `HTTP 200` liefern und darf kein `X-Frame-Options: SAMEORIGIN` enthalten.
