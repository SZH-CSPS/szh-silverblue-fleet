# Reste à faire / à valider

Miroir condensé de [../TODO.md](../TODO.md) (voir aussi FEATURES.md annexe 3).

## Portes de validation (exigent un build CI réel — non testable hors CI)
1. **Build buildah des 3 images** (pull base Silverblue/bootc + layering).
2. **`syncthing.service` user** présent dans le paquet F44 ? sinon `syncthing@.service` système.
3. **USBGuard banc** : syntaxe de `rules.conf` + `usbguard-daemon.conf` (une règle invalide
   empêche le démon de démarrer), et non-lockout sur le matériel réel.
4. Coexistence `gpg`/`scdaemon` ↔ `pcscd` (peut nécessiter `pcsc-shared`).
5. `fleet-vault` : tester `create/open/close/status` sur une vraie machine (cryptsetup loop).
6. VeraCrypt retiré → `fuse`/`fuse-libs` retirés : vérifier que rien d'autre n'en dépend.
7. `common/build/lib.sh` créé mais **non câblé** dans les build.sh (adoption = follow-up).

## Sécurité
- **PIN LUKS** : ✅ résolu (cause = enrôlement jamais fait ; `fleet-tpm-enroll` déplacé en
  `/usr/bin`). Reste : fiabiliser l'enrôlement au 1er login (l'assistant ne se lance qu'au
  login GNOME du compte bureau ; sinon `sudo fleet-provision` / `sudo fleet-tpm-enroll`).
- **Clavier prompt LUKS** : 🎯 cause CONFIRMÉE (07-05) = karg `vconsole.keymap=` VIDE posé
  par Anaconda à l'install (écrase /etc/vconsole.conf, priorité cmdline). Corrigé : kickstart
  `keyboard --vckeymap=fr_CH`, kargs d'image, rhgb/quiet rétablis, service initramfs à chaque
  boot. **À VALIDER sur poste** :
  `sudo rpm-ostree kargs --delete=vconsole.keymap --append=vconsole.keymap=fr_CH` + reboot
  → tester `z` au prompt. À appliquer sur CHAQUE poste déjà installé.
- **GDM profil admin** : compte `admin` réaffiché (`fleet-gdm-show-admin.conf` + retrait du
  masquage). Le desktop standard continue de masquer `admin`. GDM présélectionne ensuite le
  dernier utilisateur connecté (pas de « défaut » figé possible nativement).
- Activer `COSIGN_ENABLED=true` en prod (sinon policy.json rejette les images non signées).
- greenboot : décider des checks `required.d/` (bloquants) — prudence sur le banc hors-ligne.
- Logo GDM désactivé (asset dédié à produire).

## Migration
- Re-pointer les postes déployés `silverblue-x13*` → `szh-*` (`bootc switch`, cf.
  [06-securite.md](06-securite.md) / REDESIGN Phase 4).
- Commande pour cette machine → `szh-silverblue-admin` : voir 06-securite.md.

## Comptes / install
- Banc : définir les identifiants du compte `tester` à l'installation (pas figés dans l'image).
- Modifs dconf non commitées (MAJ auto GNOME Software + `date-time-format`) à committer.
