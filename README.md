# Nextcloud Enterprise Installer

Zustandsorientierte Docker-Compose-Installation für Nextcloud, PostgreSQL, Redis, ONLYOFFICE, NGINX und Portainer auf Debian 13. Die aktuelle Version steht in `version.json`, Änderungen in `CHANGELOG.md`.

## Dauerhafte Verzeichnisse

| Verzeichnis | Inhalt |
|---|---|
| `/opt/nextcloud-enterprise` | Laufzeitkonfiguration: `compose.yml`, `versions.env`, `.env` (Secrets), `certs/`, NGINX/PHP/PostgreSQL/Redis-Konfiguration |
| `/opt/nextcloud-enterprise-tools` | Werkzeuge: Installation, Update, Diagnose, Backup, Restore, Reparatur, Deinstallation, `security/` |
| `/ssd_data/nextcloud-enterprise` | PostgreSQL, Redis, Nextcloud-Webroot (inkl. `config/`, `custom_apps/`), ONLYOFFICE, Portainer |
| `/hdd_data/nextcloud-data` | Nextcloud-Nutzdaten |
| `/hdd_data/nextcloud-backups` | Backups (`BACKUP_ROOT` in `.env`) |

`/ssd_data` und `/hdd_data` müssen eingehängte Datenträger sein; andernfalls bricht der Installer ab (bewusst übersteuerbar mit `NC_ALLOW_NO_MOUNTPOINT=1`).

Das entpackte Quellverzeichnis ist nur ein Installer. Wird es als `/opt/nextcloud-enterprise-installer` oder `/opt/nextcloud-enterprise-v*` ausgeführt, entfernt der letzte Installationsschritt es automatisch.

## Installation

```bash
mkdir -p /tmp/nextcloud-installer
cd /tmp/nextcloud-installer
tar -xzf /pfad/nextcloud-enterprise-installer.tar.gz
cd nextcloud-enterprise-installer
./install.sh
```

Abgefragt werden Domains, Bind-Adressen, die Adresse von `cloudflared` sowie Name und Passwort des Administrators. Das Adminpasswort wird **nicht** gespeichert. Details: [docs/INSTALL.md](docs/INSTALL.md).

## Installationsmodule

| Modul | Aufgabe |
|---|---|
| `lib/00_prerequisites.sh` | Pakete, Mountpoints, Speicher, RAM, freie Ports |
| `lib/10_docker.sh` | Docker Engine und Compose |
| `lib/20_network.sh` | Laufzeitdateien, `.env`, Upgrade-Pfad, NGINX-Konfiguration, Zertifikat |
| `lib/30_database.sh` | PostgreSQL und Redis |
| `lib/40_nextcloud.sh` | Nextcloud-Installation bzw. -Upgrade und Konfiguration |
| `lib/50_onlyoffice.sh` | ONLYOFFICE und Connector |
| `lib/60_nginx.sh` | NGINX und Cron |
| `lib/70_security.sh` | Dateirechte und Sicherheitshinweise |
| `lib/80_validation.sh` | Gesamtprüfung über `doctor.sh` |
| `lib/90_cleanup.sh` | Werkzeuge, systemd-Units, Aufräumen |

`install.sh` ist wiederholbar: Auf einem bestehenden System wird zuerst ein Backup erstellt, danach werden neue Konfiguration und Image-Versionen übernommen.

## Werkzeuge

```bash
/opt/nextcloud-enterprise-tools/status.sh
/opt/nextcloud-enterprise-tools/doctor.sh
/opt/nextcloud-enterprise-tools/repair.sh
/opt/nextcloud-enterprise-tools/update.sh        # upgrade.sh ist ein Alias
/opt/nextcloud-enterprise-tools/backup.sh [ZIEL]
/opt/nextcloud-enterprise-tools/restore.sh [--yes] BACKUPVERZEICHNIS
/opt/nextcloud-enterprise-tools/uninstall.sh
/opt/nextcloud-enterprise-tools/security/*.sh
```

Betrieb, Updates und Backups: [docs/OPERATIONS.md](docs/OPERATIONS.md).
