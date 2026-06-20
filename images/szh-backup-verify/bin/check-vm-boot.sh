#!/usr/bin/env bash
# Démarre une VM restaurée et vérifie qu'elle atteint un état systemd sain.
# Usage : check-vm-boot.sh <nom-vm> <ip>
set -euo pipefail
VM="${1:?usage: $0 <nom-vm> <ip>}"; IP="${2:?}"
virsh start "$VM"
for i in $(seq 1 60); do ssh -o ConnectTimeout=3 "tester@$IP" true 2>/dev/null && break; sleep 5; done
state=$(ssh "tester@$IP" systemctl is-system-running 2>/dev/null || true)
echo "État systemd invité: $state"
[[ "$state" == running || "$state" == degraded ]] && echo "VM OK" || { echo "VM KO"; exit 1; }
