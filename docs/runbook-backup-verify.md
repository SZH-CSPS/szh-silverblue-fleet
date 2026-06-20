# Runbook — banc `szh-backup-verify`

Banc **jetable et hors-ligne** (ThinkPad T470s) dont le seul rôle est d'éprouver la copie
hors-site et de confirmer que les backups sont restaurables : le **« 0 » du 3-2-1-1-0**
(zéro erreur, vérifiée). Distinct de PBS, sans clés vers l'infra → verdict déterministe.

## Matériel
- T470s, 1× NVMe (256–500 Go : OS atomique + disques des VM de test, jamais la photothèque).
- Disque hors-site = HDD 3,5" via **dock USB alimenté**, monté **en lecture seule**.
- `memtest86+` une nuit au 1er démarrage (corruption silencieuse). Si OK → machine de confiance.

## Runbook d'une campagne
1. **MAJ en ligne AVANT les tests.** Brancher l'Ethernet → `sudo bootc upgrade` →
   `sudo systemctl reboot` → **débrancher le câble**. (Image signée, vérifiée par `policy.json` ;
   fenêtre réseau ~2 min.)
2. **Brancher le disque hors-site** et le monter en RO :
   - LUKS : `sudo cryptsetup open --readonly /dev/sdX offsite && sudo mount -o ro /dev/mapper/offsite /mnt/offsite`
   - ZFS : `sudo zpool import -o readonly=on offsite`
   - (USBGuard : `usbguard list-devices` puis `usbguard allow-device <id>` pour le dock.)
3. **Démarrer une petite VM PBS jetable** pointée sur le datastore en RO (contourne
   `proxmox-backup-client` sur hôte atomique). Disque ZFS → lecture directe du pool importé.
4. **Restaurer vers le scratch NVMe** : disque de la VM Immich (OS + DB) + une autre VM.
   **Jamais la photothèque entière.**
5. **Vérifs déterministes** :
   - `check-vm-boot.sh <vm> <ip>` — la VM restaurée atteint un état systemd sain.
   - `check-immich.sh <http://ip:2283> <api-key> <attendu>` — ping + version + nb d'assets.
   - `check-photos-decode.sh <dossier>` — chaque image décode (montée en RO via
     `proxmox-backup-client mount`).
6. **Fermer** : `umount` / `zpool export offsite` / `cryptsetup close offsite`, débrancher le
   disque. `bootc rollback` ou effacement du scratch pour repartir propre.

## Disciplines non négociables
- Ordre strict : **update → reboot → débrancher → tester** (jamais de test câble branché).
- Disque hors-site **toujours en lecture seule**.
- Clé de déchiffrement sur **YubiKey** (rien sur le disque du banc) — cf.
  [06-securite.md](06-securite.md).
