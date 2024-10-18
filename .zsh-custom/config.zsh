[[ -d ${HOME}/.dots/hack/zsh-functions ]] && fpath=(${HOME}/.dots/hack/zsh-functions $fpath)
autoload -Uz -- ${HOME}/.dots/hack/zsh-functions/[^_]*(N:t) # autoload custom zsh functions like sync-dots
autoload -Uz edit-command-line          # Mark the 'edit-command-line' function for autoloading

zle -N edit-command-line                # Register 'edit-command-line' as a new ZLE widget
# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region
bindkey '^X^E' edit-command-line        # Bind 'Ctrl-X Ctrl-E' to the 'edit-command-line' ZLE widget
bindkey '^U' backward-kill-line         # Bind Ctrl-U to delete from the cursor to the start of the line

ulimit -n 65535 # Increase file descriptor limit
ulimit -c $(((4 << 30) / 512))  # Sets the maximum size of core dump files to 4GB

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

setopt GLOB_DOTS           # Include dotfiles in globbing patterns
setopt NO_AUTO_MENU        # Require and extra TAB press to open the completion menu
setopt PUSHDSILENT         # Silent pushd and popd to avoid printing the directory stack

setopt interactivecomments # Enable comments in interactive shell

echo -ne '\e[3 q' # Use underline blink cursor on startup.
preexec() { echo -ne '\e[3 q' ;} # Use underline blink cursor for each new prompt.
