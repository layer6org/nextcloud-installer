#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR=${PROJECT_DIR:-/opt/nextcloud-enterprise}; export PROJECT_DIR
# shellcheck source=../lib/common.sh
source "$(dirname "$0")/../lib/common.sh"
load_env
USER_ID="${1:?Aufruf: $0 BENUTZERNAME}"
TOTP_GROUP="${TOTP_GROUP:-totp-required}"
PASSKEY_ADMIN_GROUP="${PASSKEY_ADMIN_GROUP:-passkey-admins}"
occ group:add "$TOTP_GROUP" 2>/dev/null || true
if occ group:list "$USER_ID" | grep -Fq "$PASSKEY_ADMIN_GROUP"; then
  echo "Abbruch: $USER_ID gehört zur Passkey-Administratorgruppe." >&2
  exit 1
fi
occ group:adduser "$TOTP_GROUP" "$USER_ID"
echo "TOTP ist für $USER_ID beim nächsten Web-Login verpflichtend."
echo "Zulässig sind RFC-6238-kompatible Apps, z. B. KeePass/KeePassXC, Apple Passwörter, Google Authenticator oder Microsoft Authenticator."
