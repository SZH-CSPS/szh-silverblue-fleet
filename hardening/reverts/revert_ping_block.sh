#!/usr/bin/env bash
# Revert « blocage du ping (94-fleet-noping) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/sysctl.d/94-fleet-noping.conf'
echo '✓ blocage du ping (94-fleet-noping) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): ping_block" && git push  (puis CI → bootc upgrade)'
