#!/usr/bin/env bash
# =============================================================================
#  lib.sh — helpers de build PARTAGÉS par les images de la flotte.
#  À sourcer depuis un build.sh :  source /tmp/common/build/lib.sh
#
#  Scaffolding (cf. TODO.md) : les build.sh restent AUTONOMES tant que ce fichier
#  n'est pas explicitement câblé. Les helpers ci-dessous sont prêts à être adoptés
#  (évite de casser le build avant un test CI réel).
# =============================================================================

# Journal lisible dans les logs de build.
fleet_log() { printf '\n=== [fleet] %s ===\n' "$*"; }

# Active des units systemd en TOLÉRANT l'absence (un unit peut varier selon la base).
fleet_enable_units() {
    local u
    for u in "$@"; do
        systemctl enable "$u" 2>/dev/null || true
    done
}

# Nettoyage + commit ostree — pour les images rpm-ostree (Silverblue).
# Les images fedora-bootc (banc) n'en ont PAS besoin → ne pas appeler là-bas.
fleet_commit() {
    rm -rf /var/cache /var/lib/dnf /tmp/build /tmp/common
    ostree container commit
}
