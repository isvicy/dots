# Homebrew must be loaded first before other tools
[[ -s /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || true

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
else
  echo "zoxide missing!"
fi

if command -v fzf >/dev/null 2>&1; then
  # 使用与 kitty 光标一致的粉红色 #e8a0a4
  export FZF_DEFAULT_OPTS='--color=fg:#ffffff,bg:#000000,hl:#e8a0a4 --color=fg+:#ffffff,bg+:#333333,hl+:#e8a0a4 --color=info:#999999,prompt:#e8a0a4,pointer:#e8a0a4 --color=marker:#e8a0a4,spinner:#e8a0a4,header:#666666'
  eval "$(fzf --zsh)"
else
  echo "fzf missing!"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
else
  echo "atuin missing!"
fi

export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# bun completions
[ -s "/Users/moonshot/.bun/_bun" ] && source "/Users/moonshot/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
