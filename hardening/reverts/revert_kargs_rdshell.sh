#!/usr/bin/env bash
# Revert « rd.shell=0 + rd.emergency=halt (23-hardening-rdshell) — si debug initramfs requis »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/usr/lib/bootc/kargs.d/23-hardening-rdshell.toml'
echo '✓ rd.shell=0 + rd.emergency=halt (23-hardening-rdshell) — si debug initramfs requis : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): kargs_rdshell" && git push  (puis CI → bootc upgrade)'
