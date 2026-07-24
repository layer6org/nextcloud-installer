#!/usr/bin/env bash
PROJECT_DIR=/opt/nextcloud-enterprise; export PROJECT_DIR
source "$(dirname "$0")/lib/common.sh"
need_root; load_env
compose ps -a
printf '\nNextcloud:\n'; occ status --output=json 2>/dev/null | jq . || true
printf '\nONLYOFFICE:\n'; occ onlyoffice:documentserver --check 2>/dev/null || true
