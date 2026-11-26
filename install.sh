#!/usr/bin/env bash
set -Eeuo pipefail
SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}
TOOLS_DIR=${TOOLS_DIR:-/opt/nextcloud-enterprise-tools}
export SOURCE_DIR PROJECT_DIR TOOLS_DIR
# shellcheck source=lib/common.sh
source "$SOURCE_DIR/lib/common.sh"
acquire_lock

modules=(
  00_prerequisites
  10_docker
  20_network
  30_database
  40_nextcloud
  50_onlyoffice
  60_nginx
  70_security
  80_validation
  90_cleanup
)

for module in "${modules[@]}"; do
  # shellcheck disable=SC1090
  source "$SOURCE_DIR/lib/${module}.sh"
  "phase_${module}"
done
