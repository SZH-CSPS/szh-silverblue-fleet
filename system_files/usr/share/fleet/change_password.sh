#!/usr/bin/env bash
# change_password.sh — rotation des secrets initiaux (TPM + LUKS + mot de passe admin).
# Déposé à la racine du home d'admin. À lancer une fois (terminal ou double-clic).
#
# =====================================================================================
#   VARIABLES (en clair) — remplis-les pour un fonctionnement NON interactif.
#   Laisse "" pour que le script demande la valeur au moment voulu.
# =====================================================================================
PASSADMIN=""        # nouveau mot de passe admin,  ex : PASSADMIN="toto1234"
PASSLUKS=""         # nouvelle passphrase LUKS,     ex : PASSLUKS="MaPhraseLUKS"
# =====================================================================================
# Options possibles en plus (passées aussi en ligne de commande) :
#   --enrolltpm   : enrôle seulement le TPM        --notpm : saute l'étape TPM
#   --help        : aide complète
# Sécurité : ce fichier est en lecture seule pour admin (0700). Un secret écrit ici reste
# visible de quiconque peut lire le fichier — efface-le après usage si besoin.

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
    # Aucun terminal trouvé : on continue (utile si tout est non interactif).
fi

# --- Construit les arguments à partir des variables, puis lance le moteur ----
args=()
[ -n "${PASSLUKS}" ]  && args+=("--luks=${PASSLUKS}")
[ -n "${PASSADMIN}" ] && args+=("--admin=${PASSADMIN}")
exec /usr/libexec/fleet-rotate-secrets "${args[@]}" "$@"
