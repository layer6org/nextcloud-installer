#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="/opt/nextcloud-enterprise"
TOOLS_DIR="/opt/nextcloud-enterprise-tools"
KEEP_TOOLS=1
PURGE_DOCKER=0
KEEP_DATA=0
PURGE_BACKUPS=0
BACKUP_ROOT_DEFAULT="/hdd_data/nextcloud-backups"
ASSUME_YES=0
MODE_SELECTED=0

usage() {
  cat <<'USAGE'
Verwendung:
  uninstall.sh                         Interaktives Menü
  uninstall.sh --keep-data             Stack entfernen, Nutzdaten, .env und Zertifikate behalten
  uninstall.sh --delete-data           Stack und Projektdaten löschen, Docker behalten
  uninstall.sh --purge-docker          Stack, Daten und Docker vollständig entfernen
  uninstall.sh --factory-reset         Zusätzlich persistente Werkzeuge entfernen
  uninstall.sh --purge-backups         Zusätzlich alle Backups löschen (sonst bleiben sie erhalten)
  uninstall.sh --yes [OPTION]          Sicherheitsabfrage überspringen

Ohne Option wird interaktiv abgefragt, was entfernt werden soll.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --keep-data)
      KEEP_DATA=1
      MODE_SELECTED=1
      ;;
    --delete-data)
      KEEP_DATA=0
      MODE_SELECTED=1
      ;;
    --purge-docker)
      PURGE_DOCKER=1
      MODE_SELECTED=1
      ;;
    --purge-backups)
      PURGE_BACKUPS=1
      ;;
    --factory-reset)
      PURGE_DOCKER=1
      KEEP_TOOLS=0
      MODE_SELECTED=1
      ;;
    --yes|-y)
      ASSUME_YES=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unbekannte Option: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "FEHLER: root erforderlich" >&2; exit 1; }

exec 9>/run/nextcloud-enterprise.lock
flock -n 9 || { echo "FEHLER: Ein anderer Nextcloud-Enterprise-Vorgang läuft bereits." >&2; exit 1; }

# Backup-Ziel aus .env lesen, ohne die Datei zu sourcen.
BACKUP_ROOT=$(sed -nE "s/^BACKUP_ROOT='?([^']*)'?$/\1/p" "$PROJECT_DIR/.env" 2>/dev/null | tail -n1)
BACKUP_ROOT=${BACKUP_ROOT:-$BACKUP_ROOT_DEFAULT}

interactive_menu() {
  [[ -t 0 ]] || {
    echo "FEHLER: Ohne interaktives Terminal muss eine Option angegeben werden." >&2
    usage >&2
    exit 2
  }

  echo "Nextcloud Enterprise deinstallieren"
  echo
  echo "  1) Stack und alle Projektdaten löschen; Docker und Werkzeuge behalten"
  echo "  2) Nur Stack entfernen; Projektdaten und Werkzeuge behalten"
  echo "  3) Alles löschen, einschließlich Docker; Werkzeuge behalten"
  echo "  4) Factory Reset: Alles einschließlich Docker und Werkzeuge löschen"
  echo "  0) Abbrechen"
  echo

  local choice
  read -r -p "Auswahl [0-4]: " choice
  case "$choice" in
    1) KEEP_DATA=0; PURGE_DOCKER=0; KEEP_TOOLS=1 ;;
    2) KEEP_DATA=1; PURGE_DOCKER=0; KEEP_TOOLS=1 ;;
    3) KEEP_DATA=0; PURGE_DOCKER=1; KEEP_TOOLS=1 ;;
    4) KEEP_DATA=0; PURGE_DOCKER=1; KEEP_TOOLS=0 ;;
    0) echo "Deinstallation abgebrochen."; exit 0 ;;
    *) echo "Ungültige Auswahl." >&2; exit 2 ;;
  esac

  if (( ! KEEP_DATA )) && [[ -d $BACKUP_ROOT ]]; then
    local purge
    read -r -p "Auch alle Backups unter $BACKUP_ROOT löschen? [j/N]: " purge
    if [[ $purge == [jJ] ]]; then PURGE_BACKUPS=1; fi
  fi
}

if (( ! MODE_SELECTED )); then
  interactive_menu
fi

confirm_removal() {
  (( ASSUME_YES )) && return 0
  [[ -t 0 ]] || {
    echo "FEHLER: Bestätigung erforderlich. Nutze --yes nur bei bewusst automatisierter Ausführung." >&2
    exit 2
  }

  echo
  echo "Folgende Aktion wird ausgeführt:"
  echo "  Projektdaten:      $([[ $KEEP_DATA -eq 1 ]] && echo 'BEHALTEN (inkl. .env und Zertifikaten)' || echo 'LÖSCHEN')"
  echo "  Backups:           $([[ $PURGE_BACKUPS -eq 1 ]] && echo "LÖSCHEN ($BACKUP_ROOT)" || echo 'BEHALTEN')"
  echo "  Docker Engine:     $([[ $PURGE_DOCKER -eq 1 ]] && echo 'LÖSCHEN' || echo 'BEHALTEN')"
  echo "  Werkzeugverzeichnis: $([[ $KEEP_TOOLS -eq 1 ]] && echo 'BEHALTEN' || echo 'LÖSCHEN')"
  echo

  local confirmation expected=ALLES-LOESCHEN
  (( KEEP_DATA && ! PURGE_DOCKER && ! PURGE_BACKUPS )) && expected=STACK-ENTFERNEN
  read -r -p "Zum Fortfahren exakt $expected eingeben: " confirmation
  [[ "$confirmation" == "$expected" ]] || {
    echo "Deinstallation abgebrochen."
    exit 0
  }
}

