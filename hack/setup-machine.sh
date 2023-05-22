#!/bin/bash
#
# Sets up environment. Must be run after bootstrap-dots.sh. Can be run multiple times.

set -xueE -o pipefail

if [[ "$(</proc/version)" == *[Mm]icrosoft* ]] 2>/dev/null; then
	readonly WSL=1
else
	readonly WSL=0
fi

function apply_dots() {
	[[ ! -e ~/.dots ]] || return 0
	pushd -- ~/.dots
	make link
	pnpm install
	popd
	[[ ! -e ~/.dots-private ]] || return 0
	pushd -- ~/.dots-private
	pnpm install
	popd
}

# Install a bunch of debian packages.
function install_packages() {
	local packages=(
		apt-transport-https
		ascii
		autoconf # nvim
		automake # nvim
		bfs
		bison # tmux
		bsdutils
		build-essential
		byacc # tmux
		bzip2
		ca-certificates
		clang-format
		cmake # nvim
		command-not-found
		conntrack # kk
		curl      # nvim
		dconf-cli
		dos2unix
		doxygen # nvim
		g++     # nvim
		gawk
		gcc # git
		gedit
		gettext # git,nvim
		git
		gnome-icon-theme
		gnupg # terraform
		gzip
		htop
		jq
		lftp
		libbz2-dev          # python3.10
		libcurl4-gnutls-dev # git
		libevent-dev        # tmux
		libexpat1-dev       # git
		libglpk-dev
		liblzma-dev     # python3.10
		libncurses5-dev # tmux
		libreadline-dev # python3.10
		libsqlite3-dev  # nvim
		libssl-dev      # git
		libtool         # nvim
		libtool-bin     # nvim
		libxml2-utils
		libz-dev # git
		man
		meld
		moreutils
		nano
		ninja-build # nvim
		openssh-server
		p7zip-full
		p7zip-rar
		perl
		pigz
		pkg-config # nvim
		python3
		python3-pip
		python3-tk                 # python3.10
		socat                      # kk
		software-properties-common # terraform
		sqlite3                    # nvim
		stow
		tree
		unrar
		unzip # nvim
		wget
		x11-utils
		xclip
		xsel
		xz-utils
		yodl
		zip
		zlib1g-dev # mosh
		zsh
	)

	if ((WSL)); then
		packages+=(dbus-x11)
	else
		packages+=(gnome-tweak-tool imagemagick iotop tilix remmina wireguard docker.io)
	fi

	sudo apt-get update
	sudo bash -c 'DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::options::=--force-confdef -o DPkg::options::=--force-confold upgrade -y'
	sudo apt-get install -y "${packages[@]}"
	sudo apt-get autoremove -y
	sudo apt-get autoclean
}

function install_terraform() {
	[[ ! -e /etc/apt/sources.list.d/hashicorp.list ]] || return 0
	wget -O- https://apt.releases.hashicorp.com/gpg |
		gpg --dearmor |
		sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
	gpg --no-default-keyring \
		--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
		--fingerprint
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
		sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt update
	sudo apt-get install terraform
}

function install_docker() {
	if ((WSL)); then
		local release
		release="$(lsb_release -cs)"
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		sudo apt-key fingerprint 0EBFCD88
		sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu
      $release
      stable"
		sudo apt-get update -y
		sudo apt-get install -y docker-ce
	else
		sudo apt-get install -y docker.io
	fi
	sudo usermod -aG docker "$USER"
	# pip3 install --user docker-compose
}

function install_brew() {
	! command -v brew &>/dev/null || return 0
	local install
	install="$(mktemp)"
	curl -fsSLo "$install" https://raw.githubusercontent.com/Homebrew/install/master/install.sh
	bash -- "$install" </dev/null
	rm -- "$install"
}

function install_brew_bins() {
	if ! command -v pnpm &>/dev/null; then
		brew install pnpm
	fi
	if ! command -v deno &>/dev/null; then
		brew install deno
	fi
	if ! command -v buf &>/dev/null; then
		brew install bufbuild/buf/buf
	fi
	if ! command -v shellcheck &>/dev/null; then
		brew install shellcheck
	fi
	if ! command -v lua-language-server &>/dev/null; then
		brew install lua-language-server
	fi
}

function install_pnpm_bins() {
	if ! command -v eslint_d &>/dev/null; then
		pnpm install -g eslint_d
	fi
}

# Install Visual Studio Code.
function install_vscode() {
	((!WSL)) || return 0
	! command -v code &>/dev/null || return 0
	local deb
	deb="$(mktemp)"
	curl -fsSL 'https://go.microsoft.com/fwlink/?LinkID=760868' >"$deb"
	sudo dpkg -i "$deb"
	rm -- "$deb"
}

