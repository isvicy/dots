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
	pushd -- ~/.dots
	make link
	popd
}

# Install a bunch of debian packages.
function install_packages() {
	local packages=(
		ascii
		apt-transport-https
		autoconf
		bfs
		bsdutils
		bzip2
		build-essential
		ca-certificates
		clang-format
		cmake
		command-not-found
		curl
		dconf-cli
		dos2unix
		g++
		gawk
		gedit
		git
		gnome-icon-theme
		gzip
		htop
		jq
		lftp
		libglpk-dev
		libncurses-dev
		libxml2-utils
		man
		meld
		moreutils
		nano
		openssh-server
		p7zip-full
		p7zip-rar
		perl
		python3
		python3-pip
		pigz
		software-properties-common
		stow
		tree
		unrar
		unzip
		wget
		x11-utils
		xclip
		xsel
		xz-utils
		yodl
		zip
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
	pip3 install --user docker-compose
}

function install_brew() {
	! command -v brew &>/dev/null || return 0
	local install
	install="$(mktemp)"
	curl -fsSLo "$install" https://raw.githubusercontent.com/Homebrew/install/master/install.sh
	bash -- "$install" </dev/null
	rm -- "$install"
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

function install_nuget() {
	((WSL)) || return 0
	local v="5.8.1"
	! command -v nuget.exe &>/dev/null || [[ "$(nuget.exe help)" != "NuGet Version: $v."* ]] || return 0
	local tmp
	tmp="$(mktemp)"
	curl -fsSLo "$tmp" "https://dist.nuget.org/win-x86-commandline/v${v}/nuget.exe"
	chmod +x -- "$tmp"
	mv -- "$tmp" ~/.local/bin/nuget.exe
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
	! command -v cargo &>/dev/null
	local temp
	tmp="$(mktemp -d)"
	pushd -- "$tmp"
	curl --proto '=https' --tlsv1.2 -sSf 'https://sh.rustup.rs' | sh -s -- -y
	popd
	rm -rf -- "$tmp"
	source ${HOME}/.cargo/env
}

function install_rust_bins() {
	! command -v zoxide &>/dev/null
	cargo install zoxide --locked
}

function fix_locale() {
	sudo tee /etc/default/locale >/dev/null <<<'LC_ALL="C.UTF-8"'
}

# Avoid clock snafu when dual-booting Windows and Linux.
# See https://www.howtogeek.com/323390/how-to-fix-windows-and-linux-showing-different-times-when-dual-booting/.
function fix_clock() {
	((!WSL)) || return 0
	timedatectl set-local-rtc 1 --adjust-system-clock
}

# Set the shared memory size limit to 64GB (the default is 32GB).
function fix_shm() {
	((!WSL)) || return 0
	! grep -qF '# My custom crap' /etc/fstab || return 0
	sudo mkdir -p /mnt/c /mnt/d
	sudo tee -a /etc/fstab >/dev/null <<<'# My custom crap
tmpfs /dev/shm tmpfs defaults,rw,nosuid,nodev,size=64g 0 0
UUID=F212115212111D63 /mnt/c ntfs-3g nosuid,nodev,uid=0,gid=0,noatime,streams_interface=none,remove_hiberfile,async,lazytime,big_writes 0 0
UUID=2A680BF9680BC315 /mnt/d ntfs-3g nosuid,nodev,uid=0,gid=0,noatime,streams_interface=none,remove_hiberfile,async,lazytime,big_writes 0 0'
}

function win_install_fonts() {
	local dst_dir
	dst_dir="$(cmd.exe /c 'echo %LOCALAPPDATA%\Microsoft\Windows\Fonts' 2>/dev/null | sed 's/\r$//')"
	dst_dir="$(wslpath "$dst_dir")"
	mkdir -p "$dst_dir"
	local src
	for src in "$@"; do
		local file="$(basename "$src")"
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
		echo >&2 "$BASH_SOURCE: invalid username: $USER"
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

# Increase imagemagic memory and disk limits.
function fix_imagemagic() {
	# TODO: enable this.
	return
	((!WSL)) || return 0
	local cfg=/etc/ImageMagick-6/policy.xml k v kv
	[[ -f "$cfg" ]]
	for kv in "memory 16GiB" "map 32GiB" "width 128KP" "height 128KP" "area 8GiB" "disk 64GiB"; do
		read k v <<<"$kv"
		grep -qE 'name="'$k'" value="[^"]*"' "$cfg"
		sudo sed -i 's/name="'$k'" value="[^"]*"/name="'$k'" value="'$v'"/' "$cfg"
	done
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
	echo "$BASH_SOURCE: please run as non-root" >&2
	exit 1
fi

umask g-w,o-w

add_to_sudoers

install_packages
install_docker
install_brew
install_vscode
install_ripgrep
install_bat
install_gh
install_exa
install_nuget
install_bw
install_rust
install_rust_bins
# install_fonts

patch_ssh
enable_sshd
disable_motd_news

fix_locale
fix_clock
fix_shm
fix_dbus
fix_imagemagic

apply_dots

echo SUCCESS