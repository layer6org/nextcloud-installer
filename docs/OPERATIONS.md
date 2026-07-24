# Betrieb

- Status: `./scripts/status.sh`
- Backup: `./scripts/backup.sh`
- Update: zuerst `versions.env` kontrolliert anpassen, dann `./scripts/update.sh`
- Restore: `./scripts/restore.sh /hdd_data/nextcloud-backups/<Zeitstempel>`
- Logs: `docker compose logs -f --tail=200 <dienst>`

Backups auf `/hdd_data` liegen auf demselben Server und sind kein vollständiges Offsite-Backup. Die Backup-Verzeichnisse zusätzlich auf ein externes Ziel replizieren.
