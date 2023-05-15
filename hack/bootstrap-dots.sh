#!/bin/bash
#
# Clones dots and dots-private from github. Requires `git` and ssh
# keys for github.

set -xueEo pipefail

if [[ -z "${GITHUB_USERNAME:-}" ]]; then
	echo "ERROR: GITHUB_USERNAME not set" >&2
	exit 1
fi

function clone_repo() {
	local repo=$1
	local git_dir="$HOME/.$repo"
	local uri="git@github.com:$GITHUB_USERNAME/$repo.git"

	if [[ -e "$git_dir" ]]; then
		return 0
	fi

	git clone --recurse-submodules ${uri} ${git_dir}
}

if [[ "$(id -u)" == 0 ]]; then
	echo "${BASH_SOURCE}: please run as non-root" >&2
	exit 1
fi

clone_repo dots
clone_repo dots-private
