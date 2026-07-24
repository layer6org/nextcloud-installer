#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root
cd "$PROJECT_DIR"
ADMIN_USER="${1:-admin}"
# Nextcloud bietet derzeit keinen stabilen OCC-Befehl zum Auflisten registrierter Passkeys.
# Deshalb ist eine ausdrückliche Bestätigung nach einem realen Login-Test erforderlich.
printf 'Wurden mindestens zwei Passkeys registriert und beide in privaten Browserfenstern erfolgreich getestet? [ja/NEIN]: '
read -r CONFIRM
[[ "$CONFIRM" == "ja" ]] || { echo "Abgebrochen."; exit 1; }
SECRET_FILE="/root/nextcloud-${ADMIN_USER}-emergency-password.txt"
umask 077
PASSWORD="$(openssl rand -base64 72 | tr -d '\n')"
printf '%s\n' "$PASSWORD" > "$SECRET_FILE"
OC_PASS="$PASSWORD" occ user:resetpassword --password-from-env "$ADMIN_USER" --no-interaction
unset PASSWORD OC_PASS
chmod 600 "$SECRET_FILE"
echo "Adminpasswort wurde auf ein zufälliges Notfallkennwort rotiert."
echo "Einmalig in Keeper übernehmen und anschließend die Datei sicher löschen:"
echo "  $SECRET_FILE"
echo "Danach erneut ausschließlich per Passkey anmelden und testen."
