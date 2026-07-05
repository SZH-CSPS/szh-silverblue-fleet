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
# ⚠️ ZFS = module NON SIGNÉ : incompatible avec lockdown=confidentiality (karg commun
#    21-hardening-lockdown.toml). Si ZFS requis : hardening/reverts/revert_kargs_lockdown.sh
dnf clean all

### 1b. Durcissement secureblue (voir hardening/README.md) ---------------------


# >>> fleet-hardening: faillock >>>
# Anti-bruteforce (common/etc/security/faillock.conf) — utile aussi sur le compte tester.
# Revert : hardening/reverts/revert_faillock.sh
authselect current 2>/dev/null | grep -q with-faillock \
    || authselect enable-feature with-faillock 2>/dev/null || true
# <<< fleet-hardening: faillock <<<

# >>> fleet-hardening: chrony-nts >>>
# Heure authentifiée NTS (common/etc/chrony.d/). Utile au banc : MAJ en ligne ponctuelles.
# Revert : hardening/reverts/revert_chrony_nts.sh
{ [ -f /etc/chrony.conf ] && ! grep -q '^sourcedir /etc/chrony.d' /etc/chrony.conf \
    && echo 'sourcedir /etc/chrony.d' >> /etc/chrony.conf ; } || true
# <<< fleet-hardening: chrony-nts <<<

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
