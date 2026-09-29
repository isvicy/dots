#!/bin/bash

package=$1
target=$2

echo "linking ${package} to ${target}"

script=$(readlink -f "$0")
base_dir=$(dirname "$script")

. "${base_dir}"/utils.sh

ensureTargetDir "${HOME}/.config.bak"
ensureTargetDir "${HOME}/.config"
ensureTargetDir "${HOME}/.config/direnv"
ensureTargetDir "${HOME}/.local"
ensureTargetDir "${HOME}/.local/bin"
ensureTargetDir "${HOME}/.local/share"
ensureTargetDir "${HOME}/.mcp"
ensureTargetDir "${HOME}/.claude"
ensureTargetDir "${HOME}/.kimi"
ensureTargetDir "${HOME}/.agents/skills"

# herdr runtime dirs: keep plugins/ as a real directory so herdr can create
# config/, state/, etc. inside it without stow folding the whole plugins/
# into a symlink that would leak runtime files into the dots repo.
ensureTargetDir "${HOME}/.config/herdr"
ensureTargetDir "${HOME}/.config/herdr/plugins"

# Resolve conflicts with `stow --adopt` instead of parsing stow's messages,
# whose wording differs between versions (2.3 vs 2.4). --adopt moves each
# conflicting plain file from the target into the package and links it, so
# the conflicts are exactly the package files whose content changed. Other
# conflicts (a directory or foreign symlink in the way) make stow abort before
# touching anything.
#
# Snapshot the package first so every adopted file can be restored, whether
# git tracks it or not. .git and node_modules are skipped because
# .stow-local-ignore keeps stow away from them.
snapshot=$(mktemp -d)
trap 'rm -rf "${snapshot}"' EXIT
tar -C "${package}" --exclude=./.git --exclude=./node_modules -cf - . | tar -C "${snapshot}" -xf -

stow --target="${target}" "${package}" --verbose --restow --adopt || exit

# Paths are the same file (or the same symlink) in both places
same() {
  if [[ -L "$1" || -L "$2" ]]; then
    [[ -L "$1" && -L "$2" && "$(readlink "$1")" == "$(readlink "$2")" ]]
  else
    cmp -s "$1" "$2"
  fi
}

backupdir="${HOME}"/.config.bak

while IFS= read -r -d '' file; do
  file=${file#./}
  same "${snapshot}/${file}" "${package}/${file}" && continue

  # Mirror the path relative to the target so same-named files from different
  # directories don't overwrite each other, and never clobber (or nest into)
  # a backup left by an earlier run
  dest="${backupdir}/${file}"
  if [[ -e "${dest}" || -L "${dest}" ]]; then
    dest="${dest}.$(date +%Y%m%d%H%M%S)"
  fi
  ensureTargetDir "$(dirname "${dest}")"

  # The package now holds the adopted original: back it up, then put the
  # package's own version back behind the freshly created link
  mv "${package}/${file}" "${dest}"
  mv "${snapshot}/${file}" "${package}/${file}"

  echo "backed up ${target}/${file} to ${dest}"
done < <(cd "${snapshot}" && find . \( -type f -o -type l \) -print0)
