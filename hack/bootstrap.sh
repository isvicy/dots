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

# ── SSH key setup ────────────────────────────────────────────────────────────

setup_ssh() {
  if [[ -e ~/.ssh/id_ed25519 ]]; then
    return 0
  fi

  mkdir -p ~/.ssh && chmod 700 ~/.ssh

  # On WSL, try copying from Windows Downloads
  if [[ "${OS}" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    local win_home downloads
    win_home="$(cd /mnt/c && cmd.exe /c "echo %HOMEDRIVE%%HOMEPATH%" 2>/dev/null | sed 's/\r$//')"
    downloads="$(wslpath "$win_home")/Downloads"
    if [[ -f "$downloads/id_ed25519" ]]; then
      install -m 600 "$downloads/id_ed25519" ~/.ssh/id_ed25519
      info "Copied SSH key from Windows Downloads"
      return 0
    elif [[ -f "$downloads/id_ed25519.txt" ]]; then
      install -m 600 "$downloads/id_ed25519.txt" ~/.ssh/id_ed25519
      info "Copied SSH key from Windows Downloads"
      return 0
    fi
  fi

  err "No SSH key found at ~/.ssh/id_ed25519. Please place your key there and retry."
}

setup_ssh_agent() {
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    eval "$(ssh-agent -s)"
  fi
  ssh-add ~/.ssh/id_ed25519 2>/dev/null || true

  if [[ ! -e ~/.ssh/id_ed25519.pub ]]; then
    ssh-add -L > ~/.ssh/id_ed25519.pub 2>/dev/null || true
  fi
}

# ── Platform prerequisites ───────────────────────────────────────────────────

install_nix() {
  need_cmd nix && return 0
  info "Installing Nix..."
  curl -fsSL https://nixos.org/nix/install | sh -s -- --daemon --yes
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
    nix profile install nixpkgs#just
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
      sudo apt-get install -y stow 2>/dev/null || nix profile install nixpkgs#stow
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
  install_just

  info "Activating home-manager..."
  cd "$NIX_REPO" && just home
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  if [[ "$(id -u)" == 0 ]]; then
    err "Please run as non-root."
  fi

  setup_ssh
  setup_ssh_agent

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
