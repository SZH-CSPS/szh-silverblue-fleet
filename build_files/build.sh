#!/usr/bin/env bash
# =============================================================================
#  build.sh — couche système de la flotte X13. Exécuté PENDANT le build d'image.
#  Idiome ostree confirmé via coreos/layering-examples :
#      rpm-ostree install … && ostree container commit
# =============================================================================
set -euxo pipefail

### 1. Paquets système (couche RPM) -------------------------------------------
# On ne couche QUE ce qui n'est pas déjà fourni par la base Silverblue :
#   distrobox                          : conteneurs dev/pipeline (WeasyPrint + Pandoc)
#   greenboot (+default-health-checks) : auto-rollback si un boot post-MAJ échoue
#   gnome-shell-extension-appindicator : zone de notification GNOME (tray kDrive)
#   tpm2-tools                         : diagnostic TPM pour le chiffrement LUKS
#
# Gestion d'énergie : on GARDE le défaut Fedora (tuned + tuned-ppd, déjà dans la base et
# activé). Le sélecteur de profil d'énergie GNOME fonctionne nativement. Pas de TLP.
#
# NE PAS coucher git ni python3 (déjà dans la base → rpm-ostree casse sur « already provided »).
# fwupd est en général DÉJÀ dans la base : on ne le couche pas (vérifie : rpm -q fwupd).
rpm-ostree install \
    distrobox \
    greenboot \
    greenboot-default-health-checks \
    gnome-shell-extension-appindicator \
    tpm2-tools

# zenity : requis par l'assistant TPM+PIN du premier login (fleet-tpm-pin-setup).
# Installation CONDITIONNELLE : déjà présent dans certaines bases GNOME → un
# rpm-ostree install inconditionnel casserait sur « already provided ».
rpm -q zenity >/dev/null 2>&1 || rpm-ostree install zenity

### 2. Services systemd -------------------------------------------------------
# Gestion d'énergie = défaut Fedora : tuned + tuned-ppd (sélecteur de profil GNOME natif).
# tuned est activé par défaut dans la base depuis F41 ; on l'assure par sûreté.
systemctl enable tuned.service 2>/dev/null || true

# Installe/synchronise les Flatpaks de la flotte : au boot + chaque jour (timer).
systemctl enable fleet-flatpak-setup.service
systemctl enable fleet-flatpak-setup.timer

# Force le changement du mot de passe initial de szh au premier login (docs).
systemctl enable fleet-force-passwd-change.service

# Enrôlement TPM2+PIN du LUKS : proposé en GRAPHIQUE au premier login de session
# (autostart fleet-tpm-pin-setup + helper polkit). Parcours flotte : l'admin lance
# « sudo fleet-provision » après l'installation (phrase de secours + clé temporaire)
# → l'utilisateur n'a plus qu'à choisir son PIN au premier login.
# CLI admin de dépannage : sudo fleet-tpm-enroll (docs/06).

### 2a. Mises à jour automatiques de l'OS (rpm-ostree → bootc) -----------------
# L'image est reconstruite chaque nuit (CI) avec les correctifs Fedora ; le démon
# rpm-ostree les TÉLÉCHARGE et les PRÉPARE automatiquement sur les postes
# (AutomaticUpdatePolicy=stage dans /etc/rpm-ostree.conf, déposé via system_files).
# Application au redémarrage suivant, sous protection greenboot (rollback auto).
systemctl enable rpm-ostreed-automatic.timer

# sshd : pas de service SSH entrant sur les postes de la flotte (défaut Fedora
# Workstation = désactivé ; on l'assure explicitement — durcissement docs/06).
systemctl disable sshd.service 2>/dev/null || true

### 2b. greenboot (auto-rollback santé) --------------------------------------
# Active la chaîne greenboot. Boucle + garde : un unit absent selon la version ne doit
# pas interrompre le build. Les checks vivent dans /etc/greenboot/check/. Détails : docs/06.
for u in greenboot-task-runner greenboot-healthcheck greenboot-status \
         greenboot-loading-message greenboot-grub2-set-counter \
         greenboot-grub2-set-success greenboot-rpm-ostree-grub2-check-fallback \
         redboot-auto-reboot redboot-task-runner ; do
    systemctl enable "$u" 2>/dev/null || true
done

### 2c. Mises à jour firmware (fwupd / LVFS) ----------------------------------
# fwupd est supposé présent dans la base ; on active le rafraîchissement des métadonnées
# LVFS. L'APPLICATION des MAJ firmware reste manuelle/maîtrisée (docs/06).
systemctl enable fwupd-refresh.timer 2>/dev/null || true

### 2d. Défauts GNOME (dconf) -------------------------------------------------
# Compile la base dconf système (profil + clés + locks déposés via system_files) :
# extension AppIndicator par défaut (tray kDrive) + verrouillage d'écran automatique
# IMPOSÉ (clés verrouillées dans local.d/locks/00-fleet-locks). Détails : docs/04.
dconf update || true

### 2e. Splash de boot --------------------------------------------------------
# Pas de thème Plymouth personnalisé : on garde le splash Fedora par défaut
# (fiable, déjà dans l'initramfs — pas de régénération risquée au build).
# Les kargs « rhgb quiet » (usr/lib/bootc/kargs.d/10-fleet.toml) garantissent le
# splash graphique, y compris le prompt LUKS/PIN graphique au boot.

### 3. Permissions ------------------------------------------------------------
chmod +x /usr/bin/fleet-provision
chmod +x /usr/libexec/fleet-flatpak-sync
chmod +x /usr/libexec/fleet-tpm-enroll
chmod +x /usr/libexec/fleet-tpm-enroll-helper
chmod +x /usr/libexec/fleet-tpm-pin-setup
chmod +x /etc/greenboot/check/wanted.d/20-fleet-network.sh

### 3b. kDrive (AppImage pré-extraite + wrapper natif) ------------------------
# Ne fait quelque chose que si KDRIVE_URL est passé au build (sinon ignoré proprement,
# sans créer de lanceur cassé). Voir build_files/install-kdrive.sh et docs/04.
bash /tmp/build_files/install-kdrive.sh

### 4. Nettoyage + commit ostree (obligatoire sur une base ostree) ------------
rm -rf /var/cache /var/lib/dnf /tmp/build_files
ostree container commit
