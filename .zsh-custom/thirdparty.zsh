if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

export PNPM_HOME="${HOME}/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
