#!/usr/bin/env bash
# Revert « firewall deny-by-default (zone FedoraWorkstation) — retour au défaut Fedora »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/firewalld/zones/FedoraWorkstation.xml'
echo '✓ firewall deny-by-default (zone FedoraWorkstation) — retour au défaut Fedora : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): firewall" && git push  (puis CI → bootc upgrade)'
