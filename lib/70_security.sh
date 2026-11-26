#!/usr/bin/env bash
phase_70_security(){
  log "70 – Sicherheitsgrundkonfiguration anwenden"
  chmod 0750 "$PROJECT_DIR" "$PROJECT_DIR/certs"
  chmod 0600 "$PROJECT_DIR/.env" "$PROJECT_DIR/certs/origin.key"
  chmod 0644 "$PROJECT_DIR/certs/origin.crt"
  chmod 0700 "$BACKUP_ROOT"
  chmod 0750 "$LOG_DIR"
  find "$LOG_DIR" -type f -exec chmod 0640 {} +

  if [[ $NGINX_BIND_IP == 0.0.0.0 ]]; then
    warn "NGINX lauscht auf allen Schnittstellen. Docker-Ports umgehen ufw/firewalld-INPUT-Regeln; Zugriff über die DOCKER-USER-Chain einschränken (siehe docs/CLOUDFLARE.md)."
  fi
  log "Hinweis: Authentifizierungsrichtlinie bei Bedarf mit $TOOLS_DIR/security/apply-auth-policy.sh anwenden (siehe docs/AUTHENTICATION.md)."
}
