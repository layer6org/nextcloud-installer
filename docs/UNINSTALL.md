# Deinstallation

## Interaktive Deinstallation

```bash
/opt/nextcloud-enterprise-tools/uninstall.sh
```

Zur Auswahl stehen:

1. Stack und alle Projektdaten löschen; Docker und Werkzeuge behalten.
2. Nur den Stack entfernen; Projektdaten, `.env`, Zertifikate und Werkzeuge behalten.
3. Alles einschließlich Docker löschen; Werkzeuge behalten.
4. Factory Reset einschließlich Docker und Werkzeugen.

Bei den Optionen 1, 3 und 4 wird zusätzlich gefragt, ob die Backups gelöscht werden sollen (Standard: behalten).

Vor einer destruktiven Ausführung muss exakt `ALLES-LOESCHEN` eingegeben werden, bei Option 2 `STACK-ENTFERNEN`.

## Nicht-interaktive Optionen

```bash
uninstall.sh --keep-data        # Stack entfernen; Daten, .env und certs/ bleiben
uninstall.sh --delete-data      # Stack und Projektdaten löschen
uninstall.sh --purge-docker     # zusätzlich Docker entfernen
uninstall.sh --factory-reset    # zusätzlich Werkzeuge entfernen
uninstall.sh --purge-backups    # zusätzlich BACKUP_ROOT löschen
```

Für bewusst automatisierte Abläufe kann die Sicherheitsabfrage übersprungen werden:

```bash
uninstall.sh --purge-docker --yes
```

## Nach `--keep-data` neu installieren

`/opt/nextcloud-enterprise/.env` und `certs/` bleiben erhalten. Ein erneutes `install.sh` erkennt die bestehende Nextcloud-Installation anhand von `config.php`, verwendet dieselben Secrets und startet den Stack mit den vorhandenen Daten.

## `--purge-docker`

Entfernt zusätzlich:

- Docker Engine und Compose Plugin (nur tatsächlich installierte Pakete),
- Containerd und zugehörige Laufzeitdaten,
- `/var/lib/docker`, `/var/lib/containerd` und `/opt/containerd` – **inklusive aller anderen Container des Hosts**,
- sämtliche `.list`- und `.sources`-Dateien mit `download.docker.com/linux/debian`,
- Docker-Schlüssel unter `/etc/apt/keyrings` und `/usr/share/keyrings`.

Anschließend wird `apt-get update` ausgeführt, damit keine verwaiste Docker-Paketquelle zurückbleibt. Die systemd-Units für das Backup werden in jedem Modus entfernt.
