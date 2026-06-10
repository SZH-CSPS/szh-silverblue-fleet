# =============================================================================
#  Containerfile — image de flotte « silverblue-x13 » (image mode / bootc).
#
#  Modèle confirmé (coreos/layering-examples, universal-blue) :
#    1. partir d'une base Silverblue,
#    2. COPY des fichiers système (system_files → /) et des scripts de build,
#    3. RUN build.sh : layering RPM + services + commit ostree,
#    4. lint bootc.
#
#  Build local :
#    podman build -t silverblue-x13 .
#  Avec kDrive (motif d'URL %VERSION%) :
#    podman build --build-arg KDRIVE_URL="https://.../kDrive-%VERSION%-amd64.AppImage" \
#                 -t silverblue-x13 .
# =============================================================================

# Base Silverblue. Le tag est piloté par Renovate (voir .github/renovate.json5).
# Vérifier les tags disponibles : skopeo list-tags docker://quay.io/fedora/fedora-silverblue
ARG BASE_IMAGE=quay.io/fedora/fedora-silverblue
ARG FEDORA_VERSION=44
FROM ${BASE_IMAGE}:${FEDORA_VERSION}

# --- kDrive (optionnel) ------------------------------------------------------
# KDRIVE_VERSION : version COMPLÈTE telle qu'écrite dans le nom de l'AppImage Infomaniak
#                  (4 segments, ex. 3.8.2.6 — le 4e est un build interne, ABSENT des tags
#                  GitHub). Mise à jour MANUELLE : Renovate ne peut pas deviner ce build
#                  (voir .github/renovate.json5 et docs/04).
# KDRIVE_URL     : MOTIF d'URL de l'AppImage avec %VERSION% (passé en --build-arg en local,
#                  ou via la variable de dépôt vars.KDRIVE_URL en CI). Vide → kDrive omis.
#   vars.KDRIVE_URL = https://download.storage.infomaniak.com/drive/desktopclient/kDrive-%VERSION%-amd64.AppImage
ARG KDRIVE_VERSION=3.8.2.6
ARG KDRIVE_URL=""

# --- VeraCrypt ---------------------------------------------------------------
# RPM officiel couché au build (absent de Flathub/dépôts Fedora). URL fournie par la
# variable de dépôt vars.VERACRYPT_URL (Settings → Variables), passée en --build-arg via
# .github/workflows/build.yml — comme kDrive. Vide → VeraCrypt OMIS.
#   ex. vars.VERACRYPT_URL = https://launchpad.net/veracrypt/trunk/1.26.24/+download/veracrypt-1.26.24-Fedora-40-x86_64.rpm
# RPM Fedora-40 (seul publié) → résolution des deps à valider sur Fedora 44.
# Voir build_files/install-veracrypt.sh.
ARG VERACRYPT_URL=""

# Fichiers déposés tels quels sur l'image, puis scripts de build.
COPY system_files/ /
COPY build_files/ /tmp/build_files/

# Couche système + services + intégration kDrive + commit ostree (dans build.sh).
RUN KDRIVE_URL="${KDRIVE_URL}" KDRIVE_VERSION="${KDRIVE_VERSION}" \
    VERACRYPT_URL="${VERACRYPT_URL}" \
    bash /tmp/build_files/build.sh

# Vérifie que l'image respecte les invariants bootc (échoue le build si non).
RUN bootc container lint