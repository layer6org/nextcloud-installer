#!/usr/bin/env bash
phase_00_prerequisites(){
  log "00 – Systemvoraussetzungen prüfen"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl jq rsync openssl mawk sed grep coreutils \
    iproute2 util-linux tar gzip
  local c
  for c in awk sed grep openssl rsync curl jq ss mountpoint flock tar gzip; do need "$c"; done

  [[ -r /etc/os-release ]] || die "/etc/os-release fehlt."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ ${ID:-} == debian ]] || warn "Getestet für Debian; erkannt wurde ${ID:-unbekannt}."
  case $(uname -m) in x86_64|aarch64) ;; *) warn "Architektur $(uname -m) wurde nicht getestet." ;; esac

  # Ohne eingehängte Datenträger landen alle Daten unbemerkt auf dem Root-Dateisystem.
  local m
  for m in /ssd_data /hdd_data; do
    if ! mountpoint -q "$m"; then
      [[ ${NC_ALLOW_NO_MOUNTPOINT:-0} == 1 ]] \
        && warn "$m ist kein Mountpoint (NC_ALLOW_NO_MOUNTPOINT=1 gesetzt)." \
        || die "$m ist kein Mountpoint. Datenträger einhängen oder bewusst NC_ALLOW_NO_MOUNTPOINT=1 setzen."
    fi
  done

  local avail
  avail=$(df -Pm /ssd_data 2>/dev/null | awk 'NR==2 {print $4}')
  (( ${avail:-0} >= 30720 )) || warn "Auf /ssd_data sind weniger als 30 GiB frei."
  avail=$(df -Pm /hdd_data 2>/dev/null | awk 'NR==2 {print $4}')
  (( ${avail:-0} >= 51200 )) || warn "Auf /hdd_data sind weniger als 50 GiB frei."
  local mem_kib
  mem_kib=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  (( ${mem_kib:-0} >= 12000000 )) || warn "Weniger als 12 GB RAM; ONLYOFFICE und PostgreSQL (shared_buffers=2GB) können unter Last instabil werden."

  # Ports nur bei Neuinstallation prüfen; bei bestehendem Stack belegt nc-nginx sie selbst.
  if ! docker inspect nc-nginx >/dev/null 2>&1; then
    local port
    for port in 80 443; do
      ! ss -H -ltn "sport = :$port" 2>/dev/null | grep -q . || die "TCP-Port $port ist bereits belegt."
    done
  fi
}
