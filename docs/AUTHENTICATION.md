# Authentifizierungsrichtlinie

## Zielbild

- Administrator: Anmeldung im Web bevorzugt ausschließlich per Passkey/WebAuthn.
- Administrator: kein TOTP und keine Recovery Codes als regulärer Anmeldeweg.
- Normale Benutzer: Benutzername/Passwort plus verpflichtendes TOTP.
- TOTP-Apps: KeePass/KeePassXC, Apple Passwörter, Google Authenticator oder Microsoft Authenticator.
- Desktop-, Mobil- und WebDAV-Clients verwenden gerätespezifische App-Passwörter.

## Technische Grenze

Nextcloud Core kann 2FA für Gruppen erzwingen, aber nicht nativ pro Benutzer den Passwort-Login vollständig abschalten und ausschließlich Passkeys zulassen. Das Projekt nähert die Forderung sicher an:

1. Admin wird der Gruppe `passkey-admins` zugewiesen und von der TOTP-Erzwingung ausgeschlossen.
2. WebAuthn wird aktiviert.
3. Mindestens zwei unabhängige Passkeys werden registriert und getestet.
4. Danach wird das Adminpasswort auf ein langes, zufälliges Notfallkennwort rotiert.
5. Das Kennwort wird ausschließlich in Keeper verwahrt und nicht im täglichen Betrieb verwendet.

## Installation

Die Richtlinie wird **nicht** automatisch vom Installer angewendet, weil sie das Verhalten für alle Benutzer ändert (u. a. kein „Passwort vergessen“-Link, App-Passwörter für alle Clients). Anwenden mit:

```bash
/opt/nextcloud-enterprise-tools/security/apply-auth-policy.sh [ADMINBENUTZER]
```

Die Passkey-Registrierung selbst erfordert eine interaktive Browser-Sitzung und kann nicht sicher automatisiert werden.

Prüfen: `/opt/nextcloud-enterprise-tools/security/audit-auth-policy.sh`

## Benutzer aufnehmen

```bash
/opt/nextcloud-enterprise-tools/security/require-totp-for-user.sh BENUTZERNAME
```

## Admin nach Passkey-Test versiegeln

```bash
/opt/nextcloud-enterprise-tools/security/seal-admin-password.sh ADMINBENUTZER
```

## Notfallzugang

```bash
/opt/nextcloud-enterprise-tools/security/emergency-unlock-admin.sh ADMINBENUTZER
```

Danach die Richtlinie erneut anwenden und Passkeys kontrollieren.
