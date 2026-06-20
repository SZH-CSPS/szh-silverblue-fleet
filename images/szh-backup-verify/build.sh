#!/usr/bin/env bash
# =============================================================================
#  build.sh — image BACKUP-VERIFY (banc de vérif backup, headless, fedora-bootc).
#  Exécuté PENDANT le build (contexte = racine du dépôt).
#
#  Base fedora-bootc → on installe avec `dnf` (PAS rpm-ostree) et il n'y a PAS de
#  `ostree container commit` (idiome propre aux images ostree/Silverblue).
# =============================================================================
set -euxo pipefail

### 1. Outillage de vérification (headless, pas de GUI) ------------------------
#   libvirt/qemu-kvm/virt-install : démarrer une petite VM PBS jetable + VM de test
#   cryptsetup                    : ouvrir le disque hors-site LUKS (en lecture seule)
#   restic                        : vérif de dépôts restic (selon la chaîne de backup)
#   ImageMagick (magick)          : décodage des images (check-photos-decode.sh)
#   python3-pillow                : décodage d'images alternatif / scripts Python
#   jq curl openssh-clients       : API Immich, ping, SSH vers les VM de test
#   usbguard                      : durcissement USB (dock hors-site autorisé à la main)
#   pcsc-lite(-ccid) gnupg2 ykman : YubiKey → clé GPG de déchiffrement HORS du disque
dnf install -y \
    libvirt qemu-kvm virt-install \
    cryptsetup restic \
    ImageMagick python3-pillow \
    jq curl openssh-clients usbguard \
    pcsc-lite pcsc-lite-ccid gnupg2 yubikey-manager
# (Optionnel) ZFS UNIQUEMENT si le disque de rotation est un pool ZFS — décommenter :
# dnf install -y zfs
dnf clean all

### 2. Utilisateur opérateur ---------------------------------------------------
# tester : wheel (sudo) + libvirt (gestion des VM). Mot de passe / clé SSH à définir
# À L'INSTALLATION (ex. bootc install --root-ssh-authorized-keys, ou kickstart BIB) —
# l'image ne fige aucun secret. Voir TODO.md / docs.
useradd -m -G wheel,libvirt tester || true

### 3. Services ----------------------------------------------------------------
systemctl enable libvirtd.service
systemctl enable usbguard.service     # politique : system_files/etc/usbguard/
systemctl enable pcscd.socket         # pile carte à puce / YubiKey (à la demande)

### 4. Scripts de vérification (rendus exécutables) ----------------------------
chmod 0755 /usr/local/bin/check-photos-decode.sh \
           /usr/local/bin/check-vm-boot.sh \
           /usr/local/bin/check-immich.sh

### 5. Nettoyage ---------------------------------------------------------------
# PAS de `ostree container commit` (base fedora-bootc, pas rpm-ostree).
rm -rf /tmp/build /tmp/common
