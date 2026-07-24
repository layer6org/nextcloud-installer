# Nextcloud Enterprise 5.1.0

Zustandsorientierte Docker-Compose-Installation für Nextcloud, PostgreSQL, Redis, ONLYOFFICE, NGINX und Portainer auf Debian 13.

## Dauerhafte Verzeichnisse

Nach erfolgreicher Installation werden ausschließlich diese Projektverzeichnisse benötigt:

- `/opt/nextcloud-enterprise` – Laufzeitkonfiguration des Docker-Stacks
- `/opt/nextcloud-enterprise-tools` – persistente Installations-, Update-, Diagnose-, Backup- und Deinstallationswerkzeuge

Das entpackte Quellverzeichnis ist nur ein Installer. Wird es als `/opt/nextcloud-enterprise-installer` oder `/opt/nextcloud-enterprise-v*` ausgeführt, entfernt der letzte Installationsschritt es automatisch. Das heruntergeladene Archiv kann anschließend manuell gelöscht oder außerhalb von `/opt` aufbewahrt werden.

## Installation

Empfohlen:

```bash
mkdir -p /tmp/nextcloud-installer
cd /tmp/nextcloud-installer
tar -xzf /pfad/nextcloud-enterprise-root-latest-v5.1.0.tar.gz
cd nextcloud-enterprise-installer
./install.sh
```

## Installationsmodule

Der Installer führt diese Module der Reihe nach aus:

- `lib/00_prerequisites.sh`
- `lib/10_docker.sh`
- `lib/20_network.sh`
- `lib/30_database.sh`
- `lib/40_nextcloud.sh`
- `lib/50_onlyoffice.sh`
- `lib/60_nginx.sh`
- `lib/70_security.sh`
- `lib/80_validation.sh`
- `lib/90_cleanup.sh`

## Weitere Aufrufe

```bash
/opt/nextcloud-enterprise-tools/status.sh
/opt/nextcloud-enterprise-tools/doctor.sh
/opt/nextcloud-enterprise-tools/repair.sh
/opt/nextcloud-enterprise-tools/update.sh
/opt/nextcloud-enterprise-tools/upgrade.sh
/opt/nextcloud-enterprise-tools/backup.sh
/opt/nextcloud-enterprise-tools/restore.sh
/opt/nextcloud-enterprise-tools/uninstall.sh
```
