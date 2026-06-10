#!/usr/bin/env bash
# =============================================================================
#  install-veracrypt.sh — couche le RPM OFFICIEL de VeraCrypt dans l'image.
#  Appelé par build.sh PENDANT le build. VeraCrypt n'est PAS sur Flathub ni dans
#  les dépôts Fedora → on installe le RPM publié par le projet (signé PGP).
#
#  URL fournie par vars.VERACRYPT_URL (Containerfile → build.yml). Vide → VeraCrypt OMIS,
#  sans rien casser (comme kDrive).
#
#  ⚠️ IMPORTANT : VeraCrypt ne publie qu'un RPM « Fedora-40 » (dernière version
#  1.26.24). La base de cette flotte est Fedora 44 : la résolution des dépendances
#  (wxGTK, fuse-libs, etc.) par rpm-ostree DOIT être validée sur un build de test. Si elle
#  échoue, options : utiliser le RPM « console » (moins de deps), un COPR, ou
#  construire depuis les sources. Mettre la variable VERACRYPT_URL vide pour désactiver.
# =============================================================================
set -euo pipefail

: "${VERACRYPT_URL:=}"

if [ -z "${VERACRYPT_URL}" ]; then
    echo "VeraCrypt : VERACRYPT_URL vide → intégration ignorée."
    exit 0
fi

echo "VeraCrypt : téléchargement de ${VERACRYPT_URL}"
workdir="$(mktemp -d)"
rpm="${workdir}/veracrypt.rpm"
curl -fSL --retry 3 -o "${rpm}" "${VERACRYPT_URL}"

# Couche le RPM local (rpm-ostree résout les dépendances depuis les dépôts Fedora).
rpm-ostree install "${rpm}"

rm -rf "${workdir}"
echo "VeraCrypt intégré à l'image."
