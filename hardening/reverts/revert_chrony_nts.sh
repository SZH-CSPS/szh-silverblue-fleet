#!/usr/bin/env bash
# Revert « heure authentifiée NTS (chrony) »
# Retire la mesure du DÉPÔT (fichiers + blocs marqués dans les build.sh).
# Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/chrony.d/90-fleet-nts.sources'
for b in images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh; do
  sed -i '/# >>> fleet-hardening: chrony-nts >>>/,/# <<< fleet-hardening: chrony-nts <<</d' "$b"
done
git add images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh
echo '✓ heure authentifiée NTS (chrony) : retiré du dépôt (fichiers + blocs build.sh).'
echo '→ git commit -m "revert(hardening): chrony_nts" && git push  (puis CI → bootc upgrade)'
