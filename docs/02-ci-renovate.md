# 02 — CI, publication & Renovate

## Build & push ([.github/workflows/build.yml](../.github/workflows/build.yml))
- Déclencheurs : push `main` (hors `docs/**` / `**.md`), **cron quotidien 05:00 UTC**
  (correctifs Fedora), `workflow_dispatch`.
- **Contexte de build = racine du dépôt** (les Containerfiles font `COPY common/` ET
  `COPY images/<x>/`). Chaque image : `containerfiles: ./images/<x>/Containerfile`, `context: .`.
- Ordre : `szh-silverblue-desktop` (buildah) → `szh-silverblue-admin`
  (`BASE=localhost/szh-silverblue-desktop:latest` → couches identiques) → `szh-backup-verify`
  (`fedora-bootc`). Puis push des 3, puis signature.
- **Tags** : `latest`, `<sha>`, et tag daté `<fedora>.<AAAAMMJJ>` (épinglage / rollback ciblé).
- Concurrence `build-push`, `cancel-in-progress: false` (sérialise push + cron).

## Signature cosign (par clé)
- Activée par la variable de dépôt `COSIGN_ENABLED=true` + secrets `SIGNING_SECRET` /
  `SIGNING_SECRET_PASSWORD`. On signe le **digest** retourné par le push (pas de course).
- Vérification côté poste : [policy.json](../common/system_files/etc/containers/policy.json)
  (`keyPath` = clé publique embarquée) — voir [06-securite.md](06-securite.md).
- ⚠️ Si `policy.json` impose la signature mais que `COSIGN_ENABLED` est faux → les images non
  signées sont **rejetées au déploiement**. Garder les deux cohérents.

## Renovate ([.github/renovate.json5](../.github/renovate.json5))
- Auto : GitHub Actions (groupées) ; `ARG FEDORA_VERSION` du Containerfile desktop
  (suit `fedora-silverblue`) ; `FROM fedora-bootc:<n>` du banc ; tag `fedora` de
  `pipeline.ini` (distrobox).
- **MAJ manuelle** : kDrive (`KDRIVE_VERSION`, 4 segments non résolubles par Renovate).

## Registre auto-hébergé (option)
Bloc commenté en bas de `build.yml` : pointer `IMAGE_REGISTRY` sur une instance Forgejo +
login par secrets dédiés.
