# if custom aliases file exists, source it
if [ -f "${HOME}/.aliases_custom.zsh" ]; then
  source "${HOME}/.aliases_custom.zsh"
fi

# basic
alias ls='ls --color'
alias c='clear'
alias tree='tree -a -I .git'
# find the first tag contains COMMIT_HASH (renamed from tac to avoid conflict with GNU coreutils tac)
gft() {
  local COMMIT_HASH=$1
  git describe --tags $(git rev-list --tags --reverse --ancestry-path "${COMMIT_HASH}"..HEAD) | head -n 1
}
# proxy
alias setp="export ALL_PROXY=http://127.0.0.1:7890; export HTTP_PROXY=http://127.0.0.1:7890; export HTTPS_PROXY=http://127.0.0.1:7890"
alias usetp="unset ALL_PROXY; unset HTTP_PROXY; unset HTTPS_PROXY; unset all_proxy; unset http_proxy; unset https_proxy"
alias cip="curl 'http://ip-api.com/json/?lang=zh-CN'"
# kube
# manage multiple kubeconfig
if [ -d ~/.kube ]; then
  FOUND_CONFIGS=$(find ~/.kube -maxdepth 1 -type f -name "*config*" | paste -sd ":" -)
  if [ -n "$FOUND_CONFIGS" ]; then
    export KUBECONFIG="$FOUND_CONFIGS"
  fi
fi

# pod::
kpd() {
  read namespace podname <<<$(kubectl get pods -A | fzf --header-lines=1 | awk '{print $1, $2}')
  kubectl describe pod "$podname" -n "$namespace" "$@"
}

kpe() {
  read namespace podname <<<$(kubectl get pods -A | fzf --header-lines=1 | awk '{print $1, $2}')
  kubectl edit pod "$podname" -n "$namespace" "$@"
}

