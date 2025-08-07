# Nix shoulbe be loaded before direnv
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    export PATH=/etc/profiles/per-user/${USER}/bin:/run/current-system/sw/bin:${PATH}
fi
# End Nix

export DEFAULT_ANTHROPIC_MODEL="kimi-k2-turbo-preview"

# Smart Suggestion
export SMART_SUGGESTION_AI_PROVIDER="anthropic"
export ANTHROPIC_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapikey.gpg)
export ANTHROPIC_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapianbase.gpg)
export ANTHROPIC_SMALL_FAST_MODEL=${DEFAULT_ANTHROPIC_MODEL}
export ANTHROPIC_MODEL=${DEFAULT_ANTHROPIC_MODEL}
