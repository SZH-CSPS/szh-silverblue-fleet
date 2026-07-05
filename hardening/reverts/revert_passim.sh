#!/usr/bin/env bash
# Revert « masquage du service passim » — retire le bloc marqué du build.sh desktop.
# Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
for b in images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh; do
  sed -i '/# >>> fleet-hardening: passim >>>/,/# <<< fleet-hardening: passim <<</d' "$b"
done
git add images/szh-silverblue-desktop/build.sh images/szh-backup-verify/build.sh
echo '✓ passim : masquage retiré du dépôt.'
echo '→ git commit -m "revert(hardening): passim" && git push  (puis CI → bootc upgrade)'
