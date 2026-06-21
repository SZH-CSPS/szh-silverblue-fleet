# TODO — redesign `szh-silverblue-fleet`

> **Tracker de travail** (mis à jour en continu). Voir aussi [REDESIGN.md](REDESIGN.md) (plan
> cible + décisions) et [FEATURES.md](FEATURES.md) (inventaire de l'existant).
>
> **Reprise de session après reboot** : depuis ce dossier, `claude --resume` (ou
> `claude --continue`). Transcript :
> `~/.claude/projects/-var-home-admin-Prog-szh-silverblue-fleet/5d58091a-….jsonl`.
> Même une session neuve peut reprendre en lisant TODO.md + REDESIGN.md + FEATURES.md.

## Décisions figées (rappel)
- Signature cosign : **par clé** (`policy.json` keyPath). Activer `COSIGN_ENABLED=true` en prod.
- Chiffrement support amovible : **LUKS2 natif**, VeraCrypt **retiré**. Helper `fleet-vault`.
- Sécurité : durcissement **conservateur** (impact UX nul).
- Noms d'images : `szh-silverblue-desktop`, `szh-silverblue-admin`, `szh-backup-verify`.
- Banc : base `fedora-bootc:44`, **buildah**, headless. LUKS du banc optionnel (clé GPG sur
  **YubiKey** → rien sur disque). PIN LUKS desktop **cassé, à corriger plus tard**.
- YubiKey : compat + logiciel sur **les 3** images. Syncthing + Obsidian sur **admin**.

## Fait ✅
- [x] **FEATURES.md** — inventaire complet de l'existant.
- [x] **REDESIGN.md** — plan cible (2 familles, noyau source) + décisions.
- [x] **Phase 0** — socle durcissement : `etc/sysctl.d/90-fleet-hardening.conf`,
      `coredump.conf.d/90-fleet-nocore.conf`, `limits.d/90-fleet-nocore.conf`.
- [x] **YubiKey compat** sur standard (`pcsc-lite`, `pcsc-lite-ccid`, `ykman` + `pcscd.socket`)
      → hérité par admin ; Yubico Authenticator déplacé en `10-standard.list`.
- [x] **Syncthing** (RPM, service user) ajouté à l'admin ; ykman retiré de l'admin.
- [x] **Restructuration monorepo** : `common/` + `images/{desktop,admin,backup-verify}` (git mv).
- [x] **Containerfiles + CI + Renovate + policy.json + registries + build-iso** adaptés (noms + chemins).
- [x] **Image `szh-backup-verify`** : Containerfile fedora-bootc:44, build.sh (dnf), usbguard
      (YubiKey autorisée), user `tester`, `bin/check-*.sh`.
- [x] **`fleet-vault`** (coffre-fichier LUKS2) + chmod dans le build desktop.
- [x] **docs/** reconstitués (02/04/05/06 + runbook banc + RESTE-A-FAIRE) → liens morts comblés.
- [x] **Commande de migration** de cette machine → `szh-silverblue-admin` (REDESIGN Phase 4 / docs/06).
- [x] **Vérif statique** : `bash -n` OK partout, `policy.json` valide, aucune réf obsolète en fichier actif.

## Reste à faire ⏳ (les briques sont écrites — il reste la VALIDATION runtime)
- [ ] **Build CI réel** des 3 images (seul vrai test — non faisable hors CI). Cf. portes ci-dessous.
- [x] **PIN LUKS** résolu : cause = enrôlement jamais fait (slot tpm2 absent) ;
      `fleet-tpm-enroll` déplacé en `/usr/bin`. Reste : fiabiliser l'enrôlement au 1er login.
- [x] **Clavier prompt LUKS** : `rhgb`/`quiet` retirés → prompt texte QWERTZ correct
      (Plymouth saisissait en QWERTY). Fallback documenté : `plymouth.enable=0` si besoin.
- [ ] **`common/build/lib.sh`** : créé en scaffolding, **non câblé** dans les build.sh (follow-up).
- [ ] (Plus tard) Renommage effectif des postes déployés (`bootc switch`, cf. REDESIGN Phase 4).

## ⚠️ Portes de validation (NON testables ici — exigent un build CI réel)
- Build buildah des 3 images (impossible localement : pull base Silverblue/bootc + layering).
- `syncthing.service` user existe-t-il dans le paquet F44 ? (sinon `syncthing@.service` système)
- Coexistence `gpg`/`scdaemon` ↔ `pcscd` (peut nécessiter `pcsc-shared`).
- VeraCrypt retiré → `fuse`/`fuse-libs` retirés du desktop : vérifier que rien d'autre n'en dépend.
- Renommage d'images → re-pointer les postes déjà déployés (`bootc switch`), MAJ `policy.json`.

## Journal
- 2026-06-20 — FEATURES + REDESIGN + Phase 0 + YubiKey/Syncthing livrés. Début restructuration.
- 2026-06-20 — Restructuration monorepo complète (common/ + images/), 3 images câblées (CI,
  policy, renovate, BIB), banc szh-backup-verify créé, fleet-vault créé, docs/ reconstitués.
  Vérif statique OK. Reste : build CI réel + correction PIN LUKS. Phases 1→5 du REDESIGN faites
  côté code (sauf validation runtime).
