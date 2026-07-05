#!/usr/bin/env bash
# Revert « hardened_malloc (préload global + COPR) »
# Retire la mesure du DÉPÔT (fichiers + blocs marqués dans les build.sh).
# Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/yum.repos.d/secureblue-packages.repo'
for b in images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh; do
  sed -i '/# >>> fleet-hardening: hardened_malloc >>>/,/# <<< fleet-hardening: hardened_malloc <<</d' "$b"
done
git add images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh
echo '✓ hardened_malloc (préload global + COPR) : retiré du dépôt (fichiers + blocs build.sh).'
echo '→ git commit -m "revert(hardening): hardened_malloc" && git push  (puis CI → bootc upgrade)'
