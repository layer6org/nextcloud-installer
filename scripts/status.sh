#!/usr/bin/env bash
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
source "$(dirname "$0")/lib.sh"
compose ps
printf '\nNextcloud:\n'; compose exec -T -u www-data nextcloud php occ status || true
printf '\nSpeicher:\n'; df -h / /var /ssd_data /hdd_data
