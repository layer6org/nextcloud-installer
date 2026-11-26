#!/usr/bin/env bash
phase_90_cleanup(){
  log "90 – Persistente Werkzeuge installieren und Installationsreste bereinigen"
  install -d -m 0750 "$TOOLS_DIR" "$TOOLS_DIR/project" "$TOOLS_DIR/security"
  if [[ "$SOURCE_DIR" != "$TOOLS_DIR/project" ]]; then
    rsync -a --delete --exclude='.git/' --exclude='.DS_Store' --exclude='.env' --exclude='certs/' \
      "$SOURCE_DIR/" "$TOOLS_DIR/project/"
  fi
  chmod 0750 "$TOOLS_DIR/project"/*.sh "$TOOLS_DIR/project"/lib/*.sh "$TOOLS_DIR/project"/security/*.sh

  local s
  for s in install update upgrade uninstall backup restore status doctor repair; do
    printf '#!/usr/bin/env bash\nexec "%s/project/%s.sh" "$@"\n' "$TOOLS_DIR" "$s" > "$TOOLS_DIR/$s.sh"
    chmod 0750 "$TOOLS_DIR/$s.sh"
  done
  for s in "$TOOLS_DIR/project"/security/*.sh; do
    s=$(basename "$s")
    printf '#!/usr/bin/env bash\nexec "%s/project/security/%s" "$@"\n' "$TOOLS_DIR" "$s" > "$TOOLS_DIR/security/$s"
    chmod 0750 "$TOOLS_DIR/security/$s"
  done

  jq --arg runtime "$PROJECT_DIR" --arg tools "$TOOLS_DIR" \
    '{project, version, runtime: $runtime, tools: $tools}' "$SOURCE_DIR/version.json" > "$TOOLS_DIR/version.json"
  chmod 0640 "$TOOLS_DIR/version.json"

  # systemd-Units für das tägliche Backup installieren (nicht automatisch aktivieren,
  # da Voll-Backups auf demselben Server viel Speicher belegen).
  local unit
  for unit in nextcloud-backup.service nextcloud-backup.timer; do
    sed "s|__TOOLS_DIR__|$TOOLS_DIR|g" "$SOURCE_DIR/systemd/$unit" > "/etc/systemd/system/$unit"
    chmod 0644 "/etc/systemd/system/$unit"
  done
  systemctl daemon-reload

  # Ein unter /opt entpacktes, eindeutig als Installer benanntes Quellverzeichnis
  # wird nach der Kopie in den persistenten Werkzeugordner entfernt.
  case "$SOURCE_DIR" in
    /opt/nextcloud-enterprise-installer|/opt/nextcloud-enterprise-v*)
      if [[ "$SOURCE_DIR" != "$PROJECT_DIR" && "$SOURCE_DIR" != "$TOOLS_DIR"* ]]; then
        log "Temporäres Installationsverzeichnis wird entfernt: $SOURCE_DIR"
        rm -rf --one-file-system "$SOURCE_DIR"
      fi
      ;;
  esac

  log "Installation erfolgreich abgeschlossen (Version $(project_version "$TOOLS_DIR"))"
  echo "Nextcloud:  https://$NEXTCLOUD_DOMAIN"
  echo "ONLYOFFICE: https://$ONLYOFFICE_DOMAIN"
  echo "Portainer:  https://$PORTAINER_BIND_IP:$PORTAINER_PORT"
  echo "Laufzeit:   $PROJECT_DIR"
  echo "Werkzeuge:  $TOOLS_DIR"
  echo
  echo "Tägliches Backup aktivieren: systemctl enable --now nextcloud-backup.timer"
}
