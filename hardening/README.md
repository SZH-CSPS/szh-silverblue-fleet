# Durcissement de la flotte — matrice, sources & reverts

> **Origine.** Mesures reprises de [secureblue](https://secureblue.dev/features), filtrées
> pour une flotte d'entreprise (décisions du 2026-07-05). Chaque mesure = **1 fichier (ou
> 1 bloc marqué) = 1 script de revert**.
>
> **Procédure de revert (toujours la même)** :
> ```bash
> ./hardening/reverts/revert_<feature>.sh   # modifie le DÉPÔT
> git commit -m "revert(hardening): <feature>" && git push
> # → CI rebuild → sur les postes : sudo bootc upgrade && systemctl reboot
> ```
> Les blocs dans les `build.sh` sont délimités par `# >>> fleet-hardening: <nom> >>>` /
> `# <<< … <<<` — ne pas éditer ces marqueurs (les scripts de revert s'en servent).

## Matrice des mesures actives

| Mesure | Fichier(s) | Effet | Source secureblue | Revert |
|---|---|---|---|---|
| Sysctl réseau | `common/…/etc/sysctl.d/91-fleet-network.conf` | anti-spoof/redirect/SYN-flood | [55-hardening.conf](https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/sysctl.d/55-hardening.conf) | `revert_sysctl_network.sh` |
| Sysctl noyau | `…/92-fleet-kernel.conf` | io_uring off, kexec off, ASLR max, core off | idem | `revert_sysctl_kernel.sh` |
| perf_event root-only | `…/93-fleet-perf.conf` | anti side-channel (gêne : profiling non-root) | idem | `revert_perf_event.sh` |
| **Ping bloqué** | `…/94-fleet-noping.conf` | ne répond plus au ping v4/v6 | idem | `revert_ping_block.sh` |
| Blacklist modules | `common/…/etc/modprobe.d/90-fleet-blacklist.conf` | ~100 modules bloqués (protos exotiques, firewire, FS morts, DVB, CAN…) | [secureblue.conf](https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/modprobe.d/secureblue.conf) | `revert_module_blacklist.sh` |
| Kargs socle mémoire | `common/…/usr/lib/bootc/kargs.d/20-hardening-base.toml` | init_on_alloc/free, slab_nomerge, vsyscall=none… (~1 % CPU) | [articles/kargs](https://secureblue.dev/articles/kargs) | `revert_kargs_base.sh` |
| **Lockdown** | `…/21-hardening-lockdown.toml` | `lockdown=confidentiality` (⚠️ pas d'hibernation, pas de ZFS/module non signé, debug noyau restreint) | idem | `revert_kargs_lockdown.sh` |
| **slab_debug=FZ** | `…/22-hardening-slab-debug.toml` | détection corruption heap noyau (⚠️ qq % perf) | idem | `revert_kargs_slab_debug.sh` |
| **rd.shell=0** | `…/23-hardening-rdshell.toml` | pas de shell initramfs (⚠️ dépannage pré-boot via GRUB `e` uniquement) | idem | `revert_kargs_rdshell.sh` |
| Firewall deny-by-default | `common/…/etc/firewalld/zones/FedoraWorkstation.xml` | tout fermé sauf DHCPv6, mDNS, Syncthing (Fedora ouvre 1025-65535 par défaut !) | [features](https://secureblue.dev/features) | `revert_firewall.sh` |
| MAC randomization Wi-Fi | `common/…/etc/NetworkManager/conf.d/90-fleet-mac-randomization.conf` | scan aléatoire + MAC stable par SSID (Ethernet non touché) | [NM conf.d](https://github.com/secureblue/secureblue/tree/live/files/system/etc/NetworkManager/conf.d) | `revert_mac_randomization.sh` |
| faillock 50/24h | `common/…/etc/security/faillock.conf` + blocs `faillock` (build.sh) | verrou 24 h après 50 échecs (reset : `faillock --user X --reset`) | [features](https://secureblue.dev/features) | `revert_faillock.sh` |
| chrony NTS | `common/…/etc/chrony.d/90-fleet-nts.sources` + blocs `chrony-nts` | heure authentifiée (Cloudflare, Netnod, PTB) ; pool Fedora en secours | [chrony.conf](https://github.com/secureblue/secureblue/blob/live/files/system/etc/chrony.conf) | `revert_chrony_nts.sh` |
| **hardened_malloc** | `common/…/etc/ld.so.preload` + `etc/yum.repos.d/secureblue-packages.repo` + blocs `hardened_malloc` | allocateur durci GrapheneOS préchargé partout (host ; pas les Flatpaks) | [features](https://secureblue.dev/features) · [GrapheneOS/hardened_malloc](https://github.com/GrapheneOS/hardened_malloc) | `revert_hardened_malloc.sh` |
| passim masqué | blocs `passim` (build.sh) | service réseau LAN fwupd inutile → off | [features](https://secureblue.dev/features) | `revert_passim.sh` |

## Écarts volontaires vs secureblue (NE PAS reprendre sans réflexion)

| Mesure secureblue | Pourquoi exclue chez nous |
|---|---|
| `mitigations=auto,nosmt`, `nosmt=force` | –20/30 % perf multithread |
| Blacklist bluetooth / thunderbolt | casques/souris ; docks ThinkPad |
| Blacklist nfs/cifs/sunrpc, xfrm/esp (IPsec), l2tp | montages réseau / VPN d'entreprise potentiels |
| `iommu=force` + `intel_iommu=on` | **en attente** : à tester avec les docks avant adoption |
| `module.sig_enforce=1` | couvert par lockdown ; et casserait ZFS (banc) explicitement |
| `fs.binfmt_misc=0` | casse les builds multi-arch qemu (profil admin) |
| `tcp_timestamps=0`, IPv6 `use_tempaddr=2` | impact inventaire réseau IT — à discuter |
| Unbound + DNS-over-TLS | casserait le DNS interne / split-horizon |
| Xwayland désactivé | kDrive (Qt) et Flatpaks encore X11 |
| run0 à la place de sudo, purge SUID | changerait les workflows admin — phase ultérieure |
| Verrouillage permissions Flatpak | casse des apps au cas par cas — phase ultérieure |
| `debugfs=off`, `oops=panic`, `ia32_emulation=0` | classés « unstable » par secureblue eux-mêmes |

## Points de vigilance après déploiement

1. **hardened_malloc** = la mesure la plus susceptible de casser une app (c'est LA raison
   du script de revert dédié). Symptômes : crash au lancement, `SIGABRT` mémoire. Test
   rapide d'imputation : `LD_PRELOAD= /chemin/app` (préload désactivé pour ce process).
2. **faillock** : un utilisateur verrouillé → `sudo faillock --user <user> --reset`.
3. **rd.shell=0** : pour déboguer un boot cassé, éditer les kargs à l'invite GRUB (`e`),
   supprimer `rd.shell=0 rd.emergency=halt` pour la session.
4. **Lockdown vs ZFS (banc)** : documenté dans `images/szh-backup-verify/build.sh`.
5. **kargs.d sur postes EXISTANTS** : bootc applique les diffs kargs.d à l'upgrade ; si un
   poste ne les reçoit pas (`cat /proc/cmdline`), les poser à la main :
   `sudo rpm-ostree kargs --append=<karg>` (liste dans les .toml).
6. **NTS** : nécessite 4460/tcp sortant. Si l'horloge dérive (réseau ultra-fermé),
   `chronyc sources -v` pour vérifier, revert sinon.
7. **COPR secureblue/packages** : dépendance de build EXTERNE (hardened_malloc). Si le
   COPR est indisponible, le build CI échoue (`skip_if_unavailable=False`, volontaire :
   échec bruyant plutôt qu'image silencieusement non durcie). Amélioration possible :
   épingler la clé GPG dans l'image comme secureblue (`/usr/share/pki/rpm-gpg/`).

## Maintenance / veille

- Références amont à re-consulter périodiquement (évolutions des recommandations) :
  [features](https://secureblue.dev/features) · [kargs](https://secureblue.dev/articles/kargs) ·
  [sysctl](https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/sysctl.d/55-hardening.conf) ·
  [modprobe](https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/modprobe.d/secureblue.conf)
- Renovate ne suit PAS ces fichiers (configs statiques) → revue manuelle conseillée
  ~2×/an, ou à chaque montée de version Fedora majeure.