remove_docker_apt_configuration() {
  echo "Docker-APT-Quellen und Schlüssel werden entfernt ..."

  local source_file
  shopt -s nullglob
  for source_file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    if grep -Eqs '(^|[[:space:]])https?://download\.docker\.com/linux/debian([[:space:]/]|$)' "$source_file"; then
      echo "  Entferne $source_file"
      rm -f -- "$source_file"
    fi
  done
  shopt -u nullglob

  # Falls die Docker-Quelle direkt in /etc/apt/sources.list eingetragen wurde,
  # werden ausschließlich die betreffenden Zeilen entfernt.
  if [[ -f /etc/apt/sources.list ]] && grep -Eqs 'download\.docker\.com/linux/debian' /etc/apt/sources.list; then
    cp -a /etc/apt/sources.list /etc/apt/sources.list.pre-nextcloud-docker-removal
    sed -i '\|download\.docker\.com/linux/debian|d' /etc/apt/sources.list
  fi

  rm -f \
    /etc/apt/keyrings/docker.asc \
    /etc/apt/keyrings/docker.gpg \
    /usr/share/keyrings/docker-archive-keyring.gpg \
    /usr/share/keyrings/docker.gpg
}

confirm_removal

echo "Container und Netzwerke werden entfernt ..."
if [[ -f "$PROJECT_DIR/compose.yml" && -f "$PROJECT_DIR/.env" ]] && command -v docker >/dev/null 2>&1; then
  env_files=()
  [[ -f "$PROJECT_DIR/versions.env" ]] && env_files+=(--env-file "$PROJECT_DIR/versions.env")
  env_files+=(--env-file "$PROJECT_DIR/.env")
  docker compose \
    --project-directory "$PROJECT_DIR" \
    "${env_files[@]}" \
    -f "$PROJECT_DIR/compose.yml" \
    down --remove-orphans -v || true
fi

if command -v docker >/dev/null 2>&1; then
  docker rm -f nc-nginx nextcloud nextcloud-cron onlyoffice nc-postgres nc-redis portainer 2>/dev/null || true
  for network in nc_frontend nc_database nc_management; do
    docker network rm "$network" 2>/dev/null || true
  done
fi

if (( ! KEEP_DATA )); then
  echo "Projekt- und Nutzdaten werden entfernt ..."
  rm -rf \
    /ssd_data/nextcloud-enterprise \
    /hdd_data/nextcloud-data \
    /hdd_data/onlyoffice-logs
  rm -rf "$PROJECT_DIR"
else
  # .env (Secrets) und certs/ (Origin-Zertifikat) werden für eine spätere
  # Neuinstallation mit denselben Daten benötigt und bleiben erhalten.
  echo "Projekt- und Nutzdaten, .env und Zertifikate bleiben erhalten."
  if [[ -d $PROJECT_DIR ]]; then
    find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 ! -name .env ! -name certs -exec rm -rf {} +
  fi
fi

if (( PURGE_BACKUPS )); then
  echo "Backups werden entfernt: $BACKUP_ROOT"
  if [[ $BACKUP_ROOT == /*/* ]]; then rm -rf --one-file-system "$BACKUP_ROOT"; fi
fi

systemctl disable --now nextcloud-backup.timer 2>/dev/null || true
rm -f /etc/systemd/system/nextcloud-backup.service /etc/systemd/system/nextcloud-backup.timer
systemctl daemon-reload 2>/dev/null || true

if (( PURGE_DOCKER )); then
  echo "Docker und Containerd werden vollständig entfernt ..."
  systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true

  # Nur tatsächlich installierte Pakete übergeben – ein unbekanntes Paket
  # würde sonst den gesamten Purge abbrechen.
  installed_pkgs=()
  for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
             docker-ce-rootless-extras docker.io containerd runc; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed\|deinstall ok config-files'; then
      installed_pkgs+=("$pkg")
    fi
  done
  if (( ${#installed_pkgs[@]} )); then
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "${installed_pkgs[@]}" \
      || echo "WARNUNG: apt-get purge meldete Fehler für: ${installed_pkgs[*]}" >&2
  fi

  DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null || true

  remove_docker_apt_configuration

  rm -rf \
    /var/lib/docker \
    /var/lib/containerd \
    /etc/docker \
    /etc/containerd \
    /run/docker \
    /run/containerd \
    /opt/containerd

  systemctl daemon-reload 2>/dev/null || true

  echo "APT-Paketlisten werden ohne Docker-Repository aktualisiert ..."
  if ! apt-get update; then
    echo "WARNUNG: apt-get update meldete weiterhin Fehler. Prüfe weitere Fremdquellen unter /etc/apt/sources.list.d/." >&2
  fi
fi

if (( ! KEEP_TOOLS )); then
  rm -rf "$TOOLS_DIR"
fi

echo
echo "Deinstallation abgeschlossen."
echo "Persistente Werkzeuge: $([[ -d "$TOOLS_DIR" ]] && echo erhalten || echo entfernt)"
echo "Projektdaten: $([[ $KEEP_DATA -eq 1 ]] && echo "erhalten (.env und Zertifikate in $PROJECT_DIR)" || echo entfernt)"
echo "Backups: $([[ -d $BACKUP_ROOT ]] && echo "erhalten ($BACKUP_ROOT)" || echo entfernt)"
echo "Docker: $([[ $PURGE_DOCKER -eq 1 ]] && echo entfernt || echo erhalten)"
