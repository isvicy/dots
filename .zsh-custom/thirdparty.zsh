if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
else
    echo "zoxide missing!"
fi

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
else
    echo "fzf missing!"
fi

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
else
    echo "atuin missing!"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
else
    echo "direnv missing!"
fi

export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

[[ -s /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || true
