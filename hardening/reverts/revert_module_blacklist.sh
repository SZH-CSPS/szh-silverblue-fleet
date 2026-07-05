#!/usr/bin/env bash
# Revert « blacklist de modules noyau (modprobe.d) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/modprobe.d/90-fleet-blacklist.conf'
echo '✓ blacklist de modules noyau (modprobe.d) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): module_blacklist" && git push  (puis CI → bootc upgrade)'
