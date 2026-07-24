#!/usr/bin/env bash
phase_00_prerequisites(){
  log "00 – Systemvoraussetzungen prüfen"
  need_root
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl jq rsync openssl mawk sed grep coreutils
  for c in awk sed grep openssl rsync curl jq; do need "$c"; done
  [[ -r /etc/os-release ]] || die "/etc/os-release fehlt."
  . /etc/os-release
  [[ ${ID:-} == debian ]] || warn "Getestet für Debian; erkannt wurde ${ID:-unbekannt}."
}
