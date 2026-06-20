# 04 — Applications

## Règle de répartition
- **RPM (couché au build)** : CLI / accès matériel profond / services. Petit, stable.
- **Flatpak (synchronisé)** : applications graphiques. Listes
  `system_files/usr/share/fleet/flatpaks.d/*.list`, installées/MAJ/prunées par
  [`fleet-flatpak-sync`](../images/szh-silverblue-desktop/system_files/usr/libexec/fleet-flatpak-sync)
  (boot + quotidien). Retirer une ligne → désinstallation au prochain passage.
- **distrobox** : chaînes lourdes/changeantes (ex. `pipeline.ini` = WeasyPrint + Pandoc).

## Listes Flatpak
- `10-standard.list` (desktop, commun) : navigateur, mail, bureautique, VS Code, Proton,
  **Yubico Authenticator** (compat YubiKey pour tous).
- `20-sysadmin.list` (admin) : GIMP/Inkscape/Scribus, Obsidian, Signal/Element, draw.io,
  Podman Desktop, Seahorse, FreeCAD/Bambu/OpenSCAD, etc.

## RPM par image
- **Desktop** (`build.sh`) : distrobox, greenboot(+checks), appindicator, tpm2-tools,
  **pcsc-lite + pcsc-lite-ccid + yubikey-manager** (compat YubiKey), zenity (conditionnel).
- **Admin** (`build.sh`) : wireshark, gh, jq/yq, ripgrep/fzf/bat/fd-find/eza/git-delta, uv,
  **syncthing** (service user, UI `localhost:8384`), p7zip(-plugins).
- **Banc** (`build.sh`) : libvirt/qemu-kvm/virt-install, cryptsetup, restic, ImageMagick,
  python3-pillow, jq/curl/openssh-clients, usbguard, pcsc-lite/gnupg2/ykman.

## kDrive (Infomaniak)
AppImage livrée dans `/usr/lib/kdrive` + wrapper `/usr/bin/kdrive` qui l'extrait une fois par
utilisateur dans `~/.cache/kdrive` (kDrive échoue s'il tourne depuis `/usr` en RO). Lanceur +
autostart. `KDRIVE_URL`/`KDRIVE_VERSION` au build (vide → omis). Voir `install-kdrive.sh`.

## Chiffrement de données amovibles (remplace VeraCrypt)
- **Clé USB entière** : « Disques » (GNOME / udisks2) → formater en *LUKS + Ext4* → montage
  auto par Fichiers à l'insertion. Sans privilège. Crypto LUKS2 (AES-256-XTS, Argon2id).
- **Coffre-fichier** : [`fleet-vault`](../images/szh-silverblue-desktop/system_files/usr/bin/fleet-vault)
  `create|open|close|status` (LUKS2 dans un fichier ; nécessite sudo → comptes wheel).
- Interop Windows ponctuelle : WSL2 (`wsl --mount --bare` + `cryptsetup`).
