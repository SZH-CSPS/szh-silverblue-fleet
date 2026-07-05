#!/usr/bin/env bash
# Revert « verrouillage anti-bruteforce faillock 50/24h »
# Retire la mesure du DÉPÔT (fichiers + blocs marqués dans les build.sh).
# Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/security/faillock.conf'
for b in images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh; do
  sed -i '/# >>> fleet-hardening: faillock >>>/,/# <<< fleet-hardening: faillock <<</d' "$b"
done
git add images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh
echo '✓ verrouillage anti-bruteforce faillock 50/24h : retiré du dépôt (fichiers + blocs build.sh).'
echo '→ git commit -m "revert(hardening): faillock" && git push  (puis CI → bootc upgrade)'
