# 06 — Sécurité

## Durcissement (socle conservateur, impact UX nul)
[common/system_files/etc/sysctl.d/90-fleet-hardening.conf](../common/system_files/etc/sysctl.d/90-fleet-hardening.conf)
appliqué aux **3 images** : `kptr_restrict`, `dmesg_restrict`, `unprivileged_bpf_disabled`,
`bpf_jit_harden`, `protected_{hardlinks,symlinks,fifos,regular}`, `suid_dumpable=0`,
`yama.ptrace_scope=1`. Core dumps off (`coredump.conf.d` + `limits.d`). **Compatible KVM**
(userns gardés ; kvm/tun/bridge non blacklistés → requis par le banc). SSH entrant désactivé.

## Chaîne d'approvisionnement (signatures)
- [policy.json](../common/system_files/etc/containers/policy.json) : `default: reject` +
  signature cosign **exigée** pour les 3 dépôts de la flotte (`keyPath` = clé publique
  embarquée). Registres tiers en allowlist ; transports locaux permis.
- Signature **par clé** en CI (cf. [02-ci-renovate.md](02-ci-renovate.md)). Rotation de clé :
  signer une image de transition avec l'ANCIENNE clé (elle embarque la NOUVELLE clé publique),
  déployer, puis basculer la signature sur la nouvelle clé.

## Chiffrement disque LUKS / TPM2 / PIN (desktop)
- Parcours : LUKS choisi à l'install (`changeme`) → `sudo fleet-provision` (phrase de secours
  définitive + clé d'enrôlement temporaire `/var/lib/fleet/enroll.key`) → 1er login :
  l'utilisateur choisit **seulement son PIN** (assistant graphique), la clé temporaire est
  révoquée. Lié à **PCR 7** (Secure Boot). Phrase de passe LUKS = secours permanent.
- CLI admin / dépannage : `sudo fleet-tpm-enroll [--no-pin]`.
- ⚠️ **Le déverrouillage par PIN ne fonctionne pas à ce jour** — à corriger (cf.
  [RESTE-A-FAIRE.md](RESTE-A-FAIRE.md)). Repli = phrase de passe.

## greenboot (auto-rollback santé)
Après une MAJ + reboot, des health checks décident si le boot est « réussi » ; sinon GRUB
revient au déploiement précédent. Protection clé vu l'auto-update. Le check réseau
(`wanted.d/`) est **non bloquant**. ⚠️ Sur le **banc hors-ligne**, auditer les checks par
défaut (un check DNS/réseau en `required.d/` provoquerait des rollbacks en boucle).

## USBGuard (banc)
[usbguard-daemon.conf](../images/szh-backup-verify/system_files/etc/usbguard/usbguard-daemon.conf)
+ [rules.conf](../images/szh-backup-verify/system_files/etc/usbguard/rules.conf) : autorise ce
qui est présent au boot (lockout-safe), bloque les insertions sauf HID + YubiKey. Le dock du
disque hors-site s'autorise à la main par campagne (`usbguard allow-device`).

## YubiKey (clé GPG hors disque)
Compat sur les 3 images (`pcsc-lite`, `pcsc-lite-ccid`, `gnupg2`, `yubikey-manager` +
`pcscd.socket`). La clé privée GPG vit dans le jeton → rien sur disque → le banc reste « sans
clé ». Prévoir une **sauvegarde de la clé** (2e YubiKey / copie hors-ligne). Gotcha possible :
`pcsc-shared` dans `scdaemon.conf` si `gpg` et Yubico Authenticator se disputent la carte.

## Migration des postes vers les nouveaux noms d'images
Voir [REDESIGN.md §6 Phase 4](../REDESIGN.md) (commande `bootc switch` + cas « œuf-poule »
signature). Résumé pour cette machine → `szh-silverblue-admin` :
```bash
bootc status
sudo bootc switch --no-signature-verification ghcr.io/szh-csps/szh-silverblue-admin:latest
sudo systemctl reboot
```
(`--no-signature-verification` seulement pour la bascule de transition ; les MAJ suivantes
sont de nouveau vérifiées via le nouveau `policy.json`.)
