#!/usr/bin/env bash
# Revert « perf_event_paranoid=3 (93-fleet-perf) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/sysctl.d/93-fleet-perf.conf'
echo '✓ perf_event_paranoid=3 (93-fleet-perf) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): perf_event" && git push  (puis CI → bootc upgrade)'
