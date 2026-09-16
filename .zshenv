# Sourced for every zsh, including non-interactive SSH commands (`ssh host mosh-server`).
# Interactive setup stays in .zshrc; keep this file minimal and side-effect free
# (no pass, no subprocess calls — it runs for every zsh invocation).
typeset -U path

# Homebrew (macOS)
[ -d /opt/homebrew/bin ] && path=(/opt/homebrew/bin /opt/homebrew/sbin $path)

# home-manager standalone profile (plain Linux)
[ -d "$HOME/.nix-profile/bin" ] && path=("$HOME/.nix-profile/bin" $path)

# user toolchain: local bins + proto (proto must outrank nix-profile so
# .prototools version pins apply)
path=("$HOME/.local/bin" "$HOME/.proto/shims" "$HOME/.proto/bin" $path)

# pnpm global bins (claude/codex etc.)
export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$PNPM_HOME" $path)
