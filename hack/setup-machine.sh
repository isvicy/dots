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
	local binary_list=(
		nodejs
		pnpm
		deno
		buf
		shellcheck
		lua-language-server
		neovim
		tmux
		terraform
		ripgrep
		bat
		gh
		exa
		git
		mosh
		cilium-cli
		pyright
		mypy
		ruff
		stow
		git-delta
	)
	for item in "${binary_list[@]}"; do
		brew info "${item}" | grep --quiet 'Not installed' && brew install "${item}"
	done

	return 0
}

function install_pnpm_bins() {
	if ! command -v eslint_d &>/dev/null; then
		pnpm install -g eslint_d
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
}

function install_golang() {
	local v="1.20.4"
	! command -v go &>/dev/null || [[ "$(go version | awk '{print $3}' | tr -d 'go')" != "$v" ]] || return 0
	rm -rf "${HOME}/.local/go" # Clear install folders to avoid conflicts between source files of different versions.
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	arch=$(uname -m)
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

	tar -xzf ./go.tar.gz -C "${HOME}/.local"
	popd
	rm -rf -- "$tmp"
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
	pyenv install -s 3.10
	pyenv global 3.10
}

function install_pip_packages() {
	pip install --upgrade black
	pip install --upgrade debugpy
}

function apply_dots() {
	pushd "${HOME}/.dots"
	make link
	popd
}

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
install_pnpm_bins
install_rust
install_rust_bins
install_golang
install_golang_bins
install_golangci-lint
install_pyenv
install_python
install_pip_packages

apply_dots

echo SETUP MACHINE SUCCEED
