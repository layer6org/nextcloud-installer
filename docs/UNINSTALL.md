# Deinstallation

## Interaktive Deinstallation

Ohne Parameter zeigt der Uninstaller wieder ein Auswahlmenü:

```bash
/opt/nextcloud-enterprise-tools/uninstall.sh
```

Zur Auswahl stehen:

1. Stack und alle Projektdaten löschen; Docker und Werkzeuge behalten.
2. Nur den Stack entfernen; Projektdaten und Werkzeuge behalten.
3. Alles einschließlich Docker löschen; Werkzeuge behalten.
4. Factory Reset einschließlich Docker und Werkzeugen.

Vor einer destruktiven Ausführung muss exakt `ALLES-LOESCHEN` eingegeben werden.

## Nicht-interaktive Optionen

```bash
uninstall.sh --keep-data
uninstall.sh --purge-docker
uninstall.sh --factory-reset
```

Für bewusst automatisierte Abläufe kann die Sicherheitsabfrage ergänzt werden:

```bash
uninstall.sh --purge-docker --yes
```

`--purge-docker` entfernt zusätzlich:

- Docker Engine und Compose Plugin
- Containerd und zugehörige Laufzeitdaten
- `/var/lib/docker`, `/var/lib/containerd` und `/opt/containerd`
- sämtliche `.list`- und `.sources`-Dateien mit `download.docker.com/linux/debian`
- Docker-Schlüssel unter `/etc/apt/keyrings` und `/usr/share/keyrings`

Anschließend wird `apt-get update` ausgeführt, damit keine verwaiste Docker-Paketquelle zurückbleibt.
