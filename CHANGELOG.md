# Changelog

## 5.2.0 – 2026-11-26

### Fehlerbehebungen

- **Updates:** Image-Versionen stehen nur noch in `versions.env`; Compose liest `versions.env` und `.env`. Bisher wurden neue Versionen nie übernommen, weil sie einmalig in `.env` kopiert wurden. Bestehende `.env`-Dateien werden automatisch migriert.
- **`.env`:** Werte werden sicher gequotet; das Adminpasswort wird nicht mehr gespeichert. Sonderzeichen (`$`, `;`, Leerzeichen) im Passwort führten zuvor zu falschen Passwörtern bzw. zur Ausführung von Befehlen beim Einlesen.
- **`uninstall.sh --keep-data`:** `.env` und `certs/` bleiben erhalten; Phase 30 erkennt eine bestehende Installation anhand von `config.php` statt über den noch nicht laufenden Container. Eine Neuinstallation mit erhaltenen Daten schlug zuvor immer fehl.
- **Backup:** sichert jetzt auch `custom_apps/` und `themes/` (kompletter Webroot), ONLYOFFICE-Daten und die DB-Rollen inkl. des von Nextcloud angelegten DB-Benutzers; Prüfsummen über alle Dateien, atomarer Abschluss, Aufbewahrungsfrist.
- **Restore:** stoppt die Dienste, ersetzt Daten vollständig statt sie zu überlagern, stellt die Datenbank mit `pg_restore --create --exit-on-error` wieder her, legt fehlende DB-Rollen an, führt `maintenance:data-fingerprint` aus und unterstützt ältere Backup-Formate.
- **PostgreSQL:** die gemountete `postgresql.conf` wird jetzt tatsächlich geladen (`config_file`), mit `shm_size` und längerer Stop-Frist.
- **Memcache:** `memcache.*` wurde mit doppelten Backslashes gespeichert.
- **Security-Skripte:** `OC_PASS` wurde nicht in den Container übergeben, wodurch `seal-admin-password.sh` und `emergency-unlock-admin.sh` fehlschlugen.
- Portprüfung verlangt 80 **und** 443; ERR-Trap zeigt die richtige Datei; `wait_container_health` bricht bei beendeten Containern sofort ab.
- `uninstall.sh --purge-docker` übergibt nur installierte Pakete an `apt-get purge`.

### Sicherheit

- NGINX-Bind-IP (`NGINX_BIND_IP`) und vertrauenswürdige cloudflared-Adressen (`REALIP_TRUSTED_CIDRS`) sind konfigurierbar; Dokumentation zur `DOCKER-USER`-Chain.
- Unbekannte Hostnamen auf 443 werden per `ssl_reject_handshake` abgewiesen.
- Keine doppelten Sicherheits-Header mehr im Nextcloud-vHost; `X-XSS-Protection` entfernt.
- Redis-Passwort über `REDISCLI_AUTH` statt `-a`; Admin- und DB-Passwort nicht mehr in der docker-Befehlszeile.
- Logs (0640), Log-Verzeichnis (0750) und Backups (0700) nur für root.
- Eingaben (Domains, IPs, CIDRs, Benutzername) werden validiert.

### Verbesserungen

- Preflight-Prüfungen im Installer: Mountpoints, Speicherplatz, RAM, freie Ports.
- Upgrade-Pfad-Prüfung: keine übersprungenen Nextcloud-Hauptversionen, keine Downgrades.
- `install.sh` auf bestehenden Systemen erstellt vorher ein Backup.
- Sperre gegen parallele Läufe (`/run/nextcloud-enterprise.lock`).
- Nach Installation/Upgrade: `db:add-missing-*` und `maintenance:repair --include-expensive`.
- `doctor.sh` übernimmt die Prüfungen aus `validate.sh` (trusted_domains, ONLYOFFICE→Nextcloud, 404 der Startseite, Ports, `.env`-Rechte).
- systemd-Backup-Timer wird installiert (Aktivierung manuell).
- Upload- und Speicherlimit nur noch über `.env` (`UPLOAD_LIMIT`, `PHP_MEMORY_LIMIT`); gilt auch für den Cron-Container.
- Redis als reiner Cache ohne Persistenz, Verdrängung `volatile-lru`.
- `uninstall.sh`: `--purge-backups`, `--delete-data`, Backups bleiben standardmäßig erhalten.
- Frisch installiertes Docker erhält `config/docker-daemon.json`.

### Aufräumen

- Doppelter Skriptsatz `scripts/` entfernt; Funktionen in die Werkzeuge unter `/opt/nextcloud-enterprise-tools` übernommen. Security-Skripte liegen unter `/opt/nextcloud-enterprise-tools/security/`.
- Laufzeitverzeichnis enthält nur noch Laufzeitdateien.
- Versionsangabe nur noch in `version.json`; `.gitignore` ergänzt, `.DS_Store` entfernt; Dokumentation vereinheitlicht.

## 5.1.2 – 2026-07-23

- Debian-13-Paketfehler behoben: Das virtuelle Paket `awk` wurde durch den konkreten Provider `mawk` ersetzt.
- Der benötigte Befehl `awk` wird nach der Installation weiterhin geprüft.

## 5.1.1 – 2026-07-23

- Interaktives Deinstallationsmenü wiederhergestellt.
- Sicherheitsbestätigung `ALLES-LOESCHEN` für destruktive Deinstallationen wieder eingeführt.
- Docker-Purge entfernt alle `.list`- und `.sources`-Dateien, die auf `download.docker.com/linux/debian` verweisen.
- Docker-APT-Schlüssel werden erst zusammen mit den zugehörigen Quellen entfernt.
- Direkte Docker-Einträge in `/etc/apt/sources.list` werden gezielt bereinigt.
- Nach `--purge-docker` wird `apt-get update` ausgeführt und geprüft.
- Zusätzliche Docker-/Containerd-Pakete und Laufzeitverzeichnisse werden berücksichtigt.

## 5.1.0 – 2026-07-23

- Installer vollständig in zehn zustandsorientierte Module aufgeteilt.
- Eindeutige Trennung zwischen Laufzeitverzeichnis `/opt/nextcloud-enterprise` und Werkzeugverzeichnis `/opt/nextcloud-enterprise-tools`.
- Entpacktes Installer-Verzeichnis ist kein drittes dauerhaftes Projektverzeichnis mehr.
- Automatische Bereinigung eindeutig erkannter Installer-Verzeichnisse unter `/opt`.
- Persistente Werkzeuge werden erst nach erfolgreicher Gesamtvalidierung installiert beziehungsweise aktualisiert.
- Dokumentation der empfohlenen Entpackung unter `/tmp`.

## 5.0.0 – 2026-07-23

- Zustandsbasierte Nextcloud-Installation.
- Fester Docker-DNS-Alias für ONLYOFFICE.
- Strikte Abschlussvalidierung.
