# Documentation — `szh-silverblue-fleet`

Index de la doc de la flotte. Les **sources de vérité** restent le code commenté +
[FEATURES.md](../FEATURES.md) (inventaire) et [REDESIGN.md](../REDESIGN.md) (architecture
cible + décisions). Ces pages développent les sujets référencés dans les commentaires du code.

| Doc | Sujet |
|---|---|
| [02-ci-renovate.md](02-ci-renovate.md) | Build CI, publication, signature cosign, Renovate |
| [04-applications.md](04-applications.md) | Matrice des applications (Flatpak / RPM / distrobox), kDrive, coffres LUKS |
| [05-iso-installation.md](05-iso-installation.md) | ISO d'installation, `bootc install`, kickstart LUKS |
| [06-securite.md](06-securite.md) | Durcissement, signatures, LUKS/TPM/PIN, greenboot, USBGuard, **migration des postes** |
| [runbook-backup-verify.md](runbook-backup-verify.md) | Banc de vérif. backups : runbook d'une campagne |
| [RESTE-A-FAIRE.md](RESTE-A-FAIRE.md) | Points ouverts / à valider (miroir de TODO.md) |

## Architecture en une phrase
Un **noyau source commun** (`common/`) + **deux familles d'images** : *desktop* (Silverblue →
`szh-silverblue-desktop` → `szh-silverblue-admin`) et *appliance* (`fedora-bootc` →
`szh-backup-verify`). Build/signature/déploiement en image mode (bootc), rollback en un reboot.
