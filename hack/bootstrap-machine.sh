#!/bin/bash

set -xueEo pipefail

if [[ -z "${GITHUB_USERNAME-}" ]]; then
	echo "ERROR: GITHUB_USERNAME not set" >&2
	exit 1
fi

umask o-w

if [[ ! -e ~/.ssh/id_ed25519 ]]; then
	if [[ "$(</proc/version)" != *[Mm]icrosoft* ]] 2>/dev/null; then
		echo "ERROR: Put your ssh keys at ~/.ssh and retry" >&2
		exit 1
	fi

	win_home="$(cd /mnt/c && cmd.exe /c "echo %HOMEDRIVE%%HOMEPATH%" | sed 's/\r$//')"
	downloads="$(wslpath "$win_home")/Downloads"

	(
		umask 0077
		: >~/.ssh/id_ed25519.tmp
	)

	if [[ -f "$downloads"/id_ed25519 ]]; then
		cat -- "$downloads"/id_ed25519 >~/.ssh/id_ed25519.tmp
	elif [[ -f "$downloads"/id_ed25519.txt ]]; then
		cat -- "$downloads"/id_ed25519.txt >~/.ssh/id_ed25519.tmp
	else
		echo "ERROR: Put your ssh keys at ~/.ssh or ${downloads@Q} and retry" >&2
		exit 1
	fi

	mv -- ~/.ssh/id_ed25519.tmp ~/.ssh/id_ed25519
fi

ssh_agent="$(ssh-agent -st 20h)"
eval "$ssh_agent"
trap 'ssh-agent -k >/dev/null' INT TERM EXIT
ssh-add ~/.ssh/id_ed25519
if [[ ! -e ~/.ssh/id_ed25519.pub ]]; then
	(
		umask 0077
		: >~/.ssh/id_ed25519.pub.tmp
	)
	ssh-add -L >~/.ssh/id_ed25519.pub.tmp
	mv -- ~/.ssh/id_ed25519.pub.tmp ~/.ssh/id_ed25519.pub
fi

rm -rf ~/.cache

sudo apt-get update
sudo sh -c 'DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" upgrade -y'
sudo apt-get autoremove -y
sudo apt-get autoclean

sudo apt-get install -y curl
sudo apt-get install -y git

sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install)" \
	sh -d /usr/local -e yes
sudo chsh -s /usr/local/bin/zsh "$USER"

tmpdir="$(mktemp -d)"
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" \
	git clone --depth=1 -- git@github.com:"$GITHUB_USERNAME"/dots.git "$tmpdir"
bootstrap="$(<"$tmpdir"/hack/bootstrap-dots.sh)"
rm -rf -- "$tmpdir"
bash -c "$bootstrap"

git_dir="$HOME/.dots"
git_private_dir="${HOME}/.dots-private"

zsh -fec 'fpath=(~/.dots/hack/zsh-functions $fpath); autoload -Uz sync-dots; sync-dots'

pushd "${git_dir}"
make link
popd

bash "${git_dir}/hack/setup-machine.sh"

if [[ -f ${git_private_dir}/bootstrap-machine-private.sh ]]; then
	bash "${git_private_dir}/bootstrap-machine-private.sh"
fi

if [[ -t 0 && -n "${WSL_DISTRO_NAME-}" ]]; then
	read -p "Need to restart WSL to complete installation. Terminate WSL now? [y/N] " -n 1 -r
	echo
	if [[ ${REPLY,,} == @(y|yes) ]]; then
		wsl.exe --terminate "$WSL_DISTRO_NAME"
	fi
fi
