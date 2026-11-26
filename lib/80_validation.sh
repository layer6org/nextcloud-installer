#!/usr/bin/env bash
phase_80_validation(){
  log "80 – Vollständige Abschlussvalidierung"
  "$SOURCE_DIR/doctor.sh" || die "Abschlussvalidierung fehlgeschlagen."
}
