() {
  local hist
  for hist in ${HOME}/.dots-private/.zsh_history*~$HISTFILE(N); do
    fc -RI $hist
  done
} # Load historical Zsh history files from a specific directory into the current session’s history

# add current directory to command history
zshaddhistory() {
  local cmd="${1%%$'\n'}"
  local current_dir="$(pwd)"
  local cmddir_pattern='# CMDDIR=([^;]+)$'

  # Check if the command already contains a CMDDIR comment
  if [[ $cmd =~ $cmddir_pattern ]]; then
    local existing_dir="${match[1]}"
    if [[ $existing_dir == $current_dir ]]; then
      return 1  # CMDDIR matches current directory, do nothing
    else
      cmd="${cmd//$cmddir_pattern/# CMDDIR=${current_dir}}" # Replace existing CMDDIR with current directory
    fi
  else
    cmd="${cmd} # CMDDIR=${current_dir}" # Append CMDDIR as a comment
  fi

  print -s "$cmd"  # Add the modified command to history
  return 1  # Prevent the original command from being added to history
}

# fix windows wsl clock drift
sync_time(){
  if sudo echo Starting time sync in background
  then
      sudo nohup watch -n 10 hwclock -s > /dev/null 2>&1 &
  fi
}

eo() {
  export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/openaikey.gpg)
  export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/openaibase.gpg)
}

[[ -d ${HOME}/.dots/hack/zsh-functions ]] && fpath=(${HOME}/.dots/hack/zsh-functions $fpath)
autoload -Uz -- ${HOME}/.dots/hack/zsh-functions/[^_]*(N:t) # autoload custom zsh functions like sync-dots
autoload -Uz edit-command-line          # Mark the 'edit-command-line' function for autoloading

zle -N edit-command-line                # Register 'edit-command-line' as a new ZLE widget
bindkey '^X^E' edit-command-line        # Bind 'Ctrl-X Ctrl-E' to the 'edit-command-line' ZLE widget
bindkey '^U' backward-kill-line         # Bind Ctrl-U to delete from the cursor to the start of the line

ulimit -n 65535 # Increase file descriptor limit
ulimit -c $(((4 << 30) / 512))  # Sets the maximum size of core dump files to 4GB

setopt GLOB_DOTS           # Include dotfiles in globbing patterns
setopt NO_AUTO_MENU        # Require and extra TAB press to open the completion menu
setopt PUSHDSILENT         # Silent pushd and popd to avoid printing the directory stack
