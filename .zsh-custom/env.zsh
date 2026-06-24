export PAGER=less                      # Use 'less' as the default pager for viewing long outputs
export EDITOR='nvim'                   # Set Neovim as the default text editor
export MD_HEADING_BG=transparent       # neobean markdown heading style
export SYSTEMD_LESS=${LESS}S           # Configure 'less' for systemd logs to fold long lines
export MANOPT=--no-hyphenation         # Display man pages without hyphenation for better readability
export XDG_CONFIG_HOME="$HOME/.config" # Set the base directory for user-specific configuration files

export PATH="${HOME}/.local/bin":${PATH}    # add local path for current user
export PATH="${HOME}/.npm-global/bin:$PATH" # add npm global bin path, remeber do: npm set prefix ~/.npm-global
export PATH="${HOME}/.kimi-code/bin:$PATH"  # kimi code don't add itself in .local/bin

# add go env variables
if command -v go >/dev/null 2>&1 && [ -z "${GOPATH}" ]; then
  export GOPATH=$(go env GOPATH)
  export GOBIN="${GOPATH}/bin"   # Set the Go binary directory
  export PATH="${GOBIN}:${PATH}" # Add Go binary directory to PATH
fi

export WORDCHARS=$'!"$%&\'()*+,-.:;<>@[\\]^_`{|}~'

if [[ "$(</proc/version)" == *[Mm]icrosoft* ]] 2>/dev/null; then
  export WSL_LIB_PATH="/usr/lib/wsl/lib/"
  case ":$PATH:" in
    *":$WSL_LIB_PATH:"*) ;;
    *) export PATH="$WSL_LIB_PATH:$PATH" ;;
  esac
fi

if [ -e "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="${HOME}/.cargo/bin:${PATH}"
fi

export SHELL=$(which zsh)
export GPG_TTY=$TTY

[[ -s /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh ]] && source /etc/profiles/per-user/"$USER"/etc/profile.d/hm-session-vars.sh || true

# enable claude code full screen render mode by default
export CLAUDE_CODE_NO_FLICKER=1

# default Opus reasoning effort to max (only persistable via env var)
export CLAUDE_CODE_EFFORT_LEVEL=max

export AGENT_BROWSER_IDLE_TIMEOUT_MS=600000
export AGENT_BROWSER_DEFAULT_TIMEOUT=60000

export STAFF_KEY=$(pass show work/staff-key)
export KOKUB_API_KEY=$(pass show work/kth/key/vb)
export KIMI_CODE_EXPERIMENTAL_FLAG=1
