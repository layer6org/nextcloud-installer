#!/usr/bin/env bash
phase_70_security(){
  log "70 – Sicherheitsgrundkonfiguration anwenden"
  chmod 0600 "$PROJECT_DIR/.env" "$PROJECT_DIR/certs/origin.key"
  chmod 0644 "$PROJECT_DIR/certs/origin.crt"
  occ config:system:set overwriteprotocol --value=https
  occ config:system:set default_phone_region --value=DE
  occ config:system:set maintenance_window_start --type=integer --value=1
}