kpl() {
  read namespace podname <<<$(kubectl get pods -A | fzf --header-lines=1 | awk '{print $1, $2}')
  containers=$(kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')
  containername=$(echo "$containers" | tr ' ' '\n' | fzf)
  kubectl logs "$podname" -n "$namespace" -c "$containername" "$@"
}

kpc() {
  read namespace podname <<<$(kubectl get pods -A | fzf --header-lines=1 | awk '{print $1, $2}')
  kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' "$@"
}

# debug::
kd() {
  local namespace=$1
  local podname
  if [[ -n $namespace ]]; then
    read podname <<<$(kubectl get pods -n "$namespace" | fzf --header-lines=1 | awk '{print $1}')
  else
    read namespace podname <<<$(kubectl get pods -A | fzf --header-lines=1 | awk '{print $1, $2}')
  fi
  containers=$(kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')
  containername=$(echo "$containers" | tr ' ' '\n' | fzf)
  kubectl debug "${podname}" -n "${namespace}" -it --copy-to="${podname}"-$(date +%Y%m%d-%H%M%S)-debug --container="${containername}" -- bash
}

# delete::
kdd() {
  local namespace=$1
  local debug_pods
  if [[ -n $namespace ]]; then
    debug_pods=$(kubectl get pods -n "$namespace" --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep -- '-debug' || true)
  else
    debug_pods=$(kubectl get pods -A --no-headers -o custom-columns=":metadata.namespace,:metadata.name" 2>/dev/null | awk '{print $2,$1}' | grep -- '-debug' || true)
  fi
  if [ -z "$debug_pods" ]; then
    if [ -n "$namespace" ]; then
      echo "No debug pods found in namespace '$namespace'"
    else
      echo "No debug pods found in any namespace"
    fi
    return 0
  fi

  # Count and display debug pods
  local pod_count=$(echo "$debug_pods" | wc -l | tr -d ' ')
  echo -e "\nFound $pod_count debug pod(s):"
  echo "$debug_pods" | while IFS= read -r line; do
    read pod_name ns <<<"$line"
    echo "- $pod_name (namespace: $ns)"
  done

  # Ask for confirmation
  echo -e "\nAre you sure you want to delete these debug pods? (y/N): "
  read -r confirm

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    return 0
  fi

  echo -e "\nDeleting debug pods..."
  local deleted_count=0
  local failed_count=0

  echo "$debug_pods" | while IFS= read -r line; do
    read pod_name ns <<<"$line"
    if kubectl delete pod "$pod_name" -n "$ns" &>/dev/null; then
      echo "✓ Deleted $pod_name in namespace $ns"
      ((deleted_count++))
    else
      echo "✗ Failed to delete $pod_name in namespace $ns"
      ((failed_count++))
    fi
  done

  # Summary
  echo -e "\nDeletion Summary:"
  echo "- Total debug pods processed: $pod_count"
  if [ $failed_count -gt 0 ]; then
    echo "- Failed deletions may require manual intervention"
  fi
}

kdr() {
  resource_type=$1
  if [ -z "$resource_type" ]; then
    echo "Usage: kdr <resourceType>"
    return 1
  fi
  read namespace resource_name <<<$(kubectl get "$resource_type" -A | fzy | awk '{print $1, $2}')
  kubectl delete "$resource_type" "$resource_name" -n "$namespace"
}

# pvc::
kpvcd() {
  read namespace pvcname <<<$(kubectl get pvc -A | fzf --header-lines=1 | awk '{print $1, $2}')
  kubectl delete pvc "$pvcname" -n "$namespace"
}

# pv:: (PV is cluster-scoped, no namespace)
kpvd() {
  local pvname=$(kubectl get pv | fzf --header-lines=1 | awk '{print $1}')
  kubectl delete pv "$pvname"
}

# context::
ksc() {
  context_name=$(kubectl config get-contexts | fzy | awk '{print $1}')
  kubectl config use-context "$context_name"
}

# remove::
krdn() {
  local usage="Usage: krdn <namespace> <resourceType> [--force]"

  # Input validation with more descriptive messages
  if [ $# -lt 2 ]; then
    echo "$usage"
    echo "Exapmle: krdn default pods"
    return 1
  fi

  local namespace="$1"
  local resourceType="$2"
  local force_delete=false

  # Check for force flag
  if [ "$3" = "--force" ]; then
    force_delete=true
  fi

  # Validate namespace exists
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    echo "Error: Namespace '$namespace' does not exist"
    return 1
  fi

  # Get list of resources with error handling
  local resources
  if ! resources=$(kubectl get "$resourceType" -n "$namespace" --no-headers -o custom-columns=":metadata.name" 2>/dev/null); then
    echo "Error: Failed to get resources of type '$resourceType' in namespace '$namespace'"
    echo "Please check if the resource type is valid"
    return 1
  fi

  if [ -z "$resources" ]; then
    echo "No resources of type '$resourceType' found in namespace '$namespace'"
    return 0
  fi

  # Show resources that will be deleted with count
  local resource_count=$(echo "$resources" | wc -l)
  echo -e "\nFound $resource_count $resourceType(s) in namespace '$namespace':"
  echo "$resources" | sed 's/^/- /'

  # Skip confirmation if force flag is used
  if [ "$force_delete" = true ]; then
    echo -e "\nForce flag detected - proceeding with deletion..."
  else
    # Ask for confirmation (compatible with bash and zsh)
    echo -e "\nAre you sure you want to delete these resources? (y/N): "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Operation cancelled"
      return 0
    fi
  fi

  # Delete resources with progress indicator
  echo -e "\nDeleting resources..."
  local deleted_count=0
  local failed_count=0

  while IFS= read -r resource; do
    if kubectl delete "$resourceType" "$resource" -n "$namespace" &>/dev/null; then
      echo "✓ Deleted $resource"
      ((deleted_count++))
    else
      echo "✗ Failed to delete $resource"
      ((failed_count++))
    fi
  done <<<"$resources"

  # Summary
  echo -e "\nDeletion Summary:"
  echo "- Successfully deleted: $deleted_count"
  if [ $failed_count -gt 0 ]; then
    echo "- Failed to delete: $failed_count"
    return 1
  fi
}

# try different nvim distro
[[ -s "${HOME}/.nvim_appnames" ]] && source "${HOME}/.nvim_appnames" || true

# docker
dcr() {
  docker container ls | fzy | awk '{print $1}' | xargs -I {} sh -c 'docker stop {} && docker rm {}'
}
dcl() {
  docker container ls | fzy | awk '{print $1}' | xargs -I {} sh -c 'docker logs -f {}'
}
dis() {
  local image_tag=$(docker image ls | fzy | awk '{print $1":"$2}')
  docker history --no-trunc --format "{{.Size}}, {{.CreatedBy}}" "${image_tag}" | grep -v 0B
}
dir() {
  docker image ls | fzy | awk '{print $1":"$2}' | xargs -I {} docker image rm {}
}
# copy image from one registry to another, useful when you are dealing with multi-arch images.
dic() {
  SRC_REGISTRY=$1
  DST_REGISTRY=$2
  TAG=$3
  skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false --multi-arch=all docker://"${SRC_REGISTRY}"/"${TAG}" docker://"${DST_REGISTRY}"/"${TAG}"
}

# fix windows wsl clock drift
sync_time() {
  if sudo echo Starting time sync in background; then
    sudo nohup watch -n 10 hwclock -s >/dev/null 2>&1 &
  fi
}

_set_common_api_keys() {
  export TAVILY_API_KEY=$(pass show ai/tavily/key)
  export GITHUB_PERSONAL_ACCESS_TOKEN=$(pass show git/github/token)
}

alias clai="unset TAVILY_API_KEY"
alias clan="unset ANTHROPIC_API_KEY && unset ANTHROPIC_API_BASE && unset ANTHROPIC_BASE_URL && unset ANTHROPIC_SMALL_FAST_MODEL && unset ANTHROPIC_MODEL"

_expand_envs() {
  local src="$1"
  local tmp=$(mktemp)
  envsubst <"$src" >"$tmp"
  echo "$tmp"
}

psops() {
  pass show age/identity | SOPS_AGE_KEY_FILE=/dev/stdin sops "$@"
}

_set_garage_env() {
  export AWS_ACCESS_KEY_ID="$(pass show s3/garage/access-key)"
  export AWS_SECRET_ACCESS_KEY="$(pass show s3/garage/secret-key)"
}

_decrypt_sops() {
  local src="$1"
  local tmp=$(mktemp)
  psops --decrypt "$src" >"$tmp"
  echo "$tmp"
}

# Private per-repo instructions for coding agents, without touching a shared
# repo's tracked files. Two modes, told apart by the marker line:
# - Append: AGENTS.local.md holds the private half. codex and pi prefer
#   AGENTS.override.md over AGENTS.md in the same directory, so the override is
#   regenerated as marker + team + private on every launch and can never go stale.
# - Replace: a hand-written AGENTS.override.md (no marker) fully overrides a stale
#   team file. It is never touched here, and AGENTS.local.md is then ignored.
_AGENTS_SYNC_MARKER='<!-- generated by _agents_sync from AGENTS.md + AGENTS.local.md; edit AGENTS.local.md instead -->'

_agents_override_handwritten() {
  local first
  [[ -f AGENTS.override.md ]] || return 1
  read -r first <AGENTS.override.md
  [[ $first != "$_AGENTS_SYNC_MARKER" ]]
}

_agents_sync() {
  if _agents_override_handwritten; then
    [[ -f AGENTS.local.md ]] && print -u2 "AGENTS.local.md ignored: hand-written AGENTS.override.md takes precedence"
    return 0
  fi
  if [[ -f AGENTS.md && -f AGENTS.local.md ]]; then
    { print -r -- "$_AGENTS_SYNC_MARKER"; print; cat AGENTS.md; print; print -- '---'; print; cat AGENTS.local.md } >AGENTS.override.md
  else
    rm -f AGENTS.override.md
  fi
}

# Claude Code has no per-repo override file — every CLAUDE.md source is additive
# and it never reads AGENTS.md. Append mode needs nothing extra: CLAUDE.local.md
# imports @AGENTS.local.md. Replace mode takes the kill switch plus feeding the
# user memory and the hand-written override back in, which also drops the repo's
# nested CLAUDE.md and .claude/rules/ — the point of a full override.
_claude_run() {
  _agents_sync
  if _agents_override_handwritten; then
    CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 command claude \
      --append-system-prompt "$(cat "${HOME}/.agents/AGENTS.md" 2>/dev/null; print; cat AGENTS.override.md)" "$@"
    return
  fi
  if [[ -f AGENTS.local.md ]] && ! grep -qF '@AGENTS.local.md' CLAUDE.local.md 2>/dev/null; then
    print -u2 "warning: CLAUDE.local.md does not import @AGENTS.local.md, Claude will not see it"
  fi
  command claude "$@"
}

yolo() {
  if [[ "$1" == "update" ]]; then
    npm install -g @anthropic-ai/claude-code@latest
  else
    local cfg=$(_expand_envs "${HOME}/.mcp/default.json")
    _claude_run --dangerously-skip-permissions --mcp-config "$cfg" "$@"
    rm -f "$cfg"
  fi
}

cdx() {
  if [[ "$1" == "update" ]]; then
    npm install -g @openai/codex@latest
  else
    _agents_sync
    codex --search --dangerously-bypass-approvals-and-sandbox "$@"
  fi
}

pix() {
  if [[ "$1" == "update" ]]; then
    pi update self
  else
    _agents_sync
    pi "$@"
  fi
}

gmi() {
  if [[ "$1" == "update" ]]; then
    npm install -g @google/gemini-cli@latest
  else
    gemini "$@"
  fi
}

alias s="kitten ssh"

mm() {
  local cfg=$(_expand_envs "${HOME}/.mcp/default.json")
  kimi --yolo --mcp-config-file "$cfg" "$@"
  rm -f "$cfg"
}
mc() {
  local cfg=$(_expand_envs "${HOME}/.mcp/default.json")
  kimi --yolo --mcp-config-file "$cfg" --config-file "${HOME}/.kimi/codex.toml" "$@"
  rm -f "$cfg"
}

alias oo="opencode"

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || exit
  fi
  rm -f -- "$tmp"
}

alias twg='cd "$(twiggle --icons)"'

killport() {
  kill -9 "$(lsof -ti:"$1")"
}

# Debug Chrome that agent-browser drives over CDP (port 9222) with the user's
# login state but WITHOUT the per-connection "Allow remote debugging?" popup.
# Backed by the share-chrome-profiles skill.
chrome-debug() {
  local s="$HOME/.claude/skills/share-chrome-profiles/scripts"
  case "$1" in
    sync)
      shift
      "$s/sync-profile.sh" "$@"
      ;;
    '' | up) "$s/launch-debug-chrome.sh" ;;
    headless) "$s/launch-debug-chrome.sh" --headless ;; # no window → never steals focus
    personal) "$s/launch-personal-chrome.sh" ;;         # your real Chrome, agent ignores it
    *)
      print -u2 "usage: chrome-debug [up|headless|personal|sync [--with-indexeddb|--force]]"
      return 2
      ;;
  esac
}

