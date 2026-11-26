#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_env
echo "Projektversion: $(project_version)"
compose ps -a
printf '\nNextcloud:\n'; occ status --output=json 2>/dev/null | jq . || true
printf '\nONLYOFFICE:\n'; occ onlyoffice:documentserver --check 2>/dev/null || true
printf '\nSpeicher:\n'; df -h / /ssd_data /hdd_data 2>/dev/null || true
printf '\nBackup-Timer:\n'; systemctl list-timers nextcloud-backup.timer --no-pager 2>/dev/null || true
