export PAGER=less                              # Use 'less' as the default pager for viewing long outputs
export EDITOR='nvim'                           # Set Neovim as the default text editor
export GPG_TTY=$TTY                            # Set GPG to use the current terminal for passphrase prompts
export LANGUAGE=en_US.UTF-8                    # Set the language for the locale to English (UTF-8)
export LC_ALL=en_US.UTF-8                      # Override all locale settings to use English (UTF-8)
export LANG=en_US.UTF-8                        # Set the default locale to English (UTF-8)
export LC_CTYPE=en_US.UTF-8                    # Set the character encoding to UTF-8 for the terminal
export HOMEBREW_NO_AUTO_UPDATE=1               # Prevent Homebrew from auto-updating before operations
export SYSTEMD_LESS=${LESS}S                   # Configure 'less' for systemd logs to fold long lines
export HOMEBREW_NO_ANALYTICS=1                 # Disable Homebrew analytics data collection
export MANOPT=--no-hyphenation                 # Display man pages without hyphenation for better readability
export XDG_CONFIG_HOME="$HOME/.config"         # Set the base directory for user-specific configuration files
export PATH="${HOME}/.local/bin":${PATH}       # add local path for current user

export HOMEBREW_INSTALL_FROM_API=1
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"

if [[ "$(</proc/version)" == *[Mm]icrosoft* ]] 2>/dev/null; then
  export WSL_LIB_PATH="/usr/lib/wsl/lib/"
  case ":$PATH:" in
    *":$WSL_LIB_PATH:"*) ;;
    *) export PATH="$WSL_LIB_PATH:$PATH" ;;
  esac
fi

if [ -e "$HOME"/.cargo/env ]; then
  . "$HOME/.cargo/env"
fi
