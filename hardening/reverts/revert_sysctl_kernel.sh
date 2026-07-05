#!/usr/bin/env bash
# Revert « sysctl noyau (92-fleet-kernel : io_uring, kexec, ASLR…) »
# Retire la mesure du DÉPÔT. Ensuite : commit + push → CI rebuild → sudo bootc upgrade + reboot.
# Documentation & lien secureblue : hardening/README.md
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git rm -f 'common/system_files/etc/sysctl.d/92-fleet-kernel.conf'
echo '✓ sysctl noyau (92-fleet-kernel : io_uring, kexec, ASLR…) : retiré du dépôt.'
echo '→ git commit -m "revert(hardening): sysctl_kernel" && git push  (puis CI → bootc upgrade)'
