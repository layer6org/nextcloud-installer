#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
load_env
ADMIN_USER="${1:-${NEXTCLOUD_ADMIN_USER:-admin}}"
echo "Deaktiviere die 2FA-Erzwingung vorübergehend und setze ein neues Adminpasswort."
occ twofactorauth:enforce --off || true
OC_PASS="${OC_PASS:-}"
if [[ -z "$OC_PASS" ]]; then
  read -r -s -p "Neues temporäres Adminpasswort: " OC_PASS; echo
fi
export OC_PASS
occ_env OC_PASS -- user:resetpassword --password-from-env "$ADMIN_USER" --no-interaction
unset OC_PASS
echo "Notzugang hergestellt. Nach Reparatur Richtlinie erneut anwenden:"
echo "  $TOOLS_DIR/security/apply-auth-policy.sh '$ADMIN_USER'"
