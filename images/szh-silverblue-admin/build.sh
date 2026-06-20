#!/usr/bin/env bash
# =============================================================================
#  build-sysadmin.sh — couche ADDITIONNELLE du profil sysadmin.
#  Exécuté pendant le build de l'image admin (Containerfile), PAR-DESSUS le desktop.
#
#  Principe de répartition (équivalents de la liste Windows, docs/04) :
#    - RPM (ici)      : CLI système & outils nécessitant un accès matériel/réseau
#                       profond (Wireshark, YubiKey) — petits, stables.
#    - Flatpak        : toutes les applications GRAPHIQUES
#                       → images/szh-silverblue-admin/system_files/usr/share/fleet/flatpaks.d/20-sysadmin.list
#    - distrobox      : chaînes outillées lourdes/changeantes (pipeline.ini, etc.)
#
#  Hors périmètre (pas d'équivalent Linux empaquetable — voir 20-sysadmin.list) :
#    Adobe CC, MS Office (web), PAC/CCA, PowerToys, Everything (→ FSearch),
#    Claude Desktop/Code (installeur par utilisateur), Antidote (RPM Druide, licence
#    par poste), act / mise (non empaquetés Fedora → distrobox ou brew).
#    (Chiffrement amovible : LUKS2 natif + fleet-vault — VeraCrypt retiré.)
# =============================================================================
set -euxo pipefail

### 1. Paquets RPM sysadmin ----------------------------------------------------
#   wireshark        : capture/analyse réseau (capture non-root : ajouter
#                      l'utilisateur au groupe wireshark → usermod -aG wireshark <user>)
#   syncthing        : synchro de fichiers P2P (service utilisateur, UI localhost:8384).
#                      RPM officiel, PAS Flatpak (le bac à sable bride les dossiers à
#                      synchroniser). NB : ykman + Yubico Authenticator sont désormais dans
#                      l'image standard (compat YubiKey pour tous) → retirés d'ici.
#   gh               : GitHub CLI
#   jq / yq          : JSON / YAML en CLI (yq Fedora = wrapper python autour de jq ;
#                      si tu veux le yq Go de mikefarah : brew ou distrobox)
#   ripgrep fzf bat fd-find eza git-delta : CLI dev modernes (équiv. couche Scoop)
#   uv               : gestionnaire Python (empaqueté dans Fedora)
#   p7zip(-plugins)  : 7-Zip CLI
rpm-ostree install \
    wireshark \
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
    syncthing \
    p7zip \
    p7zip-plugins

### 1b. Syncthing en service UTILISATEUR (tous les comptes) --------------------
# UI web sur http://localhost:8384. --global = symlinks dans /etc/systemd/user/ →
# vaut pour tout utilisateur (présent et futur), sans action au premier login.
# (|| true : tolère l'absence de l'unité user selon la version du paquet — à valider au build.)
systemctl --global enable syncthing.service 2>/dev/null || true

### 2. Commit ostree (obligatoire) ---------------------------------------------
rm -rf /var/cache /var/lib/dnf /tmp/build /tmp/common
ostree container commit
