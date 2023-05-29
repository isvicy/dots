#!/bin/bash

package=$1
target=$2

if ! stow --target="$target" "$package" --restow; then
	# find the conflicting files
	conflicts=$(stow --simulate --verbose=2 --target="$target" "$package" 2>&1 | grep "existing target is")
	bakdir="${HOME}"/.config.bak
	mkdir "${bakdir}"

	# loop over each conflicting file
	while read -r conflict; do
		# extract the filename
		file=$(echo "$conflict" | awk '{print $NF}')

		# backup the conflicting file
		mv "${target}/$file" "${bakdir}"

		# report the backup
		echo "backed up ${target}/${file} to ${bakdir}/${file}"
	done <<<"${conflicts}"

	# retry the stow command
	stow --target="${target}" "${package}" --verbose --restow
fi
