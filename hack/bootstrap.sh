#!/bin/bash
#
# Unified bootstrap for all platforms: macOS, NixOS, Ubuntu/Debian.
#
# Usage:
#   GITHUB_USERNAME=isvicy bash bootstrap.sh
#
# Or curl-pipe:
#   curl -fsSL https://raw.githubusercontent.com/<user>/dots/main/hack/bootstrap.sh | \
#     GITHUB_USERNAME=isvicy bash

set -euo pipefail

GITHUB_USERNAME="${GITHUB_USERNAME:-isvicy}"
DOTS_REPO="$HOME/.dots"
DOTS_PRIVATE_REPO="$HOME/.dots-private"
NIX_REPO="$HOME/nix"
OS="$(uname -s)"

# ── Helpers ──────────────────────────────────────────────────────────────────

info() { printf '\033[1;34m→\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" &>/dev/null || return 1
}

clone_if_missing() {
  local repo=$1 dest=$2
  if [[ -d "$dest" ]]; then
    info "$dest already exists, skipping clone"
    return 0
  fi
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
    git clone --recurse-submodules "git@github.com:${GITHUB_USERNAME}/${repo}.git" "$dest"
}

# ── SSH connectivity ─────────────────────────────────────────────────────────
# Test GitHub SSH access via `ssh -T`. This works with any SSH agent
# (1Password, gpg-agent, ssh-agent, etc.) — no key files required.

ensure_github_ssh() {
  info "Testing GitHub SSH access..."
  local ssh_output
  ssh_output="$(ssh -T git@github.com 2>&1 || true)"
  if echo "$ssh_output" | grep -q "successfully authenticated"; then
    info "GitHub SSH access OK"
    return 0
  fi

  # If agent-based auth failed, try WSL key copy as fallback
  if [[ "$OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    info "Trying to copy SSH key from Windows..."
    local win_home downloads
    win_home="$(cd /mnt/c && cmd.exe /c "echo %HOMEDRIVE%%HOMEPATH%" 2>/dev/null | sed 's/\r$//')"
    downloads="$(wslpath "$win_home")/Downloads"
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if [[ -f "$downloads/id_ed25519" ]]; then
      install -m 600 "$downloads/id_ed25519" ~/.ssh/id_ed25519
    elif [[ -f "$downloads/id_ed25519.txt" ]]; then
      install -m 600 "$downloads/id_ed25519.txt" ~/.ssh/id_ed25519
    fi
    if [[ -f ~/.ssh/id_ed25519 ]]; then
      eval "$(ssh-agent -s)"
      ssh-add ~/.ssh/id_ed25519
      ssh_output="$(ssh -T git@github.com 2>&1 || true)"
      if echo "$ssh_output" | grep -q "successfully authenticated"; then
        info "GitHub SSH access OK (via WSL key)"
        return 0
      fi
    fi
  fi

  err "Cannot authenticate to GitHub via SSH.
  Ensure one of:
    - 1Password SSH agent is configured (macOS)
    - ssh-agent has your key loaded
    - ~/.ssh/id_ed25519 exists
  Then retry."
}

# ── Platform prerequisites ───────────────────────────────────────────────────

install_nix() {
  need_cmd nix && return 0
  info "Installing Nix..."
  sh <(curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install) --daemon --yes
  # Source nix in current shell
  if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

install_homebrew() {
  need_cmd brew && return 0
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

install_just() {
  need_cmd just && return 0
  info "Installing just..."
  if need_cmd brew; then
    brew install just
  elif need_cmd nix; then
    nix profile install nixpkgs#just --extra-experimental-features 'nix-command flakes'
  else
    err "Cannot install just: neither brew nor nix available"
  fi
}

# ── Clone repos & apply dotfiles ─────────────────────────────────────────────

clone_repos() {
  info "Cloning repos..."
  clone_if_missing dots "$DOTS_REPO"
  clone_if_missing dots-private "$DOTS_PRIVATE_REPO" 2>/dev/null || true
  clone_if_missing nix "$NIX_REPO"
}

apply_stow() {
  info "Applying dotfiles..."
  need_cmd stow || {
    if [[ "$OS" == "Darwin" ]]; then
      brew install stow
    else
      sudo apt-get install -y stow 2>/dev/null || \
        nix profile install nixpkgs#stow --extra-experimental-features 'nix-command flakes'
    fi
  }
  cd "$DOTS_REPO" && make link
}

# ── Platform-specific bootstrap ──────────────────────────────────────────────

bootstrap_darwin() {
  info "Bootstrapping macOS..."

  # Xcode Command Line Tools
  if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    info "Press enter after Xcode CLT installation completes."
    read -r
    need_cmd git || err "git not available. Ensure Xcode CLT installation completed successfully."
  fi

  install_nix
  install_homebrew
  clone_repos
  apply_stow
  install_just

  info "Building nix-darwin config..."
  cd "$NIX_REPO" && just darwin
}

bootstrap_nixos() {
  info "Bootstrapping NixOS..."
  clone_repos
  apply_stow

  info "Rebuilding NixOS..."
  cd "$NIX_REPO" && just nixos
}

bootstrap_linux() {
  info "Bootstrapping Linux (non-NixOS)..."

  sudo apt-get update
  sudo apt-get install -y curl git make stow zsh
  sudo chsh -s "$(which zsh)" "$USER"

  install_nix
  clone_repos
  apply_stow

  info "Activating home-manager..."
  cd "$NIX_REPO"
  # On first run, home-manager isn't on PATH yet — use nix run to bootstrap
  nix run home-manager/release-25.11 -- switch --flake . \
    --extra-experimental-features 'nix-command flakes'
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  if [[ "$(id -u)" == 0 ]]; then
    err "Please run as non-root."
  fi

  ensure_github_ssh

  case "$OS" in
    Darwin)
      bootstrap_darwin
      ;;
    Linux)
      if [[ -f /etc/NIXOS ]]; then
        bootstrap_nixos
      else
        bootstrap_linux
      fi
      ;;
    *)
      err "Unsupported OS: $OS"
      ;;
  esac

  # Run private bootstrap if available
  if [[ -f "$DOTS_PRIVATE_REPO/bootstrap-machine-private.sh" ]]; then
    info "Running private bootstrap..."
    bash "$DOTS_PRIVATE_REPO/bootstrap-machine-private.sh"
  fi

  info "Bootstrap complete!"
}

main "$@"
