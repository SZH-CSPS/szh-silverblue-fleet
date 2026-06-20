# 05 — ISO d'installation & `bootc install`

## Desktop / admin : ISO Anaconda (bootc-image-builder)
- Workflow manuel [build-iso.yml](../.github/workflows/build-iso.yml) (`workflow_dispatch`,
  choix `szh-silverblue-desktop` / `szh-silverblue-admin`) → pull de l'image publiée →
  `bootc-image-builder --type anaconda-iso` → ISO en artefact.
- Config : [bootc-image-builder/config.toml](../bootc-image-builder/config.toml).
  - Locale/clavier/timezone : Suisse (`fr_CH`/`de_CH`, `ch(fr)`, `Europe/Zurich`).
  - **Chiffrement LUKS** : EXIGE un kickstart (BIB ne chiffre pas nativement) → tout est dans
    le kickstart : `autopart --type btrfs --encrypted --passphrase=changeme` + comptes
    (`admin` wheel+SSH, `szh-csps` non privilégié) + `rootpw --lock`.
  - ⚠️ BIB interdit `[[customizations.user]]` structurés **+** kickstart simultanés → comptes
    et partitionnement TOUS dans le kickstart.
- Passphrase d'amorçage `changeme` (publique) → changée au 1er login via
  [`fleet-provision`](06-securite.md) ; mots de passe = hash de `changeme` → expirés au 1er login.

## Banc backup-verify : `bootc install to-disk`
- Headless, pas de comptes desktop → pas le kickstart ci-dessus. Installer depuis un live USB :
  réseau actif à l'install, machine hors-ligne ensuite.
- Définir les identifiants à l'install (ex. `--root-ssh-authorized-keys`, ou mot de passe du
  compte `tester`). La signature + le rollback restent acquis.
- `memtest86+` une nuit au 1er démarrage (corruption silencieuse). Voir
  [runbook-backup-verify.md](runbook-backup-verify.md).

## Type de système de fichiers racine
[usr/lib/bootc/install/00-fleet.toml](../images/szh-silverblue-desktop/system_files/usr/lib/bootc/install/00-fleet.toml)
fixe `btrfs` (lu par `bootc install` ET BIB).
