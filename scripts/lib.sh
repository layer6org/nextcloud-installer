#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
set -a
source "$PROJECT_DIR/versions.env"
[[ -f "$PROJECT_DIR/.env" ]] && source "$PROJECT_DIR/.env"
set +a
compose() { docker compose --env-file "$PROJECT_DIR/.env" -f "$PROJECT_DIR/compose.yml" "$@"; }
log() { printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
require_root() { [[ $EUID -eq 0 ]] || { echo "Als root ausführen." >&2; exit 1; }; }

occ() { compose exec -T -u www-data nextcloud php occ "$@"; }
