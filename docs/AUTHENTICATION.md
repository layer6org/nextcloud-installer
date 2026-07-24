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

Der Installer richtet die Apps, Gruppen und Grundkonfiguration ein. Die Passkey-Registrierung selbst erfordert eine interaktive Browser-Sitzung und kann nicht sicher automatisiert werden.

## Benutzer aufnehmen

```bash
/opt/nextcloud-enterprise/security/require-totp-for-user.sh BENUTZERNAME
```

## Admin nach Passkey-Test versiegeln

```bash
/opt/nextcloud-enterprise/security/seal-admin-password.sh ADMINBENUTZER
```

## Notfallzugang

```bash
/opt/nextcloud-enterprise/security/emergency-unlock-admin.sh ADMINBENUTZER
```

Danach die Richtlinie erneut anwenden und Passkeys kontrollieren.
