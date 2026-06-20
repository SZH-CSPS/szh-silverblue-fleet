# Inventaire des fonctionnalités — `szh-silverblue-fleet`

> **But de ce document.** État des lieux *exhaustif* des fonctionnalités actuellement
> implémentées dans ce dépôt, catégorisées, avec pour chacune **comment elle est
> implémentée** (fichiers + mécanisme + pièges). Objectif : qu'une IA (ou un humain)
> puisse reprendre le contexte sans relire tout le code.
>
> **Périmètre.** Décrit l'état du *working tree* au **2026-06-20**. Ne couvre PAS le futur
> profil « admin serveur » (vérif. backup offline) : il n'existe pas encore dans le code.
>
> **À noter dès maintenant :**
> - Le code référence partout un dossier `docs/` (`docs/02`, `docs/04`, `docs/05`,
>   `docs/06`, `docs/RESTE-A-FAIRE`) qui **n'existe pas** dans le dépôt → liens morts à
>   reconstituer pendant le redesign.
> - Deux fichiers dconf ont des **modifs non commitées** (MAJ auto GNOME Software +
>   `date-time-format` Nautilus). Elles sont incluses dans cet inventaire.

---

## Table des matières

- [A. Vue d'ensemble & architecture](#a-vue-densemble--architecture)
- [B. Construction & publication (CI/CD)](#b-construction--publication-cicd)
- [C. Profils & héritage d'image](#c-profils--héritage-dimage)
- [D. Sécurité — chaîne d'approvisionnement (signatures)](#d-sécurité--chaîne-dapprovisionnement-signatures)
- [E. Sécurité — chiffrement disque (LUKS / TPM2 / PIN)](#e-sécurité--chiffrement-disque-luks--tpm2--pin)
- [F. Sécurité — comptes & accès](#f-sécurité--comptes--accès)
- [G. Cycle de vie & robustesse (MAJ, rollback, firmware)](#g-cycle-de-vie--robustesse-maj-rollback-firmware)
- [H. Applications (Flatpak, RPM tiers, distrobox)](#h-applications-flatpak-rpm-tiers-distrobox)
- [I. Expérience bureau (GNOME / dconf)](#i-expérience-bureau-gnome--dconf)
- [J. Localisation & clavier suisse](#j-localisation--clavier-suisse)
- [K. Installation (ISO Anaconda)](#k-installation-iso-anaconda)
- [L. Maintenance des versions (Renovate)](#l-maintenance-des-versions-renovate)
- [Annexe 1 — Carte des fichiers](#annexe-1--carte-des-fichiers)
- [Annexe 2 — Stamps & état runtime (`/var/lib/fleet`)](#annexe-2--stamps--état-runtime-varlibfleet)
- [Annexe 3 — Points ouverts / TODO repérés dans le code](#annexe-3--points-ouverts--todo-repérés-dans-le-code)

---

## A. Vue d'ensemble & architecture

**Quoi.** Image Fedora Silverblue dérivée (modèle *image mode / bootc*) pour une flotte de
ThinkPad X13. La configuration est versionnée dans Git, buildée et signée en CI, publiée sur
un registre de conteneurs (`ghcr.io`), puis déployée atomiquement sur les postes ; un échec
de boot post-MAJ revient en arrière tout seul (rollback en un redémarrage).

**Modèle à 2 images (hérité de universal-blue : bluefin → bluefin-dx)**
- `silverblue-x13` — image **standard** de la flotte.
- `silverblue-x13-sysadmin` — **dérive** de la standard (couches de base partagées) en
  ajoutant des outils sysadmin. Un poste change de profil par `bootc switch`.

**Cycle de vie d'un poste**
1. **Install** : ISO Anaconda (cat. K) → disque chiffré LUKS + comptes.
2. **Provisioning admin** : `sudo fleet-provision` (phrase de secours LUKS + clé d'enrôlement).
3. **1er login utilisateur** : assistant graphique → enrôlement TPM2+PIN ; nom d'affichage +
   expiration du mot de passe ; régénération initramfs (clavier suisse) ; sync Flatpak.
4. **Exploitation** : rebuild CI quotidien → `rpm-ostree` télécharge/prépare → appliqué au
   reboot, sous garde greenboot.
5. **Bascule de profil** : `bootc switch ghcr.io/szh-csps/silverblue-x13-sysadmin:latest`.

**Pile technique.** Fedora Silverblue 44 · bootc / `rpm-ostree` · buildah + GitHub Actions ·
cosign/sigstore · `bootc-image-builder` (ISO) · GNOME/dconf · systemd · Flatpak · distrobox.

---

## B. Construction & publication (CI/CD)

### B1. Containerfile standard
- **Fichiers** : [Containerfile](Containerfile), [build_files/build.sh](build_files/build.sh)
- **Mécanisme** : `FROM quay.io/fedora/fedora-silverblue:44` → `COPY system_files/ /` +
  `COPY build_files/` → `RUN build.sh` (layering RPM, activation services, intégration
  kDrive/VeraCrypt, `dconf update`, `ostree container commit`) → `RUN bootc container lint`
  (échoue le build si invariants bootc non respectés).
- **Build args** : `FEDORA_VERSION` (piloté Renovate), `KDRIVE_URL`/`KDRIVE_VERSION`,
  `VERACRYPT_URL`. Vides → l'app correspondante est omise proprement.
- **Pièges** : ne PAS coucher `git`/`python3`/`fwupd` (déjà dans la base → `rpm-ostree`
  casse sur « already provided ») ; `zenity` est couché conditionnellement pour la même raison.

### B2. `build.sh` — couche système (étape clé)
- **Fichier** : [build_files/build.sh](build_files/build.sh)
- **Mécanisme** : `rpm-ostree install` (distrobox, greenboot, appindicator, tpm2-tools,
  fuse/fuse-libs) → `systemctl enable` des services flotte + timers MAJ/firmware/greenboot →
  `chmod +x` des scripts → `install-kdrive.sh` + `install-veracrypt.sh` → nettoyage +
  `ostree container commit` (obligatoire sur base ostree).

### B3. Pipeline CI build & push
- **Fichier** : [.github/workflows/build.yml](.github/workflows/build.yml)
- **Déclencheurs** : push `main` (hors `docs/**` et `**.md`), **cron quotidien 05:00 UTC**
  (récupère les correctifs Fedora), `workflow_dispatch`.
- **Mécanisme** : build standard (buildah) → build sysadmin avec
  `BASE=localhost/silverblue-x13:latest` (garantit des couches de base **identiques**) →
  login ghcr → push des deux → signature cosign optionnelle.
- **Tags** : `latest`, `<sha>`, et tag daté `<fedora>.<AAAAMMJJ>` (ex. `44.20260610`) pour
  épingler/rollback une version connue.
- **Concurrence** : groupe `build-push`, `cancel-in-progress: false` (sérialise push + cron).
- **Note** : un bloc commenté en bas explique la variante registre auto-hébergé (Forgejo).

### B4. Build d'ISO d'installation (manuel)
- → voir cat. **K** (Installation).

---

## C. Profils & héritage d'image

### C1. Profil sysadmin dérivé
- **Fichiers** : [Containerfile.sysadmin](Containerfile.sysadmin),
  [build_files/build-sysadmin.sh](build_files/build-sysadmin.sh)
- **Mécanisme** : `FROM ghcr.io/szh-csps/silverblue-x13:latest` (ou `BASE` local en CI) →
  `COPY system_files_sysadmin/ /` → `build-sysadmin.sh` : `rpm-ostree install` d'outils CLI
  (wireshark, yubikey-manager, gh, jq/yq, ripgrep, fzf, bat, fd-find, eza, git-delta, uv,
  p7zip(-plugins)) → `ostree container commit`.
- **Répartition d'outils** (documentée dans le script) : RPM = CLI/accès matériel profond ;
  Flatpak = apps graphiques ([20-sysadmin.list](system_files_sysadmin/usr/share/fleet/flatpaks.d/20-sysadmin.list)) ;
  distrobox = chaînes lourdes.
- **Bascule** : `bootc switch …-sysadmin:latest` (atomique, réversible par `bootc rollback`).

---

## D. Sécurité — chaîne d'approvisionnement (signatures)

### D1. Signature cosign des images
- **Fichiers** : [.github/workflows/build.yml](.github/workflows/build.yml) (étapes cosign),
  [cosign.pub](cosign.pub), [system_files/etc/pki/containers/silverblue-x13.pub](system_files/etc/pki/containers/silverblue-x13.pub)
- **Mécanisme** : signature **par digest** (sortie de l'étape push, pas de résolution
  ultérieure de `latest` → pas de course). Activée par la variable de dépôt
  `COSIGN_ENABLED=true` + secrets `SIGNING_SECRET` / `SIGNING_SECRET_PASSWORD`.

### D2. Politique de confiance des conteneurs (imposition)
- **Fichiers** : [system_files/etc/containers/policy.json](system_files/etc/containers/policy.json),
  [system_files/etc/containers/registries.d/ghcr-silverblue-x13.yaml](system_files/etc/containers/registries.d/ghcr-silverblue-x13.yaml)
- **Mécanisme** : `default: reject` → seuls les registres allowlistés sont acceptés ; les
  deux images de la flotte **exigent** une signature cosign (`sigstoreSigned`, `keyPath`
  pointant la clé publique, `matchRepository`). `registries.d` indique d'utiliser les
  attachments sigstore. Transports locaux (build podman, stockage) restent permis.
- **Piège** : la règle la plus spécifique gagne — l'allowlist `ghcr.io` (insecure) n'affaiblit
  PAS l'exigence de signature sur les deux dépôts flotte (règles plus spécifiques).

---

## E. Sécurité — chiffrement disque (LUKS / TPM2 / PIN)

> Parcours flotte : **chiffrement choisi à l'install** (LUKS, phrase « changeme ») →
> **provisioning admin** (phrase de secours + clé d'enrôlement temporaire) →
> **1er login utilisateur** (l'utilisateur choisit juste son PIN, jamais la phrase de secours).
> La phrase de passe LUKS reste TOUJOURS le moyen de secours.

### E1. Provisioning post-installation (admin)
- **Fichier** : [system_files/usr/bin/fleet-provision](system_files/usr/bin/fleet-provision)
- **Mécanisme** (`sudo fleet-provision`, une fois) : (1) `luksChangeKey` remplace la phrase
  d'install par la phrase de secours définitive ; (1b) change le mot de passe `admin` + reset
  trousseau GNOME ; (2) dépose une clé aléatoire 64 o dans `/var/lib/fleet/enroll.key`
  (root 0600, **dans le disque chiffré**) ajoutée comme slot LUKS → autorise l'enrôlement PIN
  au 1er login. Re-provisioning : révoque l'ancienne clé d'abord. Validations : phrases ≥ 12 c.

### E2. Assistant graphique d'enrôlement (1er login)
- **Fichiers** : [system_files/usr/libexec/fleet-tpm-pin-setup](system_files/usr/libexec/fleet-tpm-pin-setup),
  [system_files/etc/xdg/autostart/fleet-tpm-pin-setup.desktop](system_files/etc/xdg/autostart/fleet-tpm-pin-setup.desktop)
- **Mécanisme** : autostart GNOME (délai 20 s) → dialogues `zenity`. Sort silencieusement
  (exit 0) si déjà enrôlé (stamp `tpm-enrolled`), pas de TPM, pas de LUKS, ou pas de zenity.
  Poste provisionné → demande **seulement le PIN** (≥ 6 c.) ; sinon (repli) demande la phrase
  LUKS en plus. Délègue la partie privilégiée au helper via `pkexec`. « Plus tard » → reproposé
  au prochain login (pas de stamp).

### E3. Helper privilégié (root via polkit)
- **Fichiers** : [system_files/usr/libexec/fleet-tpm-enroll-helper](system_files/usr/libexec/fleet-tpm-enroll-helper),
  [system_files/usr/share/polkit-1/actions/ch.szh.fleet.tpm-enroll.policy](system_files/usr/share/polkit-1/actions/ch.szh.fleet.tpm-enroll.policy)
- **Mécanisme** : secrets lus sur **STDIN** (jamais en argument → invisibles dans `/proc`).
  Mode provisionné : `systemd-cryptenroll --unlock-key-file=enroll.key --wipe-slot=tpm2
  --tpm2-pcrs=7 --tpm2-with-pin=yes`, puis **révoque** la clé temporaire (slot + fichier).
  Mode repli : phrase LUKS + PIN. Polkit `auth_self` (l'utilisateur confirme avec SON mot de
  passe de session) — la vraie barrière reste la phrase LUKS exigée par systemd-cryptenroll.

### E4. CLI admin d'enrôlement / ré-enrôlement
- **Fichier** : [system_files/usr/libexec/fleet-tpm-enroll](system_files/usr/libexec/fleet-tpm-enroll)
- **Mécanisme** : `sudo fleet-tpm-enroll [--no-pin]`. Enrôle TPM2 lié à **PCR 7** (état Secure
  Boot, stable aux MAJ noyau), `--wipe-slot=tpm2` (pas de doublon). Sert au dépannage / après
  changement firmware/Secure Boot. `--no-pin` déconseillé sur laptop.
- **Pièges** : PCR 7 n'a de valeur que si **Secure Boot activé** ; conserver la phrase LUKS.

### E5. Splash & prompt LUKS graphique
- → kargs `rhgb quiet` (cat. J / [10-fleet.toml](system_files/usr/lib/bootc/kargs.d/10-fleet.toml)) ;
  Plymouth = thème Fedora par défaut (pas de thème custom).

---

## F. Sécurité — comptes & accès

### F1. Deux comptes par poste (admin / utilisateur)
- **Fichier** : [bootc-image-builder/config.toml](bootc-image-builder/config.toml) (kickstart)
- **Mécanisme** : `admin` (groupe `wheel`/sudo, clé SSH ed25519 de robin.morand) +
  `szh-csps` (aucun groupe → pas de sudo). Mots de passe initiaux = hash de « changeme »
  (à changer au 1er login). `rootpw --lock` (pas de login root direct).

### F2. Expiration mot de passe + nom d'affichage (1er login)
- **Fichier** : [system_files/usr/lib/systemd/system/fleet-force-passwd-change.service](system_files/usr/lib/systemd/system/fleet-force-passwd-change.service)
- **Mécanisme** : oneshot, une seule fois (`ConditionPathExists=!/var/lib/fleet/passwd-expired`).
  Si `szh-csps` existe → `usermod -c "SZH-CSPS"` (GECOS) + `chage -d 0` (changement requis).

### F3. Masquage du compte `admin` à l'écran de connexion
- **Fichier** : [system_files/usr/lib/tmpfiles.d/fleet-gdm-hide-admin.conf](system_files/usr/lib/tmpfiles.d/fleet-gdm-hide-admin.conf)
- **Mécanisme** : `systemd-tmpfiles` crée `/var/lib/AccountsService/users/admin` avec
  `SystemAccount=true` → GDM n'affiche que `szh-csps` ; `admin` reste connectable via « Non
  répertorié ? ». (On crée le fichier au lieu d'embarquer du `/var` brut → conforme bootc lint.)
- **Effet de bord** : retire à `admin` le statut « administrateur » au sens UI GNOME (polkit
  Paramètres) ; sans impact sur `sudo` CLI (reste dans `wheel`).

### F4. SSH entrant désactivé
- **Fichier** : [build_files/build.sh](build_files/build.sh) (`systemctl disable sshd.service`)
- **Mécanisme** : défaut Workstation = désactivé ; on l'assure explicitement (durcissement).

---

## G. Cycle de vie & robustesse (MAJ, rollback, firmware)

### G1. Mises à jour OS automatiques
- **Fichiers** : [system_files/etc/rpm-ostree.conf](system_files/etc/rpm-ostree.conf),
  [build_files/build.sh](build_files/build.sh) (`enable rpm-ostreed-automatic.timer`)
- **Mécanisme** : image reconstruite chaque nuit (CI) → `AutomaticUpdatePolicy=stage` :
  le démon télécharge et **prépare** la nouvelle image ; application au **reboot** suivant
  (atomique, protégée par greenboot).

### G2. greenboot — santé du boot & auto-rollback
- **Fichiers** : [build_files/build.sh](build_files/build.sh) (enable de la chaîne greenboot),
  [system_files/etc/greenboot/check/wanted.d/20-fleet-network.sh](system_files/etc/greenboot/check/wanted.d/20-fleet-network.sh)
- **Mécanisme** : `greenboot` + `greenboot-default-health-checks` couchés ; chaîne d'units
  activée en boucle tolérante. Health check réseau dans `wanted.d/` = **NON bloquant**
  (journalisé MOTD/journal, pas de rollback). Déplacer dans `required.d/` pour le rendre
  bloquant (un échec → rollback auto).

### G3. Mises à jour firmware (LVFS)
- **Fichier** : [build_files/build.sh](build_files/build.sh) (`enable fwupd-refresh.timer`)
- **Mécanisme** : rafraîchissement auto des métadonnées LVFS ; l'**application** des MAJ
  firmware reste manuelle/maîtrisée. (`fwupd` supposé présent dans la base → non couché.)

### G4. Gestion d'énergie
- **Fichier** : [build_files/build.sh](build_files/build.sh) (`enable tuned.service`)
- **Mécanisme** : défaut Fedora `tuned` + `tuned-ppd` (sélecteur de profil GNOME natif).
  Pas de TLP.

---

## H. Applications (Flatpak, RPM tiers, distrobox)

### H1. Synchronisation des Flatpaks de la flotte
- **Fichiers** : [system_files/usr/libexec/fleet-flatpak-sync](system_files/usr/libexec/fleet-flatpak-sync),
  [.service](system_files/usr/lib/systemd/system/fleet-flatpak-setup.service) +
  [.timer](system_files/usr/lib/systemd/system/fleet-flatpak-setup.timer),
  listes [10-standard.list](system_files/usr/share/fleet/flatpaks.d/10-standard.list) /
  [20-sysadmin.list](system_files_sysadmin/usr/share/fleet/flatpaks.d/20-sysadmin.list)
- **Mécanisme** : ensemble désiré = **union** de toutes les listes `flatpaks.d/*.list` (ordre
  alphanum, `#` et lignes vides ignorés) → `flatpak install --system --or-update`. **Prune** :
  une app retirée des listes ET présente dans l'état précédent (`/var/lib/fleet/flatpaks.state`)
  est désinstallée ; les apps installées manuellement par l'utilisateur ne sont jamais touchées.
- **Robustesse réseau** : teste la joignabilité réelle de Flathub (curl) ; échec → exit ≠ 0 →
  `Restart=on-failure` réessaie toutes les 2 min (`StartLimitIntervalSec=0`). Timer quotidien
  `Persistent=true` + `RandomizedDelaySec=1h` (MAJ + prune réguliers).

### H2. Dépôts tiers Fedora activés pour toute la flotte
- **Fichier** : [system_files/etc/fedora-third-party.conf](system_files/etc/fedora-third-party.conf) (`enabled = 1`)
- **Mécanisme** : on **livre le fichier d'état** (déterministe en image mode) plutôt que de
  lancer `fedora-third-party enable` au build → GNOME Software n'affiche plus l'invite
  « Activer / Ignorer ». On NE lance PAS l'outil (il gérerait son propre remote Flathub filtré,
  en conflit avec notre Flathub complet ajouté par `fleet-flatpak-sync`).

### H3. kDrive (Infomaniak) — AppImage + wrapper
- **Fichiers** : [build_files/install-kdrive.sh](build_files/install-kdrive.sh) (appelé par build.sh)
- **Mécanisme** : l'AppImage est livrée telle quelle dans `/usr/lib/kdrive` ; un wrapper
  `/usr/bin/kdrive` l'**extrait une fois par utilisateur** dans `~/.cache/kdrive` (inscriptible)
  puis lance `AppRun` (kDrive échoue s'il tourne depuis `/usr` en lecture seule). Données
  (compte/ParmsDB) dans `$HOME`. Génère lanceur GNOME + autostart (délai 15 s). Icône extraite
  au build. `KDRIVE_URL` vide → ignoré proprement.
- **Piège** : version à **4 segments** (ex. `3.8.2.6`), dernier = build interne Infomaniak,
  absent des tags GitHub → **MAJ manuelle** de `KDRIVE_VERSION` (Renovate ne peut pas).

### H4. VeraCrypt — RPM officiel couché
- **Fichier** : [build_files/install-veracrypt.sh](build_files/install-veracrypt.sh)
- **Mécanisme** : télécharge + `rpm-ostree install` le RPM upstream (absent de Flathub/Fedora).
  Requiert `fuse`/`fuse-libs` (couchés dans build.sh). `VERACRYPT_URL` vide → ignoré.
- **Piège** : seul un RPM « Fedora-40 » est publié (1.26.24) ; **résolution de deps à valider
  sur F44**. Si échec : RPM console, COPR, ou build source.

### H5. Chaîne éditoriale distrobox (WeasyPrint + Pandoc)
- **Fichier** : [system_files/usr/share/fleet/distrobox/pipeline.ini](system_files/usr/share/fleet/distrobox/pipeline.ini)
- **Mécanisme** : conteneur `fedora:44` assemblé à la demande
  (`distrobox assemble create --file …/pipeline.ini`) avec Pango/cairo/harfbuzz + Pandoc +
  Ghostscript ; WeasyPrint via `pip` (init hook). Isole des dizaines de RPM hors de l'image
  atomique. `start_now=false` (créé au besoin). Tag fedora suivi par Renovate.

---

## I. Expérience bureau (GNOME / dconf)

### I1. Défauts dconf de la flotte
- **Fichiers** : [00-fleet-defaults](system_files/etc/dconf/db/local.d/00-fleet-defaults),
  [profile/user](system_files/etc/dconf/profile/user)
- **Mécanisme** : base dconf « local » compilée par `dconf update` au build ; profil utilisateur
  = `user-db:user` puis `system-db:local` (défauts surchargables sauf si verrouillés). Clés
  posées : extension **AppIndicator** (tray kDrive), claviers suisses FR/DE, fond d'écran SZH
  clair/sombre (`zoom`, `primary-color #252b46`), écran de verrouillage, Nautilus
  (`executable-text-activation='ask'`, `date-time-format='detailed'`), GNOME Software
  (`download-updates`/`-notify=true`).

### I2. Clés verrouillées (politique imposée)
- **Fichier** : [locks/00-fleet-locks](system_files/etc/dconf/db/local.d/locks/00-fleet-locks)
- **Mécanisme** : l'utilisateur ne peut PAS modifier : verrouillage auto de session
  (`screensaver/lock-enabled`, `lock-delay`), extinction écran (`session/idle-delay=600`),
  format date Nautilus, MAJ auto GNOME Software. Empêche de neutraliser le verrouillage écran.

### I3. Fond d'écran & assets SZH
- **Fichiers** : [backgrounds/szh/](system_files/usr/share/backgrounds/szh/) (dark/light PNG),
  [gnome-background-properties/szh.xml](system_files/usr/share/gnome-background-properties/szh.xml)
- **Mécanisme** : PNG 16:9 3840×2160 (marges autour du logo → rognage sûr en 16:10) ;
  `szh.xml` les déclare dans le sélecteur de fonds GNOME.

### I4. Logo GDM (greeter)
- **Fichier** : [gdm.d/01-fleet-logo](system_files/etc/dconf/db/gdm.d/01-fleet-logo)
- **Mécanisme** : base dconf « gdm ». **Actuellement désactivé** (`logo=''`) : l'ancien logo
  Plymouth était trop grand/blanc sur le greeter. Pour réactiver : fournir un PNG dédié
  (~250 px, transparent) dans `/usr/share/szh/gdm-logo.png` et pointer `logo=…`.

---

## J. Localisation & clavier suisse

> Problème central : faire en sorte que l'invite **LUKS/PIN au boot** ET le **greeter GDM**
> soient en clavier suisse (et non QWERTY US), à plusieurs couches (initramfs, console, XKB).

### J1. Console / invite LUKS
- **Fichiers** : [system_files/etc/vconsole.conf](system_files/etc/vconsole.conf) (`KEYMAP=fr_CH`),
  [kargs.d/10-fleet.toml](system_files/usr/lib/bootc/kargs.d/10-fleet.toml) (`rd.vconsole.keymap=fr_CH`)
- **Mécanisme** : le karg charge tôt le keymap dans l'initramfs ; pleinement effectif après
  régénération locale de l'initramfs (J3).

### J2. Greeter GDM / X11
- **Fichier** : [system_files/etc/X11/xorg.conf.d/00-keyboard.conf](system_files/etc/X11/xorg.conf.d/00-keyboard.conf)
- **Mécanisme** : le greeter GDM ne lit PAS le dconf utilisateur → la config XKB système
  (`XkbLayout "ch,ch"`, `XkbVariant "fr,"`) fait foi pour console + écran de connexion.

### J3. Régénération initramfs au 1er boot
- **Fichier** : [fleet-initramfs-localize.service](system_files/usr/lib/systemd/system/fleet-initramfs-localize.service)
- **Mécanisme** : oneshot une seule fois (stamp `initramfs-localized`) → `rpm-ostree initramfs
  --enable` (embarque `vconsole.conf`). On délègue au poste car la régénération **dracut
  échoue dans le build conteneur**. Effet appliqué au reboot suivant (pas de reboot auto).
- **Piège** : tant que la régén n'a pas eu lieu, le keymap initramfs dépend du générique
  Fedora (« à vérifier au boot », cf. commentaire vconsole.conf).

### J4. kargs de boot
- **Fichier** : [kargs.d/10-fleet.toml](system_files/usr/lib/bootc/kargs.d/10-fleet.toml)
- **Mécanisme** : `rhgb quiet` (splash graphique + prompt LUKS graphique) +
  `rd.vconsole.keymap=fr_CH`. Versionne les kargs avec l'image (vs `grubby` poste par poste).
  Note : `mitigations=auto` conservé (commentaire sur l'option `nosmt`).

---

## K. Installation (ISO Anaconda)

### K1. Build d'ISO via bootc-image-builder
- **Fichiers** : [.github/workflows/build-iso.yml](.github/workflows/build-iso.yml),
  [bootc-image-builder/config.toml](bootc-image-builder/config.toml)
- **Mécanisme** : `workflow_dispatch` (choix profil + tag) → pull de l'image publiée →
  `podman run --privileged bootc-image-builder --type anaconda-iso` → ISO en artefact.
  BIB conseillé épinglé par digest.

### K2. Kickstart : chiffrement LUKS + comptes
- **Fichier** : [bootc-image-builder/config.toml](bootc-image-builder/config.toml)
- **Mécanisme** : locale/clavier/timezone en `customizations` structurées ; **tout le reste
  dans un kickstart unique** (`autopart --type btrfs --encrypted --passphrase=changeme` +
  comptes `admin`/`szh-csps` + `rootpw --lock`).
- **Piège** : BIB interdit `[[customizations.user]]` structurés **+** kickstart simultanés
  (erreur « not compatible with user-supplied kickstart »). Comme le chiffrement EXIGE le
  kickstart, comptes & partitionnement sont **tous** dans le kickstart. Type rootfs btrfs aussi
  fixé dans [00-fleet.toml](system_files/usr/lib/bootc/install/00-fleet.toml) (lu par
  `bootc install` ET BIB).

---

## L. Maintenance des versions (Renovate)

- **Fichier** : [.github/renovate.json5](.github/renovate.json5)
- **Mécanisme** : gère en auto **GitHub Actions** (regroupés en 1 PR) + `ARG FEDORA_VERSION`
  du Containerfile (suit les tags `fedora-silverblue`) + le tag fedora de `pipeline.ini`
  (aligné sur la base). `:dependencyDashboard` activé.
- **Hors périmètre auto** : kDrive (versions 4 segments non résolubles → MAJ manuelle, cf. H3).

---

## Annexe 1 — Carte des fichiers

```
Containerfile                       B1  image standard (FROM silverblue:44 → build.sh → lint)
Containerfile.sysadmin              C1  profil sysadmin (FROM standard → build-sysadmin.sh)
README.md                           —   présentation publique courte
cosign.pub                          D1  clé publique cosign (référence)
.gitignore / .github/renovate.json5 L   Renovate

build_files/
  build.sh                          B2  couche système (RPM + services + apps + commit)
  build-sysadmin.sh                 C1  couche additionnelle sysadmin (RPM CLI)
  install-kdrive.sh                 H3  kDrive AppImage + wrapper + lanceur + autostart
  install-veracrypt.sh              H4  RPM VeraCrypt upstream

.github/workflows/
  build.yml                         B3  build + push + signature cosign (cron quotidien)
  build-iso.yml                     K1  ISO Anaconda (manuel, via BIB)

bootc-image-builder/config.toml     K2  locale/clavier + kickstart (LUKS + comptes)

system_files/                           (déposés tels quels sur l'image →  /)
  etc/rpm-ostree.conf               G1  AutomaticUpdatePolicy=stage
  etc/fedora-third-party.conf       H2  dépôts tiers activés (enabled=1)
  etc/vconsole.conf                 J1  KEYMAP=fr_CH (console + LUKS)
  etc/X11/xorg.conf.d/00-keyboard   J2  XKB ch,ch / fr, (greeter GDM)
  etc/containers/policy.json        D2  default reject + signature flotte exigée
  etc/containers/registries.d/…     D2  attachments sigstore
  etc/pki/containers/…pub           D1  clé publique d'imposition cosign
  etc/dconf/profile/user            I1  ordre user-db puis system-db:local
  etc/dconf/db/local.d/00-…         I1  défauts GNOME (clavier, fond, lock, nautilus…)
  etc/dconf/db/local.d/locks/00-…   I2  clés verrouillées (lock écran, MAJ auto)
  etc/dconf/db/gdm.d/01-fleet-logo  I4  logo GDM (désactivé)
  etc/greenboot/check/wanted.d/…    G2  health check réseau (non bloquant)
  etc/xdg/autostart/fleet-tpm-…     E2  autostart assistant TPM+PIN
  usr/bin/fleet-provision           E1  provisioning admin post-install
  usr/libexec/fleet-tpm-enroll      E4  CLI admin enrôlement TPM2
  usr/libexec/fleet-tpm-enroll-helper E3 partie root (pkexec)
  usr/libexec/fleet-tpm-pin-setup   E2  assistant graphique 1er login
  usr/libexec/fleet-flatpak-sync    H1  sync Flatpak (union des listes + prune)
  usr/lib/systemd/system/…          E2/F2/G/H1  services & timers flotte
  usr/lib/tmpfiles.d/…-hide-admin   F3  masque admin du greeter
  usr/lib/bootc/install/00-fleet    K2  rootfs btrfs par défaut
  usr/lib/bootc/kargs.d/10-fleet    J4  kargs (rhgb quiet, keymap)
  usr/share/fleet/flatpaks.d/10-…   H1  liste Flatpak standard
  usr/share/fleet/distrobox/…       H5  conteneur pipeline (WeasyPrint+Pandoc)
  usr/share/backgrounds/szh/…       I3  fonds d'écran SZH
  usr/share/polkit-1/actions/…      E3  policy polkit enrôlement
  usr/share/gnome-background-…      I3  déclaration fonds GNOME

system_files_sysadmin/
  usr/share/fleet/flatpaks.d/20-…   C1/H1  liste Flatpak sysadmin
```

---

## Annexe 2 — Stamps & état runtime (`/var/lib/fleet`)

État persistant créé/lu côté poste (sert d'idempotence « une seule fois ») :

| Chemin                              | Posé par                         | Rôle |
|-------------------------------------|----------------------------------|------|
| `enroll.key`                        | `fleet-provision`                | Clé LUKS temporaire (révoquée après enrôlement PIN) |
| `tpm-enrolled`                      | helper / `fleet-tpm-enroll`      | Stamp « enrôlement TPM fait » (l'assistant se tait) |
| `passwd-expired`                    | `fleet-force-passwd-change`      | Stamp « nom d'affichage + expiration pw faits » |
| `initramfs-localized`               | `fleet-initramfs-localize`       | Stamp « initramfs régénéré (clavier suisse) » |
| `flatpaks.state`                    | `fleet-flatpak-sync`             | Dernier ensemble installé (base du prune) |

---

## Annexe 3 — Points ouverts / TODO repérés dans le code

- **`docs/` inexistant** : tous les renvois (`docs/02/04/05/06`, `docs/RESTE-A-FAIRE`) sont
  des liens morts → à reconstituer pendant le redesign.
- **Logo GDM désactivé** (I4) : asset dédié à produire.
- **VeraCrypt** (H4) : RPM Fedora-40 sur base F44 → résolution de deps **non validée**.
- **Keymap initramfs** (J1/J3) : effectif seulement après régén locale ; comportement avant
  régén « à vérifier au boot ».
- **greenboot health check** (G2) : réseau **non bloquant** — décider quels checks passer en
  `required.d/` (bloquants) lors du durcissement.
- **cosign** (D1) : signature conditionnée à `COSIGN_ENABLED=true` — confirmer qu'elle est
  bien activée en prod (sinon `policy.json` rejette les images non signées au déploiement).
- **Déverrouillage TPM2+PIN non fonctionnel** (E) ⚠️ : à ce jour le déverrouillage par PIN
  au boot **ne marche pas** sur les postes (cause à investiguer : keymap/initramfs, PCR 7
  sans Secure Boot, ou parcours d'enrôlement). Repli = phrase de passe LUKS. **À corriger
  plus tard** (décision utilisateur). Pistes : vérifier `systemd-cryptenroll <dev>` (slot
  tpm2 présent ?), Secure Boot activé (PCR 7), et l'invite PIN à l'initramfs.
- **Modifs dconf non commitées** (I1/I2) : MAJ auto GNOME Software + `date-time-format` à
  committer ou réintégrer proprement.
```
