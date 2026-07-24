#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib.sh"
require_root

failures=0
warn() { printf 'WARNUNG: %s\n' "$*"; }
fail() { printf 'FEHLER: %s\n' "$*" >&2; failures=$((failures+1)); }
ok() { printf 'OK: %s\n' "$*"; }

[[ -r /etc/os-release ]] || fail '/etc/os-release fehlt.'
if [[ -r /etc/os-release ]]; then
  source /etc/os-release
  [[ ${ID:-} == debian ]] && ok "Debian ${VERSION_ID:-unbekannt}" || fail 'Unterstützt wird ausschließlich Debian.'
fi
[[ $EUID -eq 0 ]] && ok 'Ausführung als root' || fail 'Das Skript muss als root laufen.'
[[ $(uname -m) == x86_64 || $(uname -m) == aarch64 ]] && ok "Architektur $(uname -m)" || warn "Architektur $(uname -m) wurde nicht getestet."

for m in /ssd_data /hdd_data; do
  mountpoint -q "$m" && ok "$m ist eingehängt" || fail "$m ist kein Mountpoint."
done

avail_ssd=$(df -Pm /ssd_data 2>/dev/null | awk 'NR==2 {print $4}')
avail_hdd=$(df -Pm /hdd_data 2>/dev/null | awk 'NR==2 {print $4}')
[[ ${avail_ssd:-0} -ge 30720 ]] && ok 'Mindestens 30 GiB auf /ssd_data frei' || fail 'Auf /ssd_data müssen mindestens 30 GiB frei sein.'
[[ ${avail_hdd:-0} -ge 51200 ]] && ok 'Mindestens 50 GiB auf /hdd_data frei' || fail 'Auf /hdd_data müssen mindestens 50 GiB frei sein.'

mem_kib=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
[[ ${mem_kib:-0} -ge 12000000 ]] && ok 'Mindestens 12 GB RAM vorhanden' || warn 'Weniger als 12 GB RAM; ONLYOFFICE kann unter Last instabil werden.'

for port in 80 443; do
  if ss -H -ltn "sport = :$port" 2>/dev/null | grep -q .; then
    fail "TCP-Port $port ist bereits belegt."
  else
    ok "TCP-Port $port ist frei"
  fi
done

for cmd in apt-get curl openssl mountpoint ss awk grep sed; do
  command -v "$cmd" >/dev/null 2>&1 && ok "$cmd vorhanden" || fail "$cmd fehlt."
done

if (( failures > 0 )); then
  printf '\nVorprüfung mit %d Fehler(n) abgebrochen.\n' "$failures" >&2
  exit 1
fi
printf '\nVorprüfung erfolgreich.\n'
