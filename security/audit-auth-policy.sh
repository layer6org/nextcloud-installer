#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
cd "$PROJECT_DIR"
ADMIN_USER="${1:-admin}"
echo "=== Apps ==="
occ app:list | grep -E 'twofactor|Enabled:|Disabled:' || true
echo "=== Systemkonfiguration ==="
occ config:system:get auth.webauthn.enabled || true
occ config:system:get token_auth_enforced || true
occ config:system:get lost_password_link || true
echo "=== Gruppen ==="
occ group:list "$ADMIN_USER" || true
echo "=== 2FA-Status Admin ==="
occ twofactorauth:state "$ADMIN_USER" || true
echo "=== Erzwingungsstatus ==="
occ twofactorauth:enforce || true
