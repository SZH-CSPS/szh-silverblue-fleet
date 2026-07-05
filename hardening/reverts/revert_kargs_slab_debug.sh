#!/usr/bin/env bash
# Revert « slab_debug=FZ (22-hardening-slab-debug) — si perte de perf »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/usr/lib/bootc/kargs.d/22-hardening-slab-debug.toml'
echo '✓ slab_debug=FZ (22-hardening-slab-debug) — si perte de perf : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): kargs_slab_debug" && git push  (puis CI → bootc upgrade)'
