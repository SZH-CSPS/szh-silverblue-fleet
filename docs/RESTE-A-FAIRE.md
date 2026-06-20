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
- **PIN LUKS non fonctionnel** (desktop) → diagnostiquer (`systemd-cryptenroll`, Secure Boot
  PCR 7, invite initramfs).
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
