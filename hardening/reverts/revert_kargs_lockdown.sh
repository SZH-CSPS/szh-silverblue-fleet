#!/usr/bin/env bash
# Revert « lockdown=confidentiality (21-hardening-lockdown) — requis pour ZFS banc »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/usr/lib/bootc/kargs.d/21-hardening-lockdown.toml'
echo '✓ lockdown=confidentiality (21-hardening-lockdown) — requis pour ZFS banc : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): kargs_lockdown" && git push  (puis CI → bootc upgrade)'
