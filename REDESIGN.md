# Plan de redesign — `szh-silverblue-fleet`

> **But.** Repartir sur une base propre (fin du monkey-patching) : un **noyau de
> configuration commun** + des **profils spécifiques**, pour 3 cibles, en **augmentant la
> sécurité pour tous** (durcissement conservateur, impact UX nul).
>
> **À lire avec** [FEATURES.md](FEATURES.md) (inventaire de l'existant). Ce document décrit
> la **cible** et la **migration** ; FEATURES.md décrit le **présent**.
>
> **Statut.** Brouillon de plan, à valider avant tout changement de code. Décisions encore
> ouvertes : voir §7.

---

## 1. Les 3 cibles (et ce qu'elles partagent vraiment)

| Cible | Rôle | Base image | GUI |
|---|---|---|---|
| **Laptop standard** | poste de bureau de la flotte | `fedora-silverblue` | GNOME |
| **Laptop admin** | poste sysadmin (ex-profil `sysadmin`) | dérive du standard | GNOME |
| **Banc backup-verify** | vérif. backups jetable, **hors-ligne** (T470s) | `fedora-bootc` | headless |

**Constat clé.** Les deux laptops partagent une vraie base d'image (Silverblue/GNOME).
Le banc `backup-verify` part d'une base **différente** (`fedora-bootc`, headless) et ne
partage **rien au niveau de la couche d'image**. Le « noyau commun » ne peut donc PAS être
une image de base partagée : c'est un **ensemble de modules source** que chaque famille copie.

Ce qu'ils partagent réellement = **chaîne d'appro. signée, socle de durcissement,
conventions CI/tags/Renovate, pattern de stamps `/var/lib/fleet`**.

---

## 2. Architecture cible : 2 familles, 1 noyau source

```
                    common/  (noyau — NON bootable, fragments source)
                      │  policy.json + cosign · sysctl durci · lib.sh build
                      │  reusable CI (build/sign/push) · Renovate · conventions
        ┌─────────────┴──────────────┐
        ▼                             ▼
  Famille DESKTOP                Famille APPLIANCE
  FROM fedora-silverblue:44      FROM fedora-bootc:44
        │                             │
  szh-silverblue-desktop         szh-backup-verify
        │                        (autonome, headless)
        ▼
  szh-silverblue-admin
  (FROM desktop)
```

- **Desktop** garde le modèle actuel (admin dérive de standard → couches partagées, bascule
  `bootc switch`).
- **Appliance** copie `common/` directement par-dessus `fedora-bootc`.
- Le noyau est partagé **par copie de source**, pas par héritage d'image entre familles.

---

## 3. Structure de dépôt cible

```
common/                          # LE noyau partagé (source, non bootable)
  system_files/                  # fragments OS communs à TOUTES les images
    etc/sysctl.d/90-hardening.conf
    etc/containers/policy.json
    etc/containers/registries.d/
    etc/pki/containers/<clé publique cosign>
  build/lib.sh                   # fonctions shell : layer(), commit, log, enable_units()
  ci/build-sign-push.yml         # reusable workflow (workflow_call)

images/
  szh-silverblue-desktop/
    Containerfile                # FROM fedora-silverblue:44
    system_files/                # dconf, clavier suisse, LUKS/TPM, comptes, fonds…
    build.sh
  szh-silverblue-admin/
    Containerfile                # FROM …/szh-silverblue-desktop:latest
    system_files/                # 20-admin.list (flatpaks)
    build.sh                     # RPM CLI sysadmin
  szh-backup-verify/
    Containerfile                # FROM fedora-bootc:44
    system_files/                # usbguard, tester, libvirt…
    bin/                         # check-photos-decode.sh, check-vm-boot.sh, check-immich.sh
    build.sh

bootc-image-builder/             # configs ISO par image (desktop : kickstart LUKS)
.github/workflows/               # 1 wrapper court par image → appelle common/ci
.github/renovate.json5           # suit FEDORA_VERSION des 2 familles + pipeline.ini
FEATURES.md  REDESIGN.md  README.md
```

**Idiome de build par image** : `COPY common/system_files /` → `COPY images/<x>/system_files /`
→ `source common/build/lib.sh` puis `build.sh` propre → `bootc container lint`.
(Note : Silverblue = `rpm-ostree install` + `ostree container commit` ; `fedora-bootc` = `dnf
install`. Les deux idiomes diffèrent → on partage des **fonctions** dans `lib.sh`, pas un
script monolithique.)

---

## 4. Répartition existant → noyau / famille

Dérivé de [FEATURES.md](FEATURES.md). « Commun » = monte dans `common/`.

| Bloc (réf. FEATURES) | Destination | Note |
|---|---|---|
| Signatures cosign + `policy.json` + registries.d (D) | **common/** | + ajouter l'entrée `szh-backup-verify` |
| **sysctl durci** (nouveau, issu de la spec banc) | **common/** | zéro-impact UX → **pour les 3** |
| **Support YubiKey / carte à puce** (`pcsc-lite`, `pcsc-lite-ccid`, `yubikey-manager` ; `gnupg2` base) | **common/** | compat **pour les 3** ; GUI Yubico Authenticator (Flatpak) = desktop + admin uniquement |
| SSH entrant désactivé (F4) | **common/** | s'applique aux 3 |
| greenboot enable (G2) | **common/** (helper) | checks spécifiques par image |
| Renovate (L), schéma de tags datés (B3) | **common/** | une seule politique |
| Pattern stamps `/var/lib/fleet` (annexe FEATURES) | **common/** (convention) | réutilisé par les scripts |
| MAJ OS auto (G1), firmware (G3) | **common/** | pertinent desktop + banc |
| GNOME/dconf (I), clavier suisse + initramfs (J) | desktop | — |
| LUKS/TPM/PIN + assistant (E) | desktop | banc : LUKS optionnel (§7) |
| Comptes admin/szh-csps + masquage GDM (F1–F3) | desktop | banc : compte `tester` |
| Flatpak sync + listes + third-party (H1/H2) | desktop | — |
| kDrive (H3), distrobox pipeline (H5) | desktop | — |
| ~~VeraCrypt (H4)~~ → **LUKS2 natif** (GNOME Disques, `fleet-vault`) | desktop | **retiré** ; rien à coucher (déjà dans la base) |
| Fonds d'écran SZH, logo GDM (I3/I4) | desktop | — |
| tuned (G4), kargs splash (J4) | desktop | — |
| ISO + kickstart LUKS (K) | desktop (bootc-image-builder/) | banc : `bootc install to-disk` |
| RPM CLI sysadmin + 20-*.list (C1) **+ Syncthing (RPM), Obsidian (Flatpak)** | admin | Syncthing = service user, UI `localhost:8384` |
| libvirt/qemu, restic, ImageMagick, usbguard, `tester`, `check-*.sh` | backup-verify | depuis la spec |

---

## 5. Sécurité « pour tous » — socle conservateur (impact UX nul)

Promu dans `common/system_files/etc/sysctl.d/90-hardening.conf`, appliqué aux 3 images :

```
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.protected_fifos=2
fs.protected_regular=2
fs.suid_dumpable=0
kernel.yama.ptrace_scope=1
```
+ core dumps désactivés (systemd-coredump `Storage=none` + `* hard core 0`). **Compatible
KVM** : on **garde** les userns et on ne blackliste **pas** kvm/tun/bridge (le banc en a besoin
pour les VM de test). *Livré en Phase 0* (cf. §6).

**Déjà acquis à conserver** : SSH entrant off, `policy.json` default-reject + signatures,
verrouillage d'écran imposé (dconf locks, desktop).

**Spécifique par image (pas « pour tous »)** :
- `usbguard` → **banc uniquement** (bloque l'USB ; sur desktop, politique permissive-journalisée
  seulement, à étudier plus tard — pas dans le socle conservateur).
- greenboot bloquant (`required.d/`) : décider quels checks promouvoir (§7).

**Hors socle conservateur** (notés pour mémoire, NON retenus maintenant car impact UX/perf) :
`mitigations=auto,nosmt`, durcissement USB sur desktop, blacklist modules.

---

## 6. Plan de migration (incrémental, la flotte continue de builder)

Ordonné du moins risqué au plus structurant. Chaque phase est commitable seule.

**Phase 0 — Socle sécurité additif (gain immédiat, risque faible)** — ✅ *fait (working tree)*
- Livré : `etc/sysctl.d/90-fleet-hardening.conf`, `etc/systemd/coredump.conf.d/90-fleet-nocore.conf`,
  `etc/security/limits.d/90-fleet-nocore.conf`. Fichiers `/etc` appliqués au boot → **aucun
  câblage `build.sh`** (ship via `COPY system_files/`). Migreront sous `common/` en Phase 2.
- Reste : valider au prochain **build CI + smoke test poste** qu'aucun réglage ne gêne
  kDrive / VS Code (effet réel seulement après reconstruction + déploiement de l'image).

**Phase 1 — Intégrer `backup-verify` (isolé, ne touche pas le desktop)**
- Nouveau dossier image, **aligné** : base `fedora-bootc:44`, build **buildah**, signature
  **par clé** (§7), entrée `szh-backup-verify` dans `policy.json`, casse ghcr minuscule.
  **+ support YubiKey** (`pcsc-lite`, `pcsc-lite-ccid`, `gnupg2`, `yubikey-manager`) **et règle
  usbguard autorisant la YubiKey** (clé GPG de déchiffrement sur jeton — cf. §7.6).
- CI : wrapper qui réutilise le workflow commun. Renovate suit son `FROM`.
- Livrer `bin/check-*.sh` + runbook (le runbook de campagne → futur `docs/`).

**Phase 2 — Extraire le noyau `common/`**
- Créer `common/system_files`, `common/build/lib.sh`, `common/ci/build-sign-push.yml`.
- Refondre `build.yml` en wrappers `workflow_call`. Vérifier digests/tags identiques.

**Phase 3 — Réorganiser le desktop en `images/`**
- Déplacer Silverblue vers `images/szh-silverblue-desktop` + `images/szh-silverblue-admin`
  (ex-sysadmin). Le plus invasif → en dernier. Garder les builds verts à chaque étape.

**Phase 4 — Bascule des postes existants vers les nouveaux noms (coordonné)**
- Le nouveau dépôt utilise directement les noms finaux `szh-silverblue-desktop`,
  `szh-silverblue-admin`, `szh-backup-verify`. Les postes déjà déployés en `silverblue-x13*`
  doivent être basculés (`bootc switch`) + `policy.json` mis à jour. **Coût** : re-pointer
  les postes existants ; aucun impact sur les nouvelles installs.

- **⚠️ Œuf-poule signature** : le `policy.json` ACTUEL d'un poste ne connaît que
  `silverblue-x13*` (default reject). Une bascule vers le NOUVEAU nom est donc *refusée*
  tant que le poste n'a pas le nouveau `policy.json`. Or ce dernier n'arrive qu'AVEC la
  nouvelle image → il faut une bascule de transition.

  **Migration de CETTE machine (dev/admin → `szh-silverblue-admin`)** — après que la CI a
  buildé/poussé (et signé, si `COSIGN_ENABLED=true`) la nouvelle image :
  ```bash
  # 0. Image actuellement suivie :
  bootc status

  # 1a. Si la signature N'EST PAS imposée (COSIGN désactivé) → bascule directe :
  sudo bootc switch ghcr.io/szh-csps/szh-silverblue-admin:latest

  # 1b. Si la signature EST imposée (pull « rejected » car l'ancien policy.json ignore le
  #     nouveau nom) → UNE bascule de transition sans vérif (le poste récupère alors le
  #     nouveau policy.json, qui ré-impose la signature pour les MAJ suivantes) :
  sudo bootc switch --no-signature-verification ghcr.io/szh-csps/szh-silverblue-admin:latest

  # 2. Appliquer :
  sudo systemctl reboot

  # 3. Après redémarrage, contrôler (les MAJ suivantes sont de nouveau vérifiées) :
  bootc status
  ```
  Alternative à 1b conservant la vérif : éditer `/etc/containers/policy.json` du poste pour
  y ajouter l'entrée `szh-silverblue-admin` AVANT le `bootc switch` (puis bascule normale).

**Phase 5 — Reconstituer `docs/`**
- Combler les liens morts référencés par le code (`docs/02/04/05/06`, `docs/RESTE-A-FAIRE`)
  + intégrer le runbook backup-verify. Au fil des phases (décision validée précédemment).

---

## 7. Décisions ouvertes (à trancher avant implémentation)

1. **Modèle de signature cosign** — ✅ **DÉCIDÉ : par clé** (on garde le modèle actuel de la
   flotte : clé cosign + `policy.json` keyPath). Conséquence : `backup-verify` est converti
   du keyless vers la clé, et toutes les images partagent la même clé publique embarquée
   (vérif hors-ligne robuste, privé — pas de Rekor public).
2. **Activer `COSIGN_ENABLED=true` en prod** : si la signature par clé est retenue, confirmer
   qu'elle tourne réellement (sinon `policy.json` rejette les images non signées au déploiement).
3. **Version Fedora du banc** — ✅ **DÉCIDÉ : aligné sur 44** (`fedora-bootc:44`).
4. **Outil de build CI unique** — ✅ **DÉCIDÉ : buildah partout** (un seul reusable workflow).
5. **Noms d'images** — ✅ **DÉCIDÉ** : `szh-silverblue-desktop` (standard), `szh-silverblue-admin`
   (admin), `szh-backup-verify` (banc). Bascule des postes existants = Phase 4.
6. **Secret de déchiffrement du banc & LUKS** — ⚠️ conditionnel à *où vit la clé* :
   - **Voie recommandée — clé GPG sur YubiKey** : la clé privée vit dans le **jeton**, jamais
     sur le disque du banc ; `gpg`/`pass` appellent la carte (PIN + touch). Le banc reste
     *réellement* « sans clé » → un vol ne révèle rien → **LUKS du banc redevient optionnel**.
     Prérequis image banc : `gnupg2` + `pcsc-lite`, et **autoriser la YubiKey dans usbguard**.
     Prévoir une **sauvegarde de la clé** (2e YubiKey ou copie hors-ligne au coffre) — sinon SPOF.
   - **Phrase tapée à chaque campagne** (rien stocké) → LUKS du banc optionnel (defense-in-depth
     pour les données restaurées transitoires sur le scratch).
   - **Keyfile/clé en clair posé sur le disque** (à éviter) → LUKS du banc **obligatoire**
     (phrase interactive au boot ; pas de TPM auto-unlock, qui annulerait la protection au vol).
7. **greenboot bloquant** : quels health checks passer en `required.d/` (un échec → rollback) ?
   *Reco : démarrer non bloquant partout, promouvoir au cas par cas après observation.*
8. **Chiffrement clé USB / coffre de secrets** — ✅ **DÉCIDÉ : LUKS2 natif, VeraCrypt
   retiré.** Supports lus uniquement sous Linux (fleet interne ; cas Windows ponctuel = WSL2
   `wsl --mount --bare` + `cryptsetup`, réservé à l'IT). Clé USB *entière* → GNOME Disques
   (format « LUKS + Ext4 ») + montage auto Nautilus. Coffre-*fichier* → `cryptsetup` sur
   loopback (helper `fleet-vault` à fournir, optionnel). Bénéfice annexe : supprime le RPM
   VeraCrypt Fedora-40-sur-F44 non validé (cf. FEATURES H4).

---

## 8. Hors périmètre (pour mémoire, plus tard)

- Politique USB sur desktop (usbguard permissif-journalisé).
- Mitigations CPU agressives (`nosmt`), blacklist de modules.
- MDM/inventaire de flotte, télémétrie de conformité.
- Logo GDM (asset dédié à produire — cf. FEATURES I4).
