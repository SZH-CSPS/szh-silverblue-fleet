#!/usr/bin/env bash
# Revert « kargs socle mémoire (20-hardening-base) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/usr/lib/bootc/kargs.d/20-hardening-base.toml'
echo '✓ kargs socle mémoire (20-hardening-base) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): kargs_base" && git push  (puis CI → bootc upgrade)'
