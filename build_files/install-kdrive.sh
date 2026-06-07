#!/usr/bin/env bash
# =============================================================================
#  install-kdrive.sh — intègre NATIVEMENT kDrive (Infomaniak) dans l'image.
#  Appelé par build.sh PENDANT le build. Voir docs/04-applications.md.
#
#  Stratégie (sans FUSE, sans MAJ runtime — la version est figée par l'image) :
#    - télécharger l'AppImage (URL = motif KDRIVE_URL avec %VERSION% → KDRIVE_VERSION)
#    - la PRÉ-EXTRAIRE dans /usr/lib/kdrive  (--appimage-extract, pas de FUSE)
#    - wrapper /usr/bin/kdrive  → lance AppRun
#    - lanceur GNOME + autostart de session + icône
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

# 2. Pré-extraction (génère squashfs-root/). --appimage-extract n'exige pas FUSE.
( cd "${workdir}" && "${appimage}" --appimage-extract >/dev/null )
src="${workdir}/squashfs-root"

# 3. Installer le contenu extrait sous /usr/lib/kdrive.
dest="/usr/lib/kdrive"
rm -rf "${dest}"
mkdir -p "${dest}"
cp -a "${src}/." "${dest}/"

# 4. Wrapper exécutable dans le PATH.
cat > /usr/bin/kdrive <<'EOF'
#!/usr/bin/env bash
# Lanceur natif de kDrive (AppImage pré-extraite dans /usr/lib/kdrive).
exec /usr/lib/kdrive/AppRun "$@"
EOF
chmod 0755 /usr/bin/kdrive

# 5. Icône : récupérer celle de l'AppImage, sinon le .DirIcon.
icon_dir="/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${icon_dir}"
icon_src="$(find "${src}" -maxdepth 2 -name 'kdrive*.png' -o -maxdepth 2 -name 'kDrive*.png' 2>/dev/null | head -1 || true)"
if [ -z "${icon_src}" ] && [ -f "${src}/.DirIcon" ]; then
    icon_src="${src}/.DirIcon"
fi
if [ -n "${icon_src}" ]; then
    cp "${icon_src}" "${icon_dir}/com.infomaniak.kdrive.png" || true
fi

# 6. Lanceur GNOME (grille d'applications).
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

# 7. Autostart à l'ouverture de session (comportement attendu d'un client de sync).
cp /usr/share/applications/com.infomaniak.kdrive.desktop \
   /etc/xdg/autostart/com.infomaniak.kdrive.desktop
# Démarrage discret au login.
echo "X-GNOME-Autostart-Delay=10" >> /etc/xdg/autostart/com.infomaniak.kdrive.desktop

# 8. Nettoyage du dossier temporaire.
rm -rf "${workdir}"
echo "kDrive ${KDRIVE_VERSION} intégré : /usr/lib/kdrive + /usr/bin/kdrive + lanceur + autostart."
