#!/usr/bin/env bash
# =============================================================================
#  build-sysadmin.sh — couche ADDITIONNELLE du profil sysadmin.
#  Exécuté pendant le build de Containerfile.sysadmin, PAR-DESSUS l'image standard.
#
#  Principe de répartition (équivalents de la liste Windows, docs/04) :
#    - RPM (ici)      : CLI système & outils nécessitant un accès matériel/réseau
#                       profond (Wireshark, YubiKey) — petits, stables.
#    - Flatpak        : toutes les applications GRAPHIQUES
#                       → system_files_sysadmin/usr/share/fleet/flatpaks.d/20-sysadmin.list
#    - distrobox      : chaînes outillées lourdes/changeantes (pipeline.ini, etc.)
#
#  Hors périmètre (pas d'équivalent Linux empaquetable — voir 20-sysadmin.list) :
#    Adobe CC, MS Office (web), PAC/CCA, PowerToys, Everything (→ FSearch),
#    Claude Desktop/Code (installeur par utilisateur), VeraCrypt (RPM upstream,
#    install manuelle documentée), Antidote (RPM Druide, licence par poste),
#    act / mise (non empaquetés Fedora → distrobox ou brew).
# =============================================================================
set -euxo pipefail

### 1. Paquets RPM sysadmin ----------------------------------------------------
#   wireshark        : capture/analyse réseau (capture non-root : ajouter
#                      l'utilisateur au groupe wireshark → usermod -aG wireshark <user>)
#   yubikey-manager  : ykman CLI (l'app graphique Yubico Authenticator est en Flatpak)
#   gh               : GitHub CLI
#   jq / yq          : JSON / YAML en CLI (yq Fedora = wrapper python autour de jq ;
#                      si tu veux le yq Go de mikefarah : brew ou distrobox)
#   ripgrep fzf bat fd-find eza git-delta : CLI dev modernes (équiv. couche Scoop)
#   uv               : gestionnaire Python (empaqueté dans Fedora)
#   p7zip(-plugins)  : 7-Zip CLI
rpm-ostree install \
    wireshark \
    yubikey-manager \
    gh \
    jq \
    yq \
    ripgrep \
    fzf \
    bat \
    fd-find \
    eza \
    git-delta \
    uv \
    p7zip \
    p7zip-plugins

### 2. Commit ostree (obligatoire) ---------------------------------------------
rm -rf /var/cache /var/lib/dnf /tmp/build_files
ostree container commit
