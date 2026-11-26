# Cloudflare Zero Trust

Empfohlen:

- Zwei Public Hostnames bzw. Tunnel-Routen für Nextcloud und ONLYOFFICE.
- Origin-Ziel jeweils `https://SERVER-IP:443` mit passendem Host-Header.
- Cloudflare Origin Certificate in `certs/origin.crt` und `certs/origin.key` ablegen.
- Nextcloud-Zugriff durch Access Policy schützen.
- ONLYOFFICE muss für Browser und Nextcloud erreichbar sein; die Access-Policy darf die Editor-Requests nicht durch eine interaktive Anmeldung blockieren. Eine Service-Token- oder Bypass-Regel für die erforderlichen ONLYOFFICE-Pfade kann notwendig sein.
- 80/443 nur für `cloudflared` erreichbar machen, 9443 nur aus dem administrativen LAN/VLAN (siehe unten).
- `REALIP_TRUSTED_CIDRS` in `.env` auf die Adresse von `cloudflared` beschränken und danach `repair.sh` ausführen. Jede dort eingetragene Quelle kann die Client-IP per `CF-Connecting-IP` frei festlegen – auch gegenüber dem Brute-Force-Schutz von Nextcloud.

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

## Firewall: Docker-Ports richtig absichern

Von Docker veröffentlichte Ports werden per NAT weitergeleitet und **umgehen die INPUT-Regeln** von ufw oder firewalld. Eine Host-Firewall-Regel „443 nur aus dem LAN“ greift daher nicht.

Möglichkeiten:

1. **`cloudflared` auf demselben Host:** `NGINX_BIND_IP='127.0.0.1'` in `.env` setzen, Tunnel-Ziel `https://127.0.0.1:443`, danach `repair.sh`.
2. **`cloudflared` auf einem anderen Host:** `NGINX_BIND_IP` auf die LAN-IP setzen und Zugriffe in der `DOCKER-USER`-Chain filtern, z. B. nur `cloudflared` (192.168.10.5) auf eingehendes Interface `eth0` erlauben:

   ```bash
   iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctorigdstport 443 ! -s 192.168.10.5 -j DROP
   iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctorigdstport 80  ! -s 192.168.10.5 -j DROP
   ```

   Regeln dauerhaft speichern (z. B. `iptables-persistent`) und Interface sowie Adressen anpassen.
