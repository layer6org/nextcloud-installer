# Betrieb

Alle Befehle als root; Werkzeuge liegen unter `/opt/nextcloud-enterprise-tools`. Installation, Update, Backup, Restore, Reparatur und Deinstallation sperren sich gegenseitig (`/run/nextcloud-enterprise.lock`). Logs: `/var/log/nextcloud-enterprise/`.

| Aufgabe | Befehl |
|---|---|
| Status | `status.sh` |
| Gesundheitsprüfung | `doctor.sh` |
| Konfiguration erneut anwenden | `repair.sh` |
| Backup | `backup.sh [ZIEL]` |
| Restore | `restore.sh /hdd_data/nextcloud-backups/<Zeitstempel>` |
| Container-Logs | `cd /opt/nextcloud-enterprise && docker compose --env-file versions.env --env-file .env logs -f --tail=200 <dienst>` |

## Updates

- **Neues Installer-Release:** Archiv entpacken und dessen `./install.sh` ausführen. Es sichert zuerst, übernimmt dann neue `versions.env` und Konfiguration und führt das Nextcloud-Upgrade durch. `.env` und `certs/` bleiben unverändert.
- **Nur Image-Versionen ändern:** `/opt/nextcloud-enterprise/versions.env` anpassen, dann `update.sh`.

Nextcloud lässt sich nur um **eine Hauptversion** pro Schritt aktualisieren und nicht zurückstufen; `install.sh` und `update.sh` prüfen das vor dem Start. PostgreSQL-Hauptversionswechsel (z. B. `postgres:16` → `17`) erfordern Dump und Restore und sind nicht automatisiert.

## Backups

`backup.sh` setzt Nextcloud kurz in den Wartungsmodus und schreibt nach `BACKUP_ROOT/JJJJMMTT-HHMMSS/`:

| Datei | Inhalt |
|---|---|
| `database.pgdump` | PostgreSQL (`pg_dump -Fc`) |
| `db-roles.sql` | Datenbankrollen, inkl. des von Nextcloud angelegten DB-Benutzers |
| `project.tgz` | `/opt/nextcloud-enterprise` **inkl. `.env` und Zertifikaten** |
| `nextcloud-app.tgz` | Nextcloud-Webroot inkl. `config/`, `custom_apps/`, `themes/` |
| `nextcloud-data.tgz` | Nutzdaten |
| `onlyoffice.tgz` | ONLYOFFICE-Daten |
| `SHA256SUMS`, `FORMAT`, `version.json` | Prüfsummen und Metadaten |

Backups sind nur für root lesbar (0700), enthalten aber alle Secrets. Backups älter als `BACKUP_RETENTION_DAYS` (Standard 14, `0` = nie löschen) werden nach einem erfolgreichen Lauf entfernt. Jedes Backup ist eine Vollsicherung – Speicherbedarf beachten.

Tägliches Backup um 02:30 Uhr: `systemctl enable --now nextcloud-backup.timer`.

Backups auf `/hdd_data` liegen auf demselben Server und ersetzen **keine Offsite-Sicherung**. `BACKUP_ROOT` regelmäßig verschlüsselt auf ein anderes System übertragen (z. B. restic oder borg).

## Restore

`restore.sh` stoppt die Dienste, ersetzt Konfiguration, Webroot, Nutzdaten, ONLYOFFICE-Daten und Datenbank vollständig und startet danach den Stack (`maintenance:data-fingerprint`, `maintenance:repair`, `doctor.sh`). Die Image-Versionen des Backups bleiben erhalten, damit Datenstand und Nextcloud-Version zusammenpassen.

Unterstützt werden das aktuelle Format sowie Backups der früheren `backup.sh` und `scripts/backup.sh`. Bei Backups der früheren Root-`backup.sh` fehlten `custom_apps`; ONLYOFFICE und TOTP werden dann neu installiert, weitere Apps müssen manuell nachinstalliert werden.

Restore auf einen neuen Host: zuerst `install.sh` ausführen (stellt Docker und Werkzeuge bereit), danach `restore.sh`.
