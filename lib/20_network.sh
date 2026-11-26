#!/usr/bin/env bash
create_env_file(){
  local f="$PROJECT_DIR/.env" tmp
  prompt_default NEXTCLOUD_DOMAIN "Nextcloud-Domain" "cloud.example.com" valid_domain
  prompt_default ONLYOFFICE_DOMAIN "ONLYOFFICE-Domain" "office.example.com" valid_domain
  [[ $NEXTCLOUD_DOMAIN != "$ONLYOFFICE_DOMAIN" ]] || die "Nextcloud- und ONLYOFFICE-Domain müssen sich unterscheiden."
  prompt_default NGINX_BIND_IP "Bind-IP für NGINX (80/443); 127.0.0.1, wenn cloudflared auf diesem Host läuft" "0.0.0.0" valid_ipv4
  prompt_default REALIP_TRUSTED_CIDRS "Adresse(n)/Netz(e) von cloudflared, durch Leerzeichen getrennt" "172.16.0.0/12" valid_cidr_list
  prompt_default PORTAINER_BIND_IP "Portainer-Bind-IP (LAN-IP für Zugriff aus dem Admin-Netz)" "127.0.0.1" valid_ipv4
  prompt_default NEXTCLOUD_ADMIN_USER "Nextcloud-Administrator" "admin" valid_username
  if ! nc_installed_on_disk; then
    prompt_secret NEXTCLOUD_ADMIN_PASSWORD "Nextcloud-Administratorpasswort"
  fi

  tmp=$(mktemp "$f.XXXXXX"); chmod 0600 "$tmp"
  {
    printf 'TZ=%s\n' "$(env_quote Europe/Berlin)"
    printf 'NEXTCLOUD_DOMAIN=%s\n' "$(env_quote "$NEXTCLOUD_DOMAIN")"
    printf 'ONLYOFFICE_DOMAIN=%s\n' "$(env_quote "$ONLYOFFICE_DOMAIN")"
    printf 'NGINX_BIND_IP=%s\n' "$(env_quote "$NGINX_BIND_IP")"
    printf 'REALIP_TRUSTED_CIDRS=%s\n' "$(env_quote "$REALIP_TRUSTED_CIDRS")"
    printf 'PORTAINER_BIND_IP=%s\n' "$(env_quote "$PORTAINER_BIND_IP")"
    printf 'PORTAINER_PORT=%s\n' "$(env_quote 9443)"
    printf 'NEXTCLOUD_ADMIN_USER=%s\n' "$(env_quote "$NEXTCLOUD_ADMIN_USER")"
    printf 'POSTGRES_DB=%s\n' "$(env_quote nextcloud)"
    printf 'POSTGRES_USER=%s\n' "$(env_quote nextcloud)"
    printf 'POSTGRES_PASSWORD=%s\n' "$(env_quote "$(random_secret)")"
    printf 'REDIS_PASSWORD=%s\n' "$(env_quote "$(random_secret)")"
    printf 'ONLYOFFICE_JWT_SECRET=%s\n' "$(env_quote "$(random_secret)")"
    printf 'TRUSTED_PROXIES=%s\n' "$(env_quote 172.16.0.0/12)"
    printf 'DEFAULT_PHONE_REGION=%s\n' "$(env_quote DE)"
    printf 'UPLOAD_LIMIT=%s\n' "$(env_quote 10G)"
    printf 'PHP_MEMORY_LIMIT=%s\n' "$(env_quote 1024M)"
    printf 'BACKUP_ROOT=%s\n' "$(env_quote /hdd_data/nextcloud-backups)"
    printf 'BACKUP_RETENTION_DAYS=%s\n' "$(env_quote 14)"
  } > "$tmp"
  mv -f "$tmp" "$f"
}

phase_20_network(){
  log "20 – Laufzeitprojekt, Konfiguration und Netzwerke vorbereiten"

  # Bestehende Installation: vor dem Austausch von Images und Konfiguration sichern.
  if nc_installed_on_disk && [[ -f "$PROJECT_DIR/.env" ]] && container_running nextcloud; then
    log "Bestehende Installation erkannt – Sicherung vor der Aktualisierung"
    PROJECT_DIR=$PROJECT_DIR "$SOURCE_DIR/backup.sh"
  fi

  sync_runtime_files
  [[ -f "$PROJECT_DIR/.env" ]] || create_env_file
  load_env

  valid_domain "$NEXTCLOUD_DOMAIN" || die "NEXTCLOUD_DOMAIN in .env ist ungültig."
  valid_domain "$ONLYOFFICE_DOMAIN" || die "ONLYOFFICE_DOMAIN in .env ist ungültig."
  valid_cidr_list "$REALIP_TRUSTED_CIDRS" || die "REALIP_TRUSTED_CIDRS in .env ist ungültig."
  valid_size "$UPLOAD_LIMIT" || die "UPLOAD_LIMIT in .env muss z. B. 10G lauten."
  check_nextcloud_upgrade_path

  install -d -m 0750 \
    "$SSD_ROOT"/{postgres,redis,nextcloud,portainer,onlyoffice/data,onlyoffice/lib} \
    "$NC_DATA_DIR" /hdd_data/onlyoffice-logs "$PROJECT_DIR/certs"
  install -d -m 0700 "$BACKUP_ROOT"

  render_nginx_configs

  if [[ ! -s "$PROJECT_DIR/certs/origin.crt" || ! -s "$PROJECT_DIR/certs/origin.key" ]]; then
    openssl req -x509 -nodes -newkey rsa:3072 -days 825 \
      -keyout "$PROJECT_DIR/certs/origin.key" -out "$PROJECT_DIR/certs/origin.crt" \
      -subj "/CN=$NEXTCLOUD_DOMAIN" \
      -addext "subjectAltName=DNS:$NEXTCLOUD_DOMAIN,DNS:$ONLYOFFICE_DOMAIN"
    chmod 0600 "$PROJECT_DIR/certs/origin.key"
  fi

  compose config -q
  compose pull
  compose up -d postgres redis
}
