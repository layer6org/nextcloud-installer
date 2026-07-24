# Changelog

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
