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
#   fuse + fuse-libs                   : FUSE 2 (libfuse.so.2) requis par VeraCrypt pour
#                                        monter les volumes (absent de la base → à coucher ;
#                                        sinon « libfuse.so.2: cannot open shared object »).
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
    plymouth-plugin-script \
    fuse \
    fuse-libs

### 2. Services systemd -------------------------------------------------------
# Gestion d'énergie = défaut Fedora : tuned + tuned-ppd (sélecteur de profil GNOME natif).
# tuned est activé par défaut dans la base depuis F41 ; on l'assure par sûreté.
systemctl enable tuned.service 2>/dev/null || true

# Installe les Flatpaks de la flotte : timer qui réessaie chaque minute jusqu'au succès,
# puis stamp /var/lib/fleet/flatpaks-installed → plus de relance. On active le TIMER
# (pas le .service, déclenché par le timer). Voir fleet-flatpak-setup.{service,timer}.
systemctl enable fleet-flatpak-setup.timer

# Enrôlement TPM2 du LUKS : le service de BOOT était non fiable (prompt console invisible
# derrière Plymouth/GDM + stamp posé avant la tentative → jamais retenté). On NE l'active
# donc PAS. L'enrôlement se fait de façon fiable, en terminal, via le script admin
# change_password.sh (auto si non enrôlé, ou option --enrolltpm). Voir fleet-rotate-secrets.
# (Le script /usr/libexec/fleet-tpm-enroll reste dispo pour un « sudo fleet-tpm-enroll » manuel.)
# systemctl enable fleet-tpm-enroll.service   # désactivé volontairement

# Premier login szh-csps : pose le nom d'affichage "SZH-CSPS" + force le changement du
# mot de passe initial (service oneshot, une seule fois). Voir le service homonyme.
systemctl enable fleet-force-passwd-change.service

# Dépose change_password.sh à la racine du home d'admin au premier boot (rotation LUKS +
# mot de passe admin, retrait de la clé d'amorçage "changeme"). À lancer à la main.
systemctl enable fleet-admin-desktop-setup.service

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
# Activés pour TOUTE la flotte via le fichier d'état LIVRÉ DANS L'IMAGE :
#   system_files/etc/fedora-third-party.conf  ([main] enabled = 1)
# → GNOME Software ne propose plus "Activer / Ignorer" (auth admin par poste), pour tous
#   les comptes, déterministe (committé par ostree).
# On NE lance PAS « fedora-third-party enable/refresh » ici : l'outil gérerait lui-même le
# remote Flathub (version filtrée Fedora possible), ce qui entrerait en conflit avec notre
# Flathub COMPLET ajouté par fleet-flatpak-sync (requis pour VS Code, Proton, etc.).
# Rien à faire dans build.sh : le fichier suffit.

### 2d. Défauts GNOME (dconf) -------------------------------------------------
# Compile la base dconf système (profil + clés déposés via system_files) : active
# l'extension AppIndicator par défaut (tray kDrive). Détails : docs/04.
dconf update || true

### 2e. Splash Plymouth (thème szh) + RÉGÉNÉRATION INITRAMFS ------------------
# Thème de boot déposé dans /usr/share/plymouth/themes/szh (+ plymouth-plugin-script).
# On le définit par défaut, puis on RÉGÉNÈRE l'initramfs pour y embarquer :
#   - le thème Plymouth szh (sinon le splash szh n'apparaît PAS au boot) ;
#   - le keymap clavier suisse (/etc/vconsole.conf → invite LUKS en suisse).
# Validé d'abord côté poste (rpm-ostree initramfs), puis porté ici.
# GARDE-FOU : on EXIGE le module « ostree » dans l'initramfs régénéré (sans lui, non-boot)
# → si absent, on échoue le build plutôt que de livrer une image qui ne démarre pas.
plymouth-set-default-theme szh || true

kver="$(ls -1 /usr/lib/modules | head -n1)"
echo "Régénération de l'initramfs pour le noyau ${kver} (thème szh + keymap)…"
# --no-hostonly(-cmdline) : initramfs GÉNÉRIQUE (sinon dracut l'adapterait au CONTENEUR de
# build → non-boot sur le vrai matériel). Le mode générique embarque aussi tous les keymaps
# (dont fr_CH) et Plymouth. --add ostree : indispensable au boot ostree (vérifié ci-dessous).
dracut --force --no-hostonly --no-hostonly-cmdline --add ostree \
    --kver "${kver}" "/usr/lib/modules/${kver}/initramfs.img"
if ! lsinitrd "/usr/lib/modules/${kver}/initramfs.img" | grep -q 'ostree'; then
    echo "ERREUR : initramfs régénéré SANS module ostree → risque de non-boot. Abandon du build." >&2
    exit 1
fi
echo "✓ initramfs régénéré (module ostree présent)."

### 3. Permissions ------------------------------------------------------------
chmod +x /usr/libexec/fleet-flatpak-sync
chmod +x /usr/libexec/fleet-tpm-enroll
chmod +x /usr/libexec/fleet-rotate-secrets
chmod +x /etc/greenboot/check/wanted.d/20-fleet-network.sh

### 3b. kDrive (AppImage pré-extraite + wrapper natif) ------------------------
# Ne fait quelque chose que si KDRIVE_URL est passé au build (sinon ignoré proprement,
# sans créer de lanceur cassé). Voir build_files/install-kdrive.sh et docs/04.
bash /tmp/build_files/install-kdrive.sh

### 3c. VeraCrypt (RPM officiel couché) ---------------------------------------
# Couche le RPM VeraCrypt (cf. install-veracrypt.sh). Vide VERACRYPT_URL → ignoré.
bash /tmp/build_files/install-veracrypt.sh

### 4. Nettoyage + commit ostree (obligatoire sur une base ostree) ------------
rm -rf /var/cache /var/lib/dnf /tmp/build_files
ostree container commit
