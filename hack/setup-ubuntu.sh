#!/bin/bash
#
# Sets up environment. Must be run after bootstrap-dots.sh. Can be run multiple times.

set -xueE -o pipefail

if [[ "$(</proc/version)" == *[Mm]icrosoft* ]] 2>/dev/null; then
	readonly WSL=1
else
	readonly WSL=0
fi

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

# Install a bunch of debian packages.
function install_packages() {
	local packages=(
		apt-transport-https
		autoconf # nvim
		automake # nvim
		build-essential
		bzip2
		ca-certificates
		clang-format
		cmake # nvim
		command-not-found
		conntrack # kk
		curl      # nvim
		g++       # nvim
		gcc       # git
		git
		gnupg # terraform
		gzip
		htop
		jq
		libbz2-dev         # python3.10
		liblzma-dev        # python3.10
		libreadline-dev    # python3.10
		gdb                # python3.10
		lcov               # python3.10
		libffi-dev         # python3.10
		libgdbm-dev        # python3.10
		libgdbm-compat-dev # python3.10
		libncurses5-dev    # python3.10
		libreadline6-dev   # python3.10
		libsqlite3-dev     # python3.10
		lzma               # python3.10
		lzma-dev           # python3.10
		tk-dev             # python3.10
		uuid-dev           # python3.10
		zlib1g-dev         # python3.10
		libssl-dev         # python3.10
		man
		pkg-config # nvim
		python3
		python3-pip
		python3-tk                 # python3.10
		socat                      # kk
		software-properties-common # terraform
		stow
		tree
		unrar
		unzip # nvim
		wget
		xz-utils
		zip
		# psql
		postgresql
		postgresql-contrib
	)

	sudo apt-get update
	sudo bash -c 'DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::options::=--force-confdef -o DPkg::options::=--force-confold upgrade -y'
	sudo apt-get install -y "${packages[@]}"
	sudo apt-get autoremove -y
	sudo apt-get autoclean
}

function install_docker() {
	[ ! -e /etc/apt/sources.list.d/docker.list ] || return 0

	local installed_packages
	installed_packages=$(sudo dpkg-query -l | awk '{print $2}')
	local to_remove_packages=(docker.io docker-doc docker-compose containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
	for package in "${to_remove_packages[@]}"; do
		# shellcheck disable=2076
		if [[ " ${installed_packages[*]} " =~ " ${package} " ]]; then
			sudo apt-get remove -y "${package}"
		fi
	done
	# make sure reinstalling process not interruptted
	sudo rm -rf /var/lib/dpkg/info/dokcer*

	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL 'https://download.docker.com/linux/ubuntu/gpg' | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg

	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	 $(. /etc/os-release && echo $VERSION_CODENAME) stable" |
		sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

function post_docker_installation() {
	# post installation
	if getent group docker >/dev/null 2>&1; then
		echo "Docker group already exists"
	else
		sudo groupadd docker

		# Verify that the group has been created
		if getent group docker >/dev/null 2>&1; then
			echo "Docker group has been created"
		else
			echo "Failed to create Docker group"
		fi
	fi

	# Check if the user is in the docker group
	if id -nG "$USER" | grep -qw docker; then
		echo "User $USER is already in the docker group"
		return 0
	else
		# Add the user to the docker group
		sudo usermod -aG docker "$USER"

		# Verify that the user has been added to the group
		if id -nG "$USER" | grep -qw docker; then
			echo "User $USER has been added to the docker group"
		else
			echo "Failed to add user $USER to the docker group"
		fi
	fi
}

function install_nvidia_docker_toolkit() {
	if nvidia-smi; then
		[ ! -e /etc/apt/sources.list.d/nvidia-container-toolkit.list ] || return 0
		local installed_packages
		installed_packages=$(sudo dpkg-query -l | awk '{print $2}')
		[[ " ${installed_packages[*]} " =~ "nvidia-container-toolkit" ]] && sudo apt-get remove -y nvidia-container-toolkit
		curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg &&
			curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
			sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
				sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
		sudo apt-get update
		sudo apt-get install -y nvidia-container-toolkit
		# generate CDI specification
		sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
		sudo nvidia-ctk runtime configure --runtime=docker
		# to make sure the nvidia runtime is configured properly, it's recommended we restart docker service
		sudo systemctl restart docker
		# make sure nvidia runtime is working
		sudo docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
	fi
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

function fix_locale() {
	sudo locale-gen en_US.UTF-8
	sudo tee /etc/default/locale >/dev/null <<<'LC_ALL="en_US.UTF-8"'
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
		cp -f "$src" "$dst_dir/"
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

if [[ "$(id -u)" == 0 ]]; then
	echo "${BASH_SOURCE[0]}: please run as non-root" >&2
	exit 1
fi

umask g-w,o-w

add_to_sudoers

install_packages
install_docker
post_docker_installation
install_nvidia_docker_toolkit
# install_live555
# install_fonts

fix_locale

echo SETUP UBUNTU SUCCEED

if [[ -t 0 && -n "${WSL_DISTRO_NAME-}" ]]; then
	read -p "Need to restart WSL to complete installation. Terminate WSL now? [y/N] " -n 1 -r
	echo
	if [[ ${REPLY,,} == 'y' ]]; then
		wsl.exe --terminate "$WSL_DISTRO_NAME"
	fi
fi
