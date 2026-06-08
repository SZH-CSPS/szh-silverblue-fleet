#!/usr/bin/env bash
# =============================================================================
#  install-kdrive.sh — intègre kDrive (Infomaniak) dans l'image.
#  Appelé par build.sh PENDANT le build.
#
#  Stratégie (corrigée) : on NE pré-extrait PLUS l'AppImage dans /usr (lecture seule).
#  kDrive doit pouvoir écrire près de son dossier d'app (sentry + ParmsDB) ; exécuté depuis
#  /usr, il échoue (« sentry_init returned 1 », « Unable to initialize ParmsDB »).
#  On SHIP donc l'AppImage telle quelle, et le wrapper /usr/bin/kdrive l'extrait UNE FOIS
#  par utilisateur dans ~/.cache/kdrive (inscriptible), puis lance AppRun depuis là.
#  Les DONNÉES (compte, ParmsDB, fichiers synchronisés) restent dans $HOME → persistantes ;
#  le cache ne contient que le programme extrait (recréé si l'AppImage de l'image change).
#
#  Si KDRIVE_URL est vide : on ne fait RIEN (aucun lanceur cassé) et on sort 0.
# =============================================================================
set -euo pipefail

: "${KDRIVE_URL:=}"
: "${KDRIVE_VERSION:=}"

if [ -z "${KDRIVE_URL}" ]; then
    echo "kDrive : KDRIVE_URL non fourni → intégration ignorée (image construite sans kDrive)."
    exit 0
fi

# 1. Résoudre l'URL réelle (substitue %VERSION% par la version montée par Renovate).
url="${KDRIVE_URL//%VERSION%/${KDRIVE_VERSION}}"
echo "kDrive : téléchargement de ${url}"

workdir="$(mktemp -d)"
appimage="${workdir}/kDrive.AppImage"
curl -fSL --retry 3 -o "${appimage}" "${url}"
chmod +x "${appimage}"

# 2. Ship l'AppImage telle quelle dans /usr/lib/kdrive (fichier en lecture seule = OK,
#    c'est l'EXTRACTION runtime qui se fera dans un cache inscriptible côté utilisateur).
dest="/usr/lib/kdrive"
rm -rf "${dest}"
mkdir -p "${dest}"
cp "${appimage}" "${dest}/kDrive.AppImage"
chmod 0755 "${dest}/kDrive.AppImage"

# 3. Récupérer l'icône (extraction TEMPORAIRE jetable ; --appimage-extract n'exige pas FUSE).
( cd "${workdir}" && "${appimage}" --appimage-extract >/dev/null ) || true
src="${workdir}/squashfs-root"
icon_dir="/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${icon_dir}"
icon_src="$(find "${src}" -maxdepth 2 \( -iname 'kdrive*.png' \) 2>/dev/null | head -1 || true)"
if [ -z "${icon_src}" ] && [ -f "${src}/.DirIcon" ]; then
    icon_src="${src}/.DirIcon"
fi
if [ -n "${icon_src}" ]; then
    cp "${icon_src}" "${icon_dir}/com.infomaniak.kdrive.png" || true
fi

# 4. Wrapper : extrait l'AppImage une fois par utilisateur dans le cache, puis lance.
cat > /usr/bin/kdrive <<'EOF'
#!/usr/bin/env bash
# Lanceur kDrive. L'app échoue si exécutée depuis /usr (lecture seule) : elle doit pouvoir
# écrire près de son dossier (sentry/ParmsDB). On extrait donc l'AppImage dans un cache
# INSCRIPTIBLE par utilisateur, et on lance depuis là. Les DONNÉES (compte, ParmsDB,
# fichiers synchronisés) sont dans $HOME → persistantes ; ce cache ne contient que le
# programme (recréé automatiquement, y compris après mise à jour de l'image).
set -euo pipefail
APPIMAGE="/usr/lib/kdrive/kDrive.AppImage"
DEST="${XDG_CACHE_HOME:-$HOME/.cache}/kdrive"
APPDIR="${DEST}/squashfs-root"

# (Ré)extraire si absent, ou si l'AppImage de l'image est plus récente que l'extraction.
if [ ! -x "${APPDIR}/AppRun" ] || [ "${APPIMAGE}" -nt "${APPDIR}/AppRun" ]; then
    rm -rf "${DEST}"
    mkdir -p "${DEST}"
    ( cd "${DEST}" && "${APPIMAGE}" --appimage-extract >/dev/null )
fi

exec "${APPDIR}/AppRun" "$@"
EOF
chmod 0755 /usr/bin/kdrive

# 5. Lanceur GNOME (grille d'applications).
cat > /usr/share/applications/com.infomaniak.kdrive.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=kDrive
Comment=Synchronisation kDrive (Infomaniak)
Exec=/usr/bin/kdrive
Icon=com.infomaniak.kdrive
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=true
EOF

# 6. Autostart à l'ouverture de session (comportement attendu d'un client de sync).
cp /usr/share/applications/com.infomaniak.kdrive.desktop \
   /etc/xdg/autostart/com.infomaniak.kdrive.desktop
# Démarrage discret au login (laisse le temps à la session + à la 1re extraction).
echo "X-GNOME-Autostart-Delay=15" >> /etc/xdg/autostart/com.infomaniak.kdrive.desktop

# 7. Nettoyage du dossier temporaire.
rm -rf "${workdir}"
echo "kDrive ${KDRIVE_VERSION} intégré : AppImage dans /usr/lib/kdrive + wrapper (extraction cache) + lanceur + autostart."
