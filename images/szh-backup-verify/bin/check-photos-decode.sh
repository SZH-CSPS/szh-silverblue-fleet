#!/usr/bin/env bash
# Décode chaque image d'un dossier monté en RO ; liste les KO. Le plus universel
# (indépendant d'Immich). Usage : check-photos-decode.sh <dossier>
set -euo pipefail
ROOT="${1:?usage: $0 <dossier>}"
fail=0
while IFS= read -r -d '' f; do
  magick identify -- "$f" >/dev/null 2>&1 || { echo "KO: $f"; fail=1; }
done < <(find "$ROOT" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
         -o -iname '*.png' -o -iname '*.heic' \) -print0)
[ "$fail" -eq 0 ] && echo "OK: toutes les images décodent."
exit "$fail"
