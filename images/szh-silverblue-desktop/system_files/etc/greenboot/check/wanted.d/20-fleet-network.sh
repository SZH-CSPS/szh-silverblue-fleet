#!/usr/bin/env bash
# =============================================================================
#  Health check greenboot — NON BLOQUANT (dossier wanted.d).
#  Un échec ici est journalisé (MOTD + journalctl) mais NE déclenche PAS de rollback.
#
#  Pour le rendre BLOQUANT (un échec → boot déclaré raté → rollback automatique vers
#  le déploiement précédent), déplace ce script dans /etc/greenboot/check/required.d/.
#  → À ne faire QUE pour des vérifications sûres et déterministes, sous peine d'annuler
#    de bonnes mises à jour sur un faux positif (voir docs/06).
# =============================================================================
set -uo pipefail

if systemctl is-active --quiet NetworkManager.service; then
    echo "greenboot: OK — NetworkManager actif"
    exit 0
else
    echo "greenboot: ATTENTION — NetworkManager inactif"
    exit 1
fi
