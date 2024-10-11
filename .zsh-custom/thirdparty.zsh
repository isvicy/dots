if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)"
else
  echo "zoxide missing!"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
else
  echo "atuin missing!"
fi

# Shell integrations
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
else
  echo "fzf missing!"
fi

export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
