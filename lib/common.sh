#!/usr/bin/env bash
# Gemeinsame Funktionen für Installer und persistente Werkzeuge.
set -Eeuo pipefail
umask 027

[[ $EUID -eq 0 ]] || { echo "FEHLER: Dieses Skript muss als root laufen." >&2; exit 1; }

PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}
TOOLS_DIR=${TOOLS_DIR:-/opt/nextcloud-enterprise-tools}
SOURCE_DIR=${SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
SSD_ROOT=${SSD_ROOT:-/ssd_data/nextcloud-enterprise}
NC_APP_DIR=${NC_APP_DIR:-$SSD_ROOT/nextcloud}
NC_DATA_DIR=${NC_DATA_DIR:-/hdd_data/nextcloud-data}
NC_CONFIG_FILE=${NC_CONFIG_FILE:-$NC_APP_DIR/config/config.php}
LOCK_FILE=${LOCK_FILE:-/run/nextcloud-enterprise.lock}
LOG_DIR=${LOG_DIR:-/var/log/nextcloud-enterprise}
export PROJECT_DIR TOOLS_DIR SOURCE_DIR

install -d -m 0750 "$LOG_DIR"
LOG_FILE=${LOG_FILE:-$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log}
: > "$LOG_FILE"; chmod 0640 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'rc=$?; printf "\nFEHLER in %s:%s (%s), Exit %s. Log: %s\n" "${BASH_SOURCE[0]}" "$LINENO" "${FUNCNAME[0]:-main}" "$rc" "$LOG_FILE" >&2' ERR

log(){ printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn(){ printf '\nWARNUNG: %s\n' "$*" >&2; }
die(){ echo "FEHLER: $*" >&2; exit 1; }
need_root(){ [[ $EUID -eq 0 ]] || die "Dieses Skript muss als root laufen."; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Befehl fehlt: $1"; }

# Verhindert parallele Läufe von Installation, Update, Backup, Restore usw.
# Kindprozesse (z. B. backup.sh aus update.sh) erben Sperre und Dateideskriptor.
acquire_lock(){
  [[ ${NC_LOCK_HELD:-0} == 1 ]] && return 0
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "Ein anderer Nextcloud-Enterprise-Vorgang läuft bereits ($LOCK_FILE)."
  export NC_LOCK_HELD=1
}

# Image-Versionen stehen ausschließlich in versions.env, Secrets und Einstellungen in .env.
# Spätere --env-file-Angaben überschreiben frühere.
compose(){
  docker compose --project-directory "$PROJECT_DIR" \
    --env-file "$PROJECT_DIR/versions.env" --env-file "$PROJECT_DIR/.env" \
    -f "$PROJECT_DIR/compose.yml" "$@"
}
occ(){ compose exec -T -u www-data nextcloud php /var/www/html/occ "$@"; }
# occ mit Umgebungsvariablen aus der Host-Umgebung (z. B. OC_PASS), ohne sie in der Befehlszeile zu zeigen.
# compose exec reicht Host-Variablen nicht weiter, daher docker exec -e NAME.
occ_env(){ local -a envs=(); while [[ $1 != -- ]]; do envs+=(-e "$1"); shift; done; shift; docker exec -i -u www-data "${envs[@]}" nextcloud php /var/www/html/occ "$@"; }

# ---------------------------------------------------------------- .env

env_quote(){ printf "'%s'" "${1//\'/\'\\\'\'}"; }
env_set(){
  # env_set DATEI SCHLÜSSEL WERT – ersetzt oder ergänzt eine Zeile
  local file=$1 key=$2 value=$3 tmp
  tmp=$(mktemp "$file.XXXXXX")
  grep -v "^${key}=" "$file" > "$tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$(env_quote "$value")" >> "$tmp"
  chmod 0600 "$tmp"; mv -f "$tmp" "$file"
}
env_has(){ grep -q "^$2=" "$1" 2>/dev/null; }

# Bringt eine .env älterer Versionen auf den aktuellen Stand, ohne sie zu sourcen.
migrate_env(){
  local f="$PROJECT_DIR/.env"
  [[ -f $f ]] || return 0
  if grep -qE '^(NEXTCLOUD|POSTGRES|REDIS|ONLYOFFICE|NGINX|PORTAINER)_IMAGE=|^PROJECT_REVISION=' "$f"; then
    warn "Image-Versionen aus .env entfernt; maßgeblich ist jetzt $PROJECT_DIR/versions.env."
    sed -i -E '/^(NEXTCLOUD|POSTGRES|REDIS|ONLYOFFICE|NGINX|PORTAINER)_IMAGE=/d; /^PROJECT_REVISION=/d' "$f"
  fi
  if grep -q '^NEXTCLOUD_ADMIN_PASSWORD=' "$f"; then
    warn "Klartext-Adminpasswort aus .env entfernt."
    sed -i '/^NEXTCLOUD_ADMIN_PASSWORD=/d' "$f"
  fi
  sed -i '/^OVERWRITE_PROTOCOL=/d' "$f"
  # Neue Schlüssel mit rückwärtskompatiblen Vorgaben ergänzen.
  env_has "$f" NGINX_BIND_IP || env_set "$f" NGINX_BIND_IP 0.0.0.0
  if ! env_has "$f" REALIP_TRUSTED_CIDRS; then
    env_set "$f" REALIP_TRUSTED_CIDRS "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
    warn "REALIP_TRUSTED_CIDRS vertraut allen privaten Netzen. Für mehr Sicherheit in .env auf die IP von cloudflared einschränken und repair.sh ausführen."
  fi
  env_has "$f" BACKUP_ROOT || env_set "$f" BACKUP_ROOT /hdd_data/nextcloud-backups
  env_has "$f" BACKUP_RETENTION_DAYS || env_set "$f" BACKUP_RETENTION_DAYS 14
  chmod 0600 "$f"
}

load_env(){
  [[ -f "$PROJECT_DIR/.env" ]] || die "$PROJECT_DIR/.env fehlt."
  [[ -f "$PROJECT_DIR/versions.env" ]] || die "$PROJECT_DIR/versions.env fehlt."
  migrate_env
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/versions.env"
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/.env"
  set +a
  BACKUP_ROOT=${BACKUP_ROOT:-/hdd_data/nextcloud-backups}
  BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-14}
}

# ---------------------------------------------------------- Eingaben

valid_domain(){ [[ $1 =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]; }
valid_ipv4(){
  local IFS=. o; local -a p
  [[ $1 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  read -r -a p <<<"$1"; for o in "${p[@]}"; do (( 10#$o <= 255 )) || return 1; done
}
valid_cidr_list(){
  local item
  [[ -n $1 ]] || return 1
  for item in $1; do
    [[ $item == */* ]] || { valid_ipv4 "$item" || return 1; continue; }
    valid_ipv4 "${item%/*}" && [[ ${item#*/} =~ ^([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  done
}
valid_username(){ [[ $1 =~ ^[A-Za-z0-9._@-]{1,64}$ ]]; }
valid_size(){ [[ $1 =~ ^[0-9]+[KMG]$ ]]; }

prompt_default(){
  # prompt_default VARIABLE TEXT VORGABE [PRÜFFUNKTION]
  local var=$1 text=$2 def=$3 check=${4:-} val
  while :; do
    read -r -p "$text [$def]: " val
    val=${val:-$def}
    if [[ -z $check ]] || "$check" "$val"; then break; fi
    echo "Ungültige Eingabe: $val"
  done
  printf -v "$var" '%s' "$val"
}
prompt_secret(){
  local var=$1 text=$2 a b
  while :; do
    read -r -s -p "$text: " a; echo
    read -r -s -p "Wiederholen: " b; echo
    if [[ ${#a} -lt 12 ]]; then echo "Mindestens 12 Zeichen."; continue; fi
    [[ $a == "$b" ]] && break
    echo "Eingaben stimmen nicht überein."
  done
  printf -v "$var" '%s' "$a"
}
random_secret(){ openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | cut -c1-48; }

# ------------------------------------------------------- Container

container_running(){ [[ $(docker inspect "$1" --format '{{.State.Status}}' 2>/dev/null || true) == running ]]; }
wait_container_health(){
  local c=$1 wanted=${2:-healthy} timeout=${3:-300} elapsed=0 state=""
  while (( elapsed < timeout )); do
    state=$(docker inspect "$c" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)
    [[ "$state" == "$wanted" ]] && return 0
    case $(docker inspect "$c" --format '{{.State.Status}}' 2>/dev/null || true) in
      exited|dead) break ;;
    esac
    sleep 5; elapsed=$((elapsed+5))
  done
  docker logs --tail 100 "$c" 2>/dev/null || true
  die "$c erreichte nicht den Zustand $wanted (letzter Status: ${state:-nicht vorhanden})."
}
wait_http_in_container(){
  local service=$1 url=$2 timeout=${3:-180} elapsed=0
  while (( elapsed < timeout )); do
    compose exec -T "$service" curl -fsS --connect-timeout 3 "$url" >/dev/null 2>&1 && return 0
    sleep 3; elapsed=$((elapsed+3))
  done
  die "$service erreicht $url nicht."
}

# ------------------------------------------------------- Nextcloud

# Installationszustand direkt aus config.php – funktioniert auch ohne laufenden Container.
nc_installed_on_disk(){ [[ -f $NC_CONFIG_FILE ]] && grep -Eq "'installed'[[:space:]]*=>[[:space:]]*true" "$NC_CONFIG_FILE"; }
nc_disk_version(){ [[ -f $NC_CONFIG_FILE ]] && sed -nE "s/^[[:space:]]*'version'[[:space:]]*=>[[:space:]]*'([0-9.]+)'.*/\1/p" "$NC_CONFIG_FILE" | head -n1; }
json_installed(){ occ status --output=json 2>/dev/null | jq -e '.installed == true and .maintenance == false' >/dev/null; }
db_table_count(){
  compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
    "select count(*) from pg_tables where schemaname='public';" | tr -d '[:space:]'
}

# Nextcloud unterstützt nur Upgrades um höchstens eine Hauptversion und keine Downgrades.
check_nextcloud_upgrade_path(){
  local current target cur_major tgt_major
  current=$(nc_disk_version || true)
  [[ -n $current ]] || return 0
  target=${NEXTCLOUD_IMAGE##*:}; target=${target%%-*}
  [[ $target =~ ^[0-9]+ ]] || { warn "Zielversion aus $NEXTCLOUD_IMAGE nicht ermittelbar; Upgrade-Pfad ungeprüft."; return 0; }
  cur_major=${current%%.*}; tgt_major=${target%%.*}
  (( tgt_major >= cur_major )) || die "Downgrade von Nextcloud $current auf $target wird nicht unterstützt."
  (( tgt_major <= cur_major + 1 )) || die "Nextcloud $current → $target überspringt Hauptversionen. Zuerst auf ${cur_major}+1 aktualisieren (NEXTCLOUD_IMAGE in versions.env)."
}

# Admin-Passwort wird nicht gespeichert; es wird nur für eine Neuinstallation abgefragt.
ensure_admin_password(){
  [[ -n ${NEXTCLOUD_ADMIN_PASSWORD:-} ]] && return 0
  [[ -t 0 ]] || die "Für die Neuinstallation wird NEXTCLOUD_ADMIN_PASSWORD benötigt (interaktiv oder als Umgebungsvariable)."
  prompt_secret NEXTCLOUD_ADMIN_PASSWORD "Nextcloud-Administratorpasswort"
}

nc_maintenance_install(){
  ensure_admin_password
  compose exec -T nextcloud rm -f /var/www/html/config/autoconfig.php
  # Passwörter nicht über die docker-Befehlszeile übergeben (-e NAME ohne Wert = aus Umgebung).
  NC_ADMIN_PASS=$NEXTCLOUD_ADMIN_PASSWORD docker exec -i -u www-data -e NC_ADMIN_PASS nextcloud sh -c '
    exec php /var/www/html/occ maintenance:install \
      --database=pgsql --database-host=postgres \
      --database-name="$POSTGRES_DB" --database-user="$POSTGRES_USER" \
      --database-pass="$POSTGRES_PASSWORD" \
      --admin-user="$1" --admin-pass="$NC_ADMIN_PASS" \
      --data-dir=/var/www/html/data' sh "$NEXTCLOUD_ADMIN_USER"
  unset NEXTCLOUD_ADMIN_PASSWORD
}

configure_nextcloud(){
  occ background:cron
  occ config:system:set trusted_domains 0 --value="$NEXTCLOUD_DOMAIN"
  occ config:system:set trusted_domains 1 --value=nextcloud
  occ config:system:set overwritehost --value="$NEXTCLOUD_DOMAIN"
  occ config:system:set overwriteprotocol --value=https
  occ config:system:set overwrite.cli.url --value="https://$NEXTCLOUD_DOMAIN"
  occ config:system:set allow_local_remote_servers --type=boolean --value=true
  occ config:system:set trusted_proxies 0 --value="$TRUSTED_PROXIES"
  occ config:system:set default_phone_region --value="${DEFAULT_PHONE_REGION:-DE}"
  occ config:system:set maintenance_window_start --type=integer --value=1
  occ config:system:set redis host --value=redis
  occ config:system:set redis password --value="$REDIS_PASSWORD"
  occ config:system:set redis port --type=integer --value=6379
  occ config:system:set memcache.local --value='\OC\Memcache\APCu'
  occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
  occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
}

configure_onlyoffice(){
  occ app:install onlyoffice >/dev/null 2>&1 || true
  occ app:enable onlyoffice
  occ config:app:set onlyoffice DocumentServerUrl --value="https://$ONLYOFFICE_DOMAIN/"
  occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
  occ config:app:set onlyoffice StorageUrl --value="http://nextcloud/"
  occ config:app:set onlyoffice jwt_secret --value="$ONLYOFFICE_JWT_SECRET"
  occ config:app:set onlyoffice jwt_header --value=AuthorizationJwt
  occ config:app:delete onlyoffice settings_error >/dev/null 2>&1 || true
}

# Nacharbeiten, die Nextcloud nach Installation und Upgrade empfiehlt.
nc_post_upgrade(){
  occ db:add-missing-indices || warn "db:add-missing-indices fehlgeschlagen."
  occ db:add-missing-columns || warn "db:add-missing-columns fehlgeschlagen."
  occ db:add-missing-primary-keys || warn "db:add-missing-primary-keys fehlgeschlagen."
  occ maintenance:repair --include-expensive || warn "maintenance:repair fehlgeschlagen."
}

# ------------------------------------------------------- NGINX

render_nginx_configs(){
  local d="$PROJECT_DIR/nginx" realip="" cidr
  for cidr in $REALIP_TRUSTED_CIDRS; do realip+="set_real_ip_from ${cidr};"$'\n'; done
  sed -e "s|__NEXTCLOUD_DOMAIN__|$NEXTCLOUD_DOMAIN|g" -e "s|__UPLOAD_LIMIT__|$UPLOAD_LIMIT|g" \
    "$d/conf.d/nextcloud.conf.template" > "$d/conf.d/nextcloud.conf"
  sed -e "s|__NEXTCLOUD_DOMAIN__|$NEXTCLOUD_DOMAIN|g" -e "s|__ONLYOFFICE_DOMAIN__|$ONLYOFFICE_DOMAIN|g" \
    -e "s|__UPLOAD_LIMIT__|$UPLOAD_LIMIT|g" \
    "$d/conf.d/onlyoffice.conf.template" > "$d/conf.d/onlyoffice.conf"
  awk -v r="$realip" '{ if ($0 == "__SET_REAL_IP_FROM__") printf "%s", r; else print }' \
    "$d/snippets/cloudflare-realip.conf.template" > "$d/snippets/cloudflare-realip.conf"
}

# Kopiert ausschließlich Laufzeitdateien nach PROJECT_DIR; .env und certs/ bleiben unangetastet.
sync_runtime_files(){
  install -d -m 0750 "$PROJECT_DIR"
  rsync -a --delete --delete-excluded \
    --filter='P /.env' --filter='P /certs/***' \
    --include='/compose.yml' --include='/versions.env' --include='/version.json' \
    --include='/nginx/***' --include='/php/***' --include='/postgres/***' --include='/redis/***' \
    --exclude='*' \
    "$SOURCE_DIR/" "$PROJECT_DIR/"
}

project_version(){ jq -r .version "${1:-$PROJECT_DIR}/version.json" 2>/dev/null || echo unbekannt; }
