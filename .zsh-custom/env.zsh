export PAGER=less                              # Use 'less' as the default pager for viewing long outputs
export EDITOR='nvim'                           # Set Neovim as the default text editor
export GPG_TTY=$TTY                            # Set GPG to use the current terminal for passphrase prompts
export SYSTEMD_LESS=${LESS}S                   # Configure 'less' for systemd logs to fold long lines
export MANOPT=--no-hyphenation                 # Display man pages without hyphenation for better readability
export XDG_CONFIG_HOME="$HOME/.config"         # Set the base directory for user-specific configuration files

export PATH="${HOME}/.local/bin":${PATH}       # add local path for current user
export PATH="${HOME}/.npm-global/bin:$PATH"      # add npm global bin path, remeber do: npm set prefix ~/.npm-global

# add go env variables
if command -v go >/dev/null 2>&1 && [ -z "${GOPATH}" ]; then
    export GOPATH=$(go env GOPATH)
    export GOBIN="${GOPATH}/bin"                   # Set the Go binary directory
    export PATH="${GOBIN}:${PATH}"                 # Add Go binary directory to PATH
fi

export WORDCHARS=$'!"$%&\'()*+,-.:;<>@[\\]^_`{|}~'

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

export SHELL=$(which zsh)
