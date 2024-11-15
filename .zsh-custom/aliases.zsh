# basic
alias ls='ls --color'
alias c='clear'
alias tree='tree -a -I .git'
# find the first tag contains COMMIT_HASH
tac() {
  local COMMIT_HASH=$1
  git describe --tags $(git rev-list --tags --reverse --ancestry-path ${COMMIT_HASH}..HEAD) | head -n 1
}
# proxy
alias setp="export ALL_PROXY=http://127.0.0.1:7890; export HTTP_PROXY=http://127.0.0.1:7890; export HTTPS_PROXY=http://127.0.0.1:7890; export no_proxy='localhost,127.0.0.1,.megvii-inc.com'"
alias usetp="unset ALL_PROXY; unset HTTP_PROXY; unset HTTPS_PROXY; unset all_proxy; unset http_proxy; unset https_proxy"
alias cip="curl 'http://ip-api.com/json/?lang=zh-CN'"
fly() {
    if [[ "$*" == *"?"* ]] || [[ "$*" == *"#"* ]] || [[ "$*" == *"*"* ]]; then
        # Use noglob only when command contains special characters
        proxychains4 -q -f ${HOME}/.config/proxychains/fly.conf zsh -ic "noglob $*"
    else
        # Normal command without special characters, allow alias expansion
        proxychains4 -q -f ${HOME}/.config/proxychains/fly.conf zsh -ic "$*"
    fi
}
work() {
    if [[ "$*" == *"?"* ]] || [[ "$*" == *"#"* ]] || [[ "$*" == *"*"* ]]; then
        # Use noglob only when command contains special characters
        proxychains4 -q -f ${HOME}/.config/proxychains/work.conf zsh -ic "noglob $*"
    else
        # Normal command without special characters, allow alias expansion
        proxychains4 -q -f ${HOME}/.config/proxychains/work.conf zsh -ic "$*"
    fi
}
# kube
# manage multiple kubeconfig
export KUBECONFIG=$(find ~/.kube -maxdepth 1 -type f -name "config*" | paste -sd ":" -)
kpd() {
    read namespace podname <<< $(kubectl get pods -A | percol | awk '{print $1, $2}')
    kubectl describe pod "$podname" -n "$namespace" "$@"
}

kpe() {
    read namespace podname <<< $(kubectl get pods -A | percol | awk '{print $1, $2}')
    kubectl edit pod "$podname" -n "$namespace" "$@"
}

kpl() {
    read namespace podname <<< $(kubectl get pods -A | percol | awk '{print $1, $2}')
    containers=$(kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')
    containername=$(echo $containers | tr ' ' '\n' | percol)
    kubectl logs "$podname" -n "$namespace" -c "$containername" "$@"
}

kpc() {
    read namespace podname <<< $(kubectl get pods -A | percol | awk '{print $1, $2}')
    kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' "$@"
}

kpvcd() {
    read namespace podname <<< $(kubectl get pvc -A | percol | awk '{print $1, $2}')
    kubectl delete pvc "$podname" -n "$namespace"
}

kpvd() {
    read namespace podname <<< $(kubectl get pv -A | percol | awk '{print $1, $2}')
    kubectl delete pv "$podname" -n "$namespace"
}

# krdn - Kubectl Resource Delete in Namespace
#
# This function provides an interactive way to safely delete Kubernetes resources
# within a specified namespace. It includes validation, confirmation prompts,
# and detailed progress reporting.
#
# Usage:
#     krdn <namespace> <resourceType> [--force]
#
# Arguments:
#     namespace    - The Kubernetes namespace containing the resources
#     resourceType - The type of Kubernetes resource to delete (pods, deployments, etc.)
#     --force     - (Optional) Skip confirmation prompt and delete immediately
#
# Examples:
#     krdn default pods         # Delete all pods in default namespace
#     krdn dev deployments     # Delete all deployments in dev namespace
#     krdn prod services --force # Force delete all services in prod namespace
#
# Features:
#     - Validates namespace existence
#     - Confirms resource type validity
#     - Interactive confirmation (unless --force is used)
#     - Progress tracking for each deletion
#     - Summary report of successful/failed deletions
#
# Exit Codes:
#     0 - Success or user cancelled
#     1 - Error (invalid input, resource not found, deletion failed)
#
# Notes:
#     - Use with caution in production environments
#     - Consider resource dependencies before deletion
#     - Some resources may have finalizers preventing immediate deletion
#
krdn() {
    local usage="Usage: krdn <namespace> <resourceType> [--force]"
    
    # Input validation with more descriptive messages
    if [ $# -lt 2 ]; then
        echo "$usage"
        echo "Example: krdn default pods"
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
    done <<< "$resources"
    
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
  docker container ls | percol | awk '{print $1}' | xargs -I {} sh -c 'docker stop {} && docker rm {}'
}
dcl() {
  docker container ls | percol | awk '{print $1}' | xargs -I {} sh -c 'docker logs -f {}'
}
dis() {
    local image_tag=$1
    docker history --no-trunc --format "{{.Size}}, {{.CreatedBy}}" "${image_tag}" | grep -v 0B
}
dir() {
  docker image ls | percol | awk '{print $1":"$2}' | xargs -I {} docker image rm {}
}
# copy image from one registry to another, useful when you are dealing with multi-arch images.
dic() {
  TAG=$1
  skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false --multi-arch=all docker://${SRC_REGISTRY}/${TAG} docker://${DST_REGISTRY}/${TAG}
}
# systemctl
alias scs="sudo systemctl status"
alias sct="sudo systemctl start"
alias scr="sudo systemctl restart"
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
# keys from burn.hair
ebo() {
  export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/burnopenaikey.gpg)
  export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/burnopenaibase.gpg)
}
# keys from wild
ew() {
  export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapikey.gpg)
  export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)/v1
  export ANTHROPIC_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapikey.gpg)
  export ANTHROPIC_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)
}

eg() {
  export GITLAB_TOKEN=$(gpg --quiet --decrypt ${HOME}/.gpgs/gitlabkey.gpg)
  export GITLAB_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/gitlabbase.gpg)
}
# clean sensitive env && make gpg require password immediately
alias clai="unset OPENAI_API_KEY && unset OPENAI_API_BASE && unset ANTHROPIC_API_KEY && unset ANTHROPIC_BASE_URL && gpgconf --kill gpg-agent"
alias clgit="unset GITLAB_TOKEN && unset GITLAB_URL && gpgconf --kill gpg-agent"
