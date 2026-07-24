#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
cd "$PROJECT_DIR"
ADMIN_USER="${1:-admin}"
echo "Deaktiviere die 2FA-Erzwingung vorübergehend und setze ein neues Adminpasswort."
occ twofactorauth:enforce --off || true
OC_PASS="${OC_PASS:-}"
if [[ -z "$OC_PASS" ]]; then
  read -r -s -p "Neues temporäres Adminpasswort: " OC_PASS; echo
fi
export OC_PASS
occ user:resetpassword --password-from-env "$ADMIN_USER" --no-interaction
unset OC_PASS
echo "Notzugang hergestellt. Nach Reparatur Richtlinie erneut anwenden:"
echo "  $PROJECT_DIR/security/apply-auth-policy.sh '$ADMIN_USER'"
