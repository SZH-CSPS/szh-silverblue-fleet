#!/usr/bin/env bash
# Vérifie une instance Immich restaurée (ping + version + nombre d'assets).
# ⚠️ ADAPTER les endpoints à ta version d'Immich (cf. sa doc API).
# Usage : check-immich.sh <http://ip:2283> <api-key> <attendu>
set -euo pipefail
BASE="${1:?usage: $0 <http://ip:2283> <api-key> <attendu>}"; KEY="${2:?}"; EXPECTED="${3:?}"
curl -fsS "$BASE/api/server/ping"    >/dev/null && echo "ping OK"
curl -fsS "$BASE/api/server/version" | jq -r .
count=$(curl -fsS -H "x-api-key: $KEY" "$BASE/api/assets/statistics" | jq '.total // (.images + .videos)')
echo "assets: $count (attendu $EXPECTED)"
[ "$count" -ge "$EXPECTED" ] && echo "Immich OK" || { echo "Immich KO"; exit 1; }
