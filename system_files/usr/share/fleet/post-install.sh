#!/usr/bin/env bash
# post-install.sh — post-installation SZH/CSPS (TPM + LUKS + mot de passe admin + initramfs).
# Déposé à la racine du home d'admin. À lancer une fois (terminal ou double-clic).
#
# =====================================================================================
#   VARIABLES (en clair) — remplis-les pour un fonctionnement NON interactif.
#   Laisse "" pour que le script demande la valeur au moment voulu.
# =====================================================================================
PASSADMIN=""        # nouveau mot de passe admin,  ex : PASSADMIN="toto1234"
PASSLUKS=""         # nouvelle passphrase LUKS,     ex : PASSLUKS="MaPhraseLUKS"
# =====================================================================================
# Options en plus (aussi en ligne de commande) :
#   --enrolltpm   : enrôle seulement le TPM        --notpm : saute l'étape TPM
#   --help        : aide complète
# Sécurité : fichier en 0700 (admin seul). Un secret écrit ici reste lisible par admin.

# --- Relance dans un terminal si double-cliqué (pas de tty attaché) ----------
if { [ ! -t 0 ] || [ ! -t 1 ]; } && [ -z "${FLEET_IN_TERM:-}" ]; then
    for term in ptyxis kgx gnome-terminal konsole xterm; do
        if command -v "${term}" >/dev/null 2>&1; then
            case "${term}" in
                ptyxis|kgx|gnome-terminal) exec "${term}" -- env FLEET_IN_TERM=1 bash "$0" "$@" ;;
                konsole|xterm)             exec "${term}" -e env FLEET_IN_TERM=1 bash "$0" "$@" ;;
            esac
        fi
    done
fi

# --- Construit les arguments à partir des variables, puis lance le moteur ----
args=()
[ -n "${PASSLUKS}" ]  && args+=("--luks=${PASSLUKS}")
[ -n "${PASSADMIN}" ] && args+=("--admin=${PASSADMIN}")
exec /usr/libexec/fleet-rotate-secrets "${args[@]}" "$@"
