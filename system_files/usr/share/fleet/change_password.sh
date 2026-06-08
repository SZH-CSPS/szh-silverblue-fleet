#!/usr/bin/env bash
# change_password.sh — rotation des secrets initiaux (LUKS + mot de passe admin).
# Déposé à la racine du home d'admin au premier boot ; à lancer à la main.
#
#   ./change_password.sh --help
#   ./change_password.sh --luks=MaPhraseLUKS --admin=MonMotDePasse
#
# La logique vit dans l'image (/usr/libexec/fleet-rotate-secrets) → mise à jour avec l'OS.
exec /usr/libexec/fleet-rotate-secrets "$@"
