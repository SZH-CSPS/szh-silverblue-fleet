#!/usr/bin/env bash
# Revert « randomisation MAC Wi-Fi (NetworkManager) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/NetworkManager/conf.d/90-fleet-mac-randomization.conf'
echo '✓ randomisation MAC Wi-Fi (NetworkManager) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): mac_randomization" && git push  (puis CI → bootc upgrade)'
