# Nix shoulbe be loaded before direnv
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    export PATH=/etc/profiles/per-user/${USER}/bin:/run/current-system/sw/bin:${PATH}
fi
# End Nix
