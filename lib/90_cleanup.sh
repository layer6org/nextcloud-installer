#!/usr/bin/env bash
phase_90_cleanup(){
  log "90 – Persistente Werkzeuge installieren und Installationsreste bereinigen"
  install -d -m 0750 "$TOOLS_DIR/project"
  rsync -a --delete --exclude='.env' --exclude='certs/origin.crt' --exclude='certs/origin.key' \
    "$SOURCE_DIR/" "$TOOLS_DIR/project/"
  chmod 0750 "$TOOLS_DIR/project"/*.sh "$TOOLS_DIR/project"/lib/*.sh

  local s
  for s in install update upgrade uninstall backup restore status doctor repair; do
    cat > "$TOOLS_DIR/$s.sh" <<WRAP
#!/usr/bin/env bash
exec "$TOOLS_DIR/project/$s.sh" "\$@"
WRAP
    chmod 0750 "$TOOLS_DIR/$s.sh"
  done

  cat > "$TOOLS_DIR/version.json" <<JSON
{
  "project": "Nextcloud Enterprise",
  "version": "5.1.2",
  "runtime": "$PROJECT_DIR",
  "tools": "$TOOLS_DIR"
}
JSON
  chmod 0640 "$TOOLS_DIR/version.json"

  # Ein unter /opt entpacktes, eindeutig als Installer benanntes Quellverzeichnis
  # wird nach der Kopie in den persistenten Werkzeugordner entfernt.
  case "$SOURCE_DIR" in
    /opt/nextcloud-enterprise-installer|/opt/nextcloud-enterprise-v*)
      if [[ "$SOURCE_DIR" != "$PROJECT_DIR" && "$SOURCE_DIR" != "$TOOLS_DIR" ]]; then
        log "Temporäres Installationsverzeichnis wird entfernt: $SOURCE_DIR"
        rm -rf --one-file-system "$SOURCE_DIR"
      fi
      ;;
  esac

  log "Installation erfolgreich abgeschlossen"
  echo "Nextcloud:  https://$NEXTCLOUD_DOMAIN"
  echo "ONLYOFFICE: https://$ONLYOFFICE_DOMAIN"
  echo "Laufzeit:   $PROJECT_DIR"
  echo "Werkzeuge:  $TOOLS_DIR"
}
