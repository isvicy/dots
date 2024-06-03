#!/bin/bash

package=$1
target=$2

echo "linking ${package} to ${target}"

script=$(readlink -f "$0")
base_dir=$(dirname "$script")

. "${base_dir}"/utils.sh

ensureTargetDir "${HOME}/.config.bak"
ensureTargetDir "${HOME}/.config"
ensureTargetDir "${HOME}/.local"
ensureTargetDir "${HOME}/.local/bin"
ensureTargetDir "${HOME}/.local/share"

# Run stow in simulation mode to detect conflicts
# use uniq to remove duplicates cause stow will output the confilcts info multiple times
conflicts=$(stow --simulate --verbose=2 --target="$target" "$package" 2>&1 | grep "cannot stow" | awk -F"target " '{print $2}' | awk '{print $1}' | uniq)

if [ -z "$conflicts" ]; then
	# No conflicts, proceed with stowing
	stow --target="$target" "$package" --verbose --restow
	exit 0
fi

# Handle conflicts
backupdir="${HOME}"/.config.bak

# Loop over each conflicting file
while read -r file; do
	# Backup the conflicting file
	mv "${target}/$file" "${backupdir}"

	# Report the backup
	echo "backed up ${target}/${file} to ${backupdir}/${file}"
done <<<"${conflicts}"

# Retry the stow command
stow --target="${target}" "${package}" --verbose --restow
