#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root; load_env
"$(dirname "$0")/backup.sh"
compose pull
compose up -d --remove-orphans
wait_container_health nextcloud healthy 600
wait_container_health onlyoffice healthy 600
occ upgrade
occ maintenance:repair
"$(dirname "$0")/doctor.sh"
