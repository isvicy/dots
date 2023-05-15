# Personal Zsh configuration file. It is strongly recommended to keep all
# shell customization and configuration (including exported environment
# variables such as PATH) in this file or in files sourced from it.
#
# Documentation: https://github.com/romkatv/zsh4humans/blob/v5/README.md.

# Periodic auto-update on Zsh startup: 'ask' or 'no'.
# You can manually run `z4h update` to update everything.
zstyle ':z4h:' auto-update      'no'
# Ask whether to auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:' auto-update-days '28'

# Keyboard type: 'mac' or 'pc'.
zstyle ':z4h:bindkey' keyboard  'pc'

# Don't start tmux.
zstyle ':z4h:' start-tmux       no

# Mark up shell's output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

zstyle ':z4h:term-title:ssh'    precmd                 ${${${Z4H_SSH##*:}//\%/%%}:-%m}': %~'
zstyle ':z4h:term-title:ssh'    preexec                ${${${Z4H_SSH##*:}//\%/%%}:-%m}': ${1//\%/%%}'

# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char 'accept'

# Recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# Enable direnv to automatically source .envrc files.
zstyle ':z4h:direnv'         enable 'no'
# Show "loading" and "unloading" notifications from direnv.
zstyle ':z4h:direnv:success' notify 'yes'

# Enable ('yes') or disable ('no') automatic teleportation of z4h over
# SSH when connecting to these hosts.
# The default value if none of the overrides above match the hostname.
zstyle ':z4h:ssh:*'                   enable 'yes'
# zstyle ':z4h:ssh:example-hostname1'   enable 'yes'
# zstyle ':z4h:ssh:*.example-hostname2' enable 'no'

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
zstyle ':z4h:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

if [[ -e ~/.ssh/id_ed25519 ]]; then
  zstyle ':z4h:ssh-agent:' start      yes
  zstyle ':z4h:ssh-agent:' extra-args -t 20h
else
  : ${GITSTATUS_AUTO_INSTALL:=0}
fi

if [[ $TERM == xterm-256color && ! -v ZSH_SCRIPT && ! -v ZSH_EXECUTION_STRING &&
      -z $SSH_CONNECTON && P9K_SSH -ne 1 && -e ~/.ssh/id_rsa && -e /proc/uptime &&
      ! (/tmp/wiped-after-boot -nt /proc/uptime) && -r /proc/version &&
      "$(</proc/version)" == *Microsoft* ]]; then
  print -Pr -- "%F{3}zsh%f: wiping %U/tmp%u ..."
  sudo rm -rf -- /tmp/*(ND)
  : >/tmp/wiped-after-boot
fi

# Clone additional Git repositories from GitHub.
#
# This doesn't do anything apart from cloning the repository and keeping it
# up-to-date. Cloned files can be used after `z4h init`. This is just an
# example. If you don't plan to use Oh My Zsh, delete this line.
z4h install ohmyzsh/ohmyzsh || return

z4h install romkatv/archive romkatv/zsh-prompt-benchmark

# Install or update core components (fzf, zsh-autosuggestions, etc.) and
# initialize Zsh. After this point console I/O is unavailable until Zsh
# is fully initialized. Everything that requires user interaction or can
# perform network I/O must be done above. Everything else is best done below.
z4h init || return

setopt glob_dots magic_equal_subst no_multi_os no_local_loops
setopt rm_star_silent rc_quotes glob_star_short

ulimit -c $(((4 << 30) / 512))  # 4GB

# Extend PATH.
path=(~/.local/bin $path)
path+=('/mnt/c/Program Files/Microsoft VS Code/bin'(-/N))

fpath=($Z4H/romkatv/archive $fpath)
[[ -d ~/.dots/hack/zsh-functions ]] && fpath=(~/.dots/hack/zsh-functions $fpath)

autoload -Uz -- zmv archive lsarchive unarchive ~/.dots/hack/zsh-functions/[^_]*(N:t)

# Export environment variables.
export GPG_TTY=$TTY
export PAGER=less
export GOPATH=$HOME/go
export SYSTEMD_LESS=${LESS}S
export HOMEBREW_NO_ANALYTICS=1
export MANOPT=--no-hyphenation

() {
  local hist
  for hist in ~/.dots-private/.zsh_history*~$HISTFILE(N); do
    fc -RI $hist
  done
}

# Source additional local files if they exist.
z4h source ~/.env.zsh

# Use additional Git repositories pulled in with `z4h install`.
#
# This is just an example that you should delete. It does nothing useful.
z4h source ohmyzsh/ohmyzsh/lib/diagnostics.zsh  # source an individual file
z4h load   ohmyzsh/ohmyzsh/plugins/emoji-clock  # load a plugin

# Define key bindings.
z4h bindkey z4h-backward-kill-word  Ctrl+Backspace     Ctrl+H
z4h bindkey z4h-backward-kill-zword Ctrl+Alt+Backspace

z4h bindkey undo Ctrl+/ Shift+Tab  # undo the last command line change
z4h bindkey redo Alt+/             # redo the last undone command line change

z4h bindkey z4h-cd-back    Alt+Left   # cd into the previous directory
z4h bindkey z4h-cd-forward Alt+Right  # cd into the next directory
z4h bindkey z4h-cd-up      Alt+Up     # cd into the parent directory
z4h bindkey z4h-cd-down    Alt+Down   # cd into a child directory

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $z4h_win_home ]] || hash -d w=$z4h_win_home

# Define aliases.
alias tree='tree -a -I .git'

# Add flags to existing aliases.
alias ls="${aliases[ls]:-ls} -A"

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gc="git checkout"
alias gcp="git cherry-pick"
alias gp="git pull"
alias gpu="git push"
alias ga="git add"
alias gcm="git commit -m"
alias gct="git commit"
alias grh="git reset --hard"
alias grm="git reset --mixed"