# Tag every node_modules under the given roots (default ~/repos) with a
# `.metadata_never_index` sentinel so Spotlight skips the whole subtree.
# `npm install` recreates node_modules without it, so re-run after big installs.
mdignore() {
  local roots=("${@:-$HOME/repos}") root n=0 d
  for root in "${roots[@]}"; do
    [[ -d $root ]] || {
      print -u2 "mdignore: not a directory: $root"
      continue
    }
    while IFS= read -r d; do
      touch -- "$d/.metadata_never_index" && ((n++))
    done < <(find "$root" -type d -name node_modules -prune -print)
  done
  print "mdignore: tagged $n node_modules dir(s) under ${roots[*]}"
  print "  run 'sudo mdutil -E /' to make Spotlight drop them from the index now"
}

# jj has no hook system, so workspace creation has to be wrapped. git worktree
# add does fire post-checkout, but one command for both beats two mechanisms.
# Destination comes first; everything after it is passed through, which both
# `jj workspace add` and `git worktree add` accept.
# Kept self-contained: Claude Code's shell snapshot drops `_`-prefixed functions
# and global arrays, so helpers defined outside would be missing for agents.
mkws() {
  # Deliberately ignored files that every workspace still wants, symlinked so one
  # edit reaches all of them. AGENTS.override.md is absent: _agents_sync
  # regenerates it per workspace, and writing through a symlink would clobber the
  # source worktree's.
  local -a carry=(AGENTS.local.md CLAUDE.local.md .envrc)
  local dst=$1 src vcs f visible
  if [[ -z $dst ]]; then
    print -u2 "usage: mkws <dir> [jj workspace add / git worktree add args...]"
    return 2
  fi
  shift
  if jj workspace root >/dev/null 2>&1; then
    vcs=jj src=$(jj workspace root)
    jj workspace add "$dst" "$@" || return
  else
    vcs=git src=$(git rev-parse --show-toplevel) || return
    git worktree add "$dst" "$@" || return
  fi

  for f in $carry; do
    [[ -e $src/$f && ! -e $dst/$f ]] || continue
    ln -s "$src/$f" "$dst/$f" || continue
    # Only ignored paths may be carried — a symlink the VCS picks up would get
    # committed into a shared repo. .envrc is the usual offender: ignored in most
    # repos but committed in some.
    if [[ $vcs == jj ]]; then
      visible=$(cd "$dst" && jj diff --name-only 2>/dev/null | grep -xF -- "$f")
    else
      visible=$(git -C "$dst" status --porcelain --untracked-files=all -- "$f" 2>/dev/null)
    fi
    if [[ -n $visible ]]; then
      rm -f "$dst/$f"
      print -u2 "skipped $f: not ignored here, the symlink would get committed"
    else
      print "carried $f"
    fi
  done
  if [[ -e $dst/.envrc ]] && (( $+commands[direnv] )); then
    (cd "$dst" && direnv allow) && print "direnv allow $dst"
  fi
  return 0
}

jjwsrm() {
  local ws dir
  for ws in "$@"; do
    dir=$(jj workspace list | awk -v ws="$ws:" '$1 == ws {print $2}')
    if [ -z "$dir" ]; then
      echo "skip $ws: workspace not found" >&2
      continue
    fi
    echo "forget $ws && rm $dir"
    jj workspace forget "$ws" && rm -rf -- "$dir"
  done
}
