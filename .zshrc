# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -r "${HOME}/.zsh-custom/init.zsh" ]]; then
    source ${HOME}/.zsh-custom/init.zsh
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins (order matters: syntax-highlighting must be last)
zinit light zsh-users/zsh-completions

# Turbo mode for deferred loading (improves startup time)
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light Aloxaf/fzf-tab

zinit ice wait lucid
zinit light MoonshotAI/zsh-kimi-cli

# syntax-highlighting must be loaded last
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

# Load completions with caching (regenerate only once per day)
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# custom
[[ -s ${HOME}/.zsh-custom/config.zsh ]] && source ${HOME}/.zsh-custom/config.zsh || true
[[ -s ${HOME}/.zsh-custom/env.zsh ]] && source ${HOME}/.zsh-custom/env.zsh || true
[[ -s ${HOME}/.zsh-custom/aliases.zsh ]] && source ${HOME}/.zsh-custom/aliases.zsh || true
[[ -s ${HOME}/.zsh-custom/thirdparty.zsh ]] && source ${HOME}/.zsh-custom/thirdparty.zsh || true

[[ -s ${HOME}/.${(%):-%m}.zsh ]] && source ${HOME}/.${(%):-%m}.zsh || true

[[ -s ${HOME}/.zsh-custom/post.zsh ]] && source ${HOME}/.zsh-custom/post.zsh || true
