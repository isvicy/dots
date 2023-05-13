#!/bin/bash

set -xueEo pipefail

function install_packages() {
	local packages=(
		stow
	)
	sudo apt-get update
	sudo apt-get install -y "${packages[@]}"
	sudo apt-get autoremove -y
	sudo apt-get autoclean
}

function add_to_sudoers() {
	# This is able to create /etc/sudoers.d/"$username".
	if [[ "${USER}" == *'~' || "${USER}" == *.* ]]; then
		echo >&2 "${BASH_SOURCE}: invalid username: ${USER}"
		exit 1
	fi

	sudo usermod -aG sudo "${USER}"
	sudo tee /etc/sudoers.d/"$USER" <<<"$USER ALL=(ALL) NOPASSWD:ALL" >/dev/null
	sudo chmod 440 /etc/sudoers.d/"${USER}"
}

add_to_sudoers

install_packages

echo SUCCESS
