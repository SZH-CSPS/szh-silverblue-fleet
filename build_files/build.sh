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
#   plymouth-plugin-script             : module « script » requis par le thème de boot szh
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
    tpm2-tools \
    plymouth-plugin-script

### 2. Services systemd -------------------------------------------------------
# Gestion d'énergie = défaut Fedora : tuned + tuned-ppd (sélecteur de profil GNOME natif).
# tuned est activé par défaut dans la base depuis F41 ; on l'assure par sûreté.
systemctl enable tuned.service 2>/dev/null || true

# Installe/synchronise les Flatpaks par défaut au démarrage (unité + script fournis).
systemctl enable fleet-flatpak-setup.service

# Enrolement TPM2 du LUKS au premier boot (saisie passphrase sur console ; docs/06).
# No-op propre si le disque n'est pas chiffre ou s'il n'y a pas de TPM.
systemctl enable fleet-tpm-enroll.service

# Premier login szh-csps : pose le nom d'affichage "SZH-CSPS" + force le changement du
# mot de passe initial (service oneshot, une seule fois). Voir le service homonyme.
systemctl enable fleet-force-passwd-change.service

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

### 2c-bis. Dépôts tiers (fedora-third-party) --------------------------------
# Active les "Third Party Repositories" pour TOUT LE MONDE, par défaut, sans invite.
# Écrit l'état dans /etc/fedora-third-party.conf → la logithèque (GNOME Software) ne
# propose plus "Activer / Ignorer" (ces boutons exigeaient une auth admin par poste).
# Indépendant du compte utilisateur. No-op propre si l'outil est absent.
fedora-third-party enable 2>/dev/null || true

### 2d. Défauts GNOME (dconf) -------------------------------------------------
# Compile la base dconf système (profil + clés déposés via system_files) : active
# l'extension AppIndicator par défaut (tray kDrive). Détails : docs/04.
dconf update || true

### 2e. Splash Plymouth (thème szh) ------------------------------------------
# Thème de boot déposé dans /usr/share/plymouth/themes/szh (+ plymouth-plugin-script).
# On le définit par défaut. ATTENTION : sur une image ostree/bootc, le thème n'apparaît
# au boot QUE s'il est embarqué dans l'initramfs. Or régénérer l'initramfs DANS le build
# conteneur s'est révélé non fiable (module « ostree » non garanti → risque de non-boot,
# attrapé par un garde-fou lsinitrd). On NE régénère donc PAS ici : l'image conserve
# l'initramfs Fedora éprouvé → boot fiable. Le thème reste prêt ; pour l'activer vraiment,
# régénérer l'initramfs CÔTÉ POSTE (sur vrai matériel dracut inclut bien ostree) — à
# valider sur un poste test (voir RESTE-A-FAIRE).
plymouth-set-default-theme szh || true

### 3. Permissions ------------------------------------------------------------
chmod +x /usr/libexec/fleet-flatpak-sync
chmod +x /usr/libexec/fleet-tpm-enroll
chmod +x /etc/greenboot/check/wanted.d/20-fleet-network.sh

### 3b. kDrive (AppImage pré-extraite + wrapper natif) ------------------------
# Ne fait quelque chose que si KDRIVE_URL est passé au build (sinon ignoré proprement,
# sans créer de lanceur cassé). Voir build_files/install-kdrive.sh et docs/04.
bash /tmp/build_files/install-kdrive.sh

### 4. Nettoyage + commit ostree (obligatoire sur une base ostree) ------------
rm -rf /var/cache /var/lib/dnf /tmp/build_files
ostree container commit
