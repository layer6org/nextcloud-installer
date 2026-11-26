#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
load_env
ADMIN_USER="${1:-${NEXTCLOUD_ADMIN_USER:-admin}}"
TOTP_GROUP="${TOTP_GROUP:-totp-required}"
PASSKEY_ADMIN_GROUP="${PASSKEY_ADMIN_GROUP:-passkey-admins}"

echo "[1/7] WebAuthn aktivieren"
occ config:system:set auth.webauthn.enabled --type=boolean --value=true
occ config:system:set lost_password_link --value=disabled
occ config:system:set token_auth_enforced --type=boolean --value=true

echo "[2/7] TOTP-App installieren und aktivieren"
occ app:install twofactor_totp 2>/dev/null || true
occ app:enable twofactor_totp

echo "[3/7] Richtliniengruppen anlegen"
occ group:add "$TOTP_GROUP" 2>/dev/null || true
occ group:add "$PASSKEY_ADMIN_GROUP" 2>/dev/null || true
occ group:adduser "$PASSKEY_ADMIN_GROUP" "$ADMIN_USER" 2>/dev/null || true
# Der Admin darf niemals zugleich in der erzwungenen TOTP-Gruppe verbleiben.
occ group:removeuser "$TOTP_GROUP" "$ADMIN_USER" 2>/dev/null || true

echo "[4/7] Gruppenbezogene 2FA-Erzwingung setzen"
occ twofactorauth:enforce --off 2>/dev/null || true
occ twofactorauth:enforce --on --group="$TOTP_GROUP" --exclude="$PASSKEY_ADMIN_GROUP"

echo "[5/7] Sicherheitsstatus prüfen"
occ twofactorauth:state "$ADMIN_USER" || true

echo "[6/7] Admin-Passkey noch NICHT automatisch erzwingen"
cat <<MSG
Der Admin ist jetzt von der klassischen TOTP-Pflicht ausgenommen und WebAuthn ist aktiv.
Melde dich als '$ADMIN_USER' an, registriere mindestens ZWEI Passkeys und teste beide
in einem privaten Browserfenster über „Mit einem Gerät anmelden“.

Erst nach erfolgreichem Test ausführen:
  $TOOLS_DIR/security/seal-admin-password.sh "$ADMIN_USER"
MSG

echo "[7/7] Normale Benutzer der Gruppe '$TOTP_GROUP' hinzufügen"
echo "Beispiel: $TOOLS_DIR/security/require-totp-for-user.sh BENUTZERNAME"