function install_exa() {
	local v="0.9.0"
	! command -v exa &>/dev/null || [[ "$(exa --version)" != *" v$v" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	curl -fsSLO "https://github.com/ogham/exa/releases/download/v${v}/exa-linux-x86_64-${v}.zip"
	unzip exa-linux-x86_64-${v}.zip
	sudo install -DT ./exa-linux-x86_64 /usr/local/bin/exa
	popd
	rm -rf -- "$tmp"
}

function install_ripgrep() {
	local v="12.1.1"
	! command -v rg &>/dev/null || [[ "$(rg --version)" != *" $v "* ]] || return 0
	local deb
	deb="$(mktemp)"
	curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${v}/ripgrep_${v}_amd64.deb" >"$deb"
	sudo dpkg -i "$deb"
	rm "$deb"
}

function install_bat() {
	local v="0.18.0"
	! command -v bat &>/dev/null || [[ "$(bat --version)" != *" $v" ]] || return 0
	local deb
	deb="$(mktemp)"
	curl -fsSL "https://github.com/sharkdp/bat/releases/download/v${v}/bat_${v}_amd64.deb" >"$deb"
	sudo dpkg -i "$deb"
	rm "$deb"
}

function install_gh() {
	local v="2.12.1"
	! command -v gh &>/dev/null || [[ "$(gh --version)" != */v"$v" ]] || return 0
	local deb
	deb="$(mktemp)"
	curl -fsSL "https://github.com/cli/cli/releases/download/v${v}/gh_${v}_linux_amd64.deb" >"$deb"
	sudo dpkg -i "$deb"
	rm "$deb"
}

function install_bw() {
	local v="1.22.1"
	! command -v bw &>/dev/null || [[ "$(bw --version)" != "$v" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	curl -fsSLO "https://github.com/bitwarden/cli/releases/download/v${v}/bw-linux-${v}.zip"
	unzip -- "bw-linux-${v}.zip"
	chmod +x bw
	mv bw ~/.local/bin/
	popd
	rm -rf -- "$tmp"
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
	if ! command -v pylyzer &>/dev/null; then
		cargo install pylyzer
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
	curl -fsSL "https://go.dev/dl/go${v}.linux-amd64.tar.gz" -o go.tar.gz
	tar -xzf ./go.tar.gz -C "${HOME}/.local"
	popd
	rm -rf -- "$tmp"
}

function install_golang_bins() {
	go install golang.org/x/tools/gopls@latest
	go install mvdan.cc/gofumpt@latest
	go install mvdan.cc/sh/v3/cmd/shfmt@latest
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/google/yamlfmt/cmd/yamlfmt@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
}

function install_golangci-lint() {
	! command -v golangci-lint &>/dev/null || return 0
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$(go env GOPATH)"/bin
}

function install_tmux() {
	local min_v="3.3a"
	! command -v tmux &>/dev/null || [[ "$(tmux -V | awk '{print $2}')" < "$min_v" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	git clone https://github.com/tmux/tmux.git
	cd tmux
	git checkout ${min_v}
	./configure
	make -j $(($(nproc) / 2))
	sudo make install
	popd
	rm -rf -- "$tmp"
}

function install_git() {
	local min_v='2.31.0'
	! command -v git &>/dev/null || [[ "$(git version | awk '{print $3}')" < "$min_v" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	curl -fsSL 'https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.39.3.tar.gz' -o git.tar.gz
	tar -zxf git.tar.gz
	cd git-*
	make -j $(($(nproc) / 2)) prefix="${HOME}/.local" all
	make prefix="${HOME}/.local" install
	popd
	rm -rf -- "$tmp"
}

function install_protobuf() {
	local v='3.21.1'
	! command -v protoc &>/dev/null || [[ "$(protoc --version | awk '{print $2}')" != "${v}" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	curl -fsSL 'https://github.com/protocolbuffers/protobuf/archive/refs/tags/v21.1.tar.gz' -o proto.tar.gz
	tar -xzf proto.tar.gz
	cd protobuf-21.1
	./autogen.sh
	./configure
	make -j $(($(nproc) / 2))
	sudo make install
	sudo ldconfig
	popd
	rm -rf -- "$tmp"
}

function install_mosh() {
	local min_v='1.3.2'
	! command -v mosh &>/dev/null || [[ "$(mosh -v | head -n 1 | awk '{print $2}')" != "${min_v}" ]] || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	git clone https://github.com/mobile-shell/mosh
	cd mosh
	git checkout mosh-1.4.0
	./autogen.sh
	./configure
	make -j $(($(nproc) / 2))
	sudo make install
	popd
	rm -rf -- "$tmp"
}

function install_live555() {
	! command -v live555MediaServer &>/dev/null || return 0
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	wget http://www.live555.com/liveMedia/public/live555-latest.tar.gz
	tar xvf live555-latest.tar.gz
	cd live
	./genMakefiles linux
	make -j $(($(nproc) / 2))
	sudo make install
	popd
	rm -rf -- "$tmp"
}

function install_nvim() {
	local tmp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	git clone https://github.com/neovim/neovim
	cd neovim
	git checkout master
	git pull && git pull --tags --force
	git checkout stable
	local nvim_repo_version
	nvim_repo_version=$(git tag | tail -n 1)
	if command -v nvim &>/dev/null; then
		local nvim_current_version
		nvim_current_version=$(nvim --version | head -n 1 | awk '{print $2}')
		if [ "${nvim_repo_version}" = "${nvim_current_version}" ]; then
			return 0
		fi
	fi
	make CMAKE_BUILD_TYPE=Release
	sudo make install
	popd
	rm -rf -- "$tmp"
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

function install_pip_packages() {
	pip install --upgrade black
	pip install --upgrade debugpy
}

function fix_locale() {
	sudo tee /etc/default/locale >/dev/null <<<'LC_ALL="C.UTF-8"'
}

function win_install_fonts() {
	local dst_dir
	dst_dir="$(cmd.exe /c 'echo %LOCALAPPDATA%\Microsoft\Windows\Fonts' 2>/dev/null | sed 's/\r$//')"
	dst_dir="$(wslpath "$dst_dir")"
	mkdir -p "$dst_dir"
	local src
	for src in "$@"; do
		local file
		file="$(basename "$src")"
		if [[ ! -f "$dst_dir/$file" ]]; then
			cp -f "$src" "$dst_dir/"
		fi
		local win_path
		win_path="$(wslpath -w "$dst_dir/$file")"
		# Install font for the current user. It'll appear in "Font settings".
		reg.exe add \
			'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' \
			/v "${file%.*} (TrueType)" /t REG_SZ /d "$win_path" /f 2>/dev/null
	done
}

# Install a decent monospace font.
function install_fonts() {
	((WSL)) || return 0
	win_install_fonts ~/.local/share/fonts/NerdFonts/*.ttf
}

function add_to_sudoers() {
	# This is to be able to create /etc/sudoers.d/"$username".
	if [[ "$USER" == *'~' || "$USER" == *.* ]]; then
		echo >&2 "${BASH_SOURCE[0]}: invalid username: $USER"
		exit 1
	fi

	sudo usermod -aG sudo "$USER"
	sudo tee /etc/sudoers.d/"$USER" <<<"$USER ALL=(ALL) NOPASSWD:ALL" >/dev/null
	sudo chmod 440 /etc/sudoers.d/"$USER"
}

function fix_dbus() {
	((WSL)) || return 0
	sudo dbus-uuidgen --ensure
}

function patch_ssh() {
	local v='8.2p1-4ubuntu0.5'
	local ssh
	ssh="$(which ssh)"
	grep -qF -- 'Warning: Permanently added' "$ssh" || return 0
	dpkg -s openssh-client | grep -qxF "Version: 1:$v" || return 0
	local deb
	deb="$(mktemp)"
	curl -fsSLo "$deb" \
		"https://github.com/romkatv/ssh/releases/download/v1.0/openssh-client_${v}_amd64.deb"
	sudo dpkg -i "$deb"
	rm -- "$deb"
}

function enable_sshd() {
	sudo tee /etc/ssh/sshd_config >/dev/null <<\END
ClientAliveInterval 60
AcceptEnv TERM
X11Forwarding no
X11UseLocalhost no
PermitRootLogin no
AllowTcpForwarding no
AllowAgentForwarding no
AllowStreamLocalForwarding no
AuthenticationMethods publickey
PrintLastLog no
PrintMotd no
END
	((!WSL)) || return 0
	sudo systemctl enable --now ssh
	if [[ ! -e ~/.ssh/authorized_keys ]]; then
		cp ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys
	fi
}

function with_dbus() {
	if [[ -z "${DBUS_SESSION_BUS_ADDRESS+X}" ]]; then
		dbus-launch "$@"
	else
		"$@"
	fi
}

function disable_motd_news() {
	((!WSL)) || return 0
	sudo systemctl disable motd-news.timer
}

if [[ "$(id -u)" == 0 ]]; then
	echo "${BASH_SOURCE[0]}: please run as non-root" >&2
	exit 1
fi

umask g-w,o-w

add_to_sudoers

install_packages
install_terraform
install_docker
install_brew
install_brew_bins
install_pnpm_bins
install_vscode
install_ripgrep
install_bat
install_gh
install_exa
install_bw
install_rust
install_rust_bins
install_golang
install_golang_bins
install_golangci-lint
install_tmux
install_git
install_pyenv
install_pip_packages
install_protobuf
install_mosh
install_live555
install_nvim
# install_fonts

patch_ssh
# enable_sshd
disable_motd_news

fix_locale
fix_dbus

apply_dots

echo SUCCESS
