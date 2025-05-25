#!/bin/bash

set -xueE -o pipefail

function install_brew() {
  ! command -v brew &>/dev/null || return 0
  local install
  install="$(mktemp)"
  curl -fsSLo "$install" https://raw.githubusercontent.com/Homebrew/install/master/install.sh
  bash -- "$install" </dev/null
  rm -- "$install"

  case "$(uname -s)" in
  Linux)
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    ;;
  Darwin)
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ;;
  esac
}

function install_brew_bins() {
  brew bundle --file='~/.dots/.Brewfile' --cleanup
}

function post_install_brew_bins() {
  # Install tmux plugin manager
  if [ ! -d "${HOME}/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm"
  fi

  # Install lua magick for image rendering in neovim
  luarocks --lua-version 5.1 install magick
}

function install_pnpm_bins() {
  export PNPM_HOME="${HOME}/.local/share/pnpm"
  case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
  esac

  if ! command -v eslint_d &>/dev/null; then
    pnpm install -g eslint_d
  fi
  if ! command -v fixjson &>/dev/null; then
    pnpm install -g fixjson
  fi
}

function install_rust() {
  ! command -v cargo &>/dev/null || return 0
  local tmp
  tmp="$(mktemp -d)"
  pushd -- "$tmp"
  curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
  popd
  rm -rf -- "$tmp"
  # shellcheck source=../../.cargo/env
  source "${HOME}/.cargo/env"
}

function install_rust_bins() {
  if ! command -v zoxide &>/dev/null; then
    cargo install zoxide --locked
  fi
  if ! command -v fnm &>/dev/null; then
    cargo install fnm --locked
  fi
  if ! command -v stylua &>/dev/null; then
    cargo install stylua
  fi
  if ! command -v rust-analyzer &>/dev/null; then
    rustup component add rust-analyzer
  fi
}

function install_golang() {
  local v="1.21.3"
  ! command -v go &>/dev/null || [[ "$(go version | awk '{print $3}' | tr -d 'go')" != "$v" ]] || return 0
  rm -rf "${HOME}/.local/go" # Clear install folders to avoid conflicts between source files of different versions.
  local tmp
  tmp="$(mktemp -d)"
  pushd -- "$tmp"

  arch=$(uname -m)

  case "$(uname -s)" in
  Linux)
    case ${arch} in
    x86_64)
      curl -fsSL "https://go.dev/dl/go${v}.linux-amd64.tar.gz" -o go.tar.gz
      ;;
    arm64)
      curl -fsSL "https://go.dev/dl/go${v}.linux-arm64.tar.gz" -o go.tar.gz
      ;;
    *)
      echo "not supported arch: ${arch}, skip install golang."
      exit 0
      ;;
    esac
    ;;
  Darwin)
    case ${arch} in
    x86_64)
      curl -fsSL "https://go.dev/dl/go${v}.darwin-amd64.tar.gz" -o go.tar.gz
      ;;
    arm64)
      curl -fsSL "https://go.dev/dl/go${v}.darwin-arm64.tar.gz" -o go.tar.gz
      ;;
    *)
      echo "not supported arch: ${arch}, skip install golang."
      exit 0
      ;;
    esac
    ;;
  esac

  tar -xzf ./go.tar.gz -C "${HOME}/.local"
  popd
  rm -rf -- "$tmp"
  export PATH="${HOME}/.local/go/bin:${PATH}"
}

function install_golang_bins() {
  if ! command -v go &>/dev/null; then
    echo "golang not installed, skip installing golang binarys"
    exit 0
  fi

  go install golang.org/x/tools/gopls@latest
  go install mvdan.cc/gofumpt@latest
  go install mvdan.cc/sh/v3/cmd/shfmt@latest
  go install golang.org/x/tools/cmd/goimports@latest
  go install github.com/google/yamlfmt/cmd/yamlfmt@latest
  go install github.com/go-delve/delve/cmd/dlv@latest
}

function install_golangci-lint() {
  if ! command -v go &>/dev/null; then
    echo "golang not installed, skip installing golang binarys"
    exit 0
  fi

  ! command -v golangci-lint &>/dev/null || return 0
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$(go env GOPATH)"/bin
}

function install_pyenv() {
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"

  ! command -v pyenv &>/dev/null || return 0
  if [ -e ~/.pyenv ]; then
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  pushd -- "$tmp"
  curl https://pyenv.run | bash
  popd
  rm -rf -- "$tmp"
}

function install_python() {
  CC=$(brew --prefix)/bin/gcc-14 CPPFLAGS="-I$(brew --prefix)/include" LDFLAGS="-L$(brew --prefix)/lib" pyenv install -s 3.12
  # this way, pyenv is activated in current shell, so the global setting below will work
  eval "$(pyenv init -)"
  pyenv global 3.12
}

function install_pip_packages() {
  unset ALL_PROXY

  pip install --upgrade pysocks
  pip install --upgrade pip
  pip install --upgrade black
  pip install --upgrade debugpy
}

function install_gvm() {
  export GVM_ROOT="$HOME/.gvm"
  export PATH="$GVM_ROOT/bin:$PATH"

  ! command -v gvm &>/dev/null || return 0
  if [ -e ~/.gvm ]; then
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  pushd -- "$tmp"
  curl -s -S -L https://raw.githubusercontent.com/isvicy/gvm/master/binscripts/gvm-installer | bash
  popd
  rm -rf -- "$tmp"
}

function post_install_gvm() {
  set +xueE
  [[ -s "$GVM_ROOT/scripts/gvm" ]] && source "$GVM_ROOT/scripts/gvm"
  gvm install go1.22.3 -B && gvm use go1.22.3 --default
  set -uxeE
}

function apply_dots() {
  pushd "${HOME}/.dots"
  make link
  popd
}

apply_dots

git_dir="$HOME/.dots"
machine_out="$(uname -s)"
case "${machine_out}" in
Linux)
  distro_name=$(cat /etc/*-release | grep -E '^NAME')
  if echo "${distro_name}" | grep -i 'ubuntu'; then
    bash "${git_dir}/hack/setup-ubuntu.sh"
  else
    echo "not supported distro: ${distro_name}, exiting bootstrap."
    exit 1
  fi

  ;;

Darwin)
  bash "${git_dir}/hack/setup-mac.sh"
  ;;
*)
  echo "not supported os: ${machine_out}, exiting bootstrap."
  exit 1
  ;;
esac

install_brew
install_brew_bins
post_install_brew_bins
# install_gvm
# post_install_gvm
# install_golang_bins
# install_golangci-lint
install_pnpm_bins
install_rust
install_rust_bins
# install_pyenv
# install_python
# install_pip_packages

echo SETUP MACHINE SUCCEED
