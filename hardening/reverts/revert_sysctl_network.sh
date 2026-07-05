#!/usr/bin/env bash
# Revert « sysctl réseau (91-fleet-network) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/sysctl.d/91-fleet-network.conf'
echo '✓ sysctl réseau (91-fleet-network) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): sysctl_network" && git push  (puis CI → bootc upgrade)'
