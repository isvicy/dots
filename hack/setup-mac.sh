#!/bin/bash
#
# Sets up environment. Must be run after bootstrap-dots.sh. Can be run multiple times.

set -xueE -o pipefail

function install_nix() {
  ! command -v nix &>/dev/null || return 0
  curl -fsSL https://nixos.org/nix/install | sh -s -- --yes
}

install_nix

echo SETUP MAC SUCCEED
