#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}
TOOLS_DIR=${TOOLS_DIR:-/opt/nextcloud-enterprise-tools}
SOURCE_DIR=${SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
LOG_DIR=${LOG_DIR:-/var/log/nextcloud-enterprise}
mkdir -p "$LOG_DIR"
LOG_FILE=${LOG_FILE:-$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log}
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'rc=$?; printf "\nFEHLER in %s, Zeile %s (Exit %s). Log: %s\n" "${BASH_SOURCE[1]:-$0}" "$LINENO" "$rc" "$LOG_FILE" >&2' ERR
log(){ printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn(){ printf '\nWARNUNG: %s\n' "$*" >&2; }
die(){ echo "FEHLER: $*" >&2; exit 1; }
need_root(){ [[ $EUID -eq 0 ]] || die "Dieses Skript muss als root laufen."; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Befehl fehlt: $1"; }
compose(){ docker compose --project-directory "$PROJECT_DIR" --env-file "$PROJECT_DIR/.env" -f "$PROJECT_DIR/compose.yml" "$@"; }
occ(){ compose exec -T -u www-data nextcloud php /var/www/html/occ "$@"; }
load_env(){ [[ -f "$PROJECT_DIR/.env" ]] || die "$PROJECT_DIR/.env fehlt."; set -a; source "$PROJECT_DIR/.env"; set +a; }
json_installed(){ occ status --output=json 2>/dev/null | jq -e '.installed == true and .maintenance == false' >/dev/null; }
container_running(){ [[ $(docker inspect "$1" --format '{{.State.Status}}' 2>/dev/null || true) == running ]]; }
wait_container_health(){ local c=$1 wanted=${2:-healthy} timeout=${3:-300} elapsed=0 state=""; while (( elapsed < timeout )); do state=$(docker inspect "$c" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true); [[ "$state" == "$wanted" ]] && return 0; sleep 5; elapsed=$((elapsed+5)); done; docker logs --tail 100 "$c" 2>/dev/null || true; die "$c erreichte nicht den Zustand $wanted (letzter Status: ${state:-nicht vorhanden})."; }
wait_http_in_container(){ local service=$1 url=$2 timeout=${3:-180} elapsed=0; while (( elapsed < timeout )); do compose exec -T "$service" curl -fsS --connect-timeout 3 "$url" >/dev/null 2>&1 && return 0; sleep 3; elapsed=$((elapsed+3)); done; die "$service erreicht $url nicht."; }
prompt_default(){ local var=$1 text=$2 def=$3 val; read -r -p "$text [$def]: " val; printf -v "$var" '%s' "${val:-$def}"; }
prompt_secret(){ local var=$1 text=$2 a b; while :; do read -r -s -p "$text: " a; echo; read -r -s -p "Wiederholen: " b; echo; [[ -n $a && $a == "$b" ]] && break; echo "Eingaben stimmen nicht überein."; done; printf -v "$var" '%s' "$a"; }
random_secret(){ openssl rand -base64 48 | tr -d '\n=/+' | cut -c1-48; }
