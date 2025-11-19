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
alias setp="export ALL_PROXY=http://127.0.0.1:7890; export HTTP_PROXY=http://127.0.0.1:7890; export HTTPS_PROXY=http://127.0.0.1:7890; export no_proxy='localhost,127.0.0.1,msh.team,msh.work,launchpad,svc,ivolces.com,aliyuncs.com,ksyun.cn,volces.com,aliyun.com,goproxy.cn'"
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
if [ -d ~/.kube ]; then
    FOUND_CONFIGS=$(find ~/.kube -maxdepth 1 -type f -name "config*" | paste -sd ":" -)
    if [ -n "$FOUND_CONFIGS" ]; then
        export KUBECONFIG="$FOUND_CONFIGS"
    fi
fi

# pod:: 
kpd() {
    read namespace podname <<< $(kubectl get pods -A | fzy | awk '{print $1, $2}')
    kubectl describe pod "$podname" -n "$namespace" "$@"
}

kpe() {
    read namespace podname <<< $(kubectl get pods -A | fzy | awk '{print $1, $2}')
    kubectl edit pod "$podname" -n "$namespace" "$@"
}

kpl() {
    read namespace podname <<< $(kubectl get pods -A | fzy | awk '{print $1, $2}')
    containers=$(kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')
    containername=$(echo $containers | tr ' ' '\n' | fzy)
    kubectl logs "$podname" -n "$namespace" -c "$containername" "$@"
}

kpc() {
    read namespace podname <<< $(kubectl get pods -A | fzy | awk '{print $1, $2}')
    kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' "$@"
}

# debug::
kd() {
    local namespace=$1
    local podname
    if [[ -n $namespace ]]; then
      read podname <<< $(kubectl get pods -n $namespace | fzy | awk '{print $1}')
    else
      read namespace podname <<< $(kubectl get pods -A | fzy | awk '{print $1, $2}')
    fi
    containers=$(kubectl get pod "$podname" -n "$namespace" -o jsonpath='{.spec.containers[*].name}')
    containername=$(echo $containers | tr ' ' '\n' | fzy)
    kubectl debug ${podname} -n ${namespace} -it --copy-to=${podname}-$(date +%Y%m%d-%H%M%S)-debug --container=${containername} -- bash
}

kdd() {
    local namespace=$1
    local debug_pods
    if [[ -n $namespace ]]; then
        debug_pods=$(kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep -- '-debug' || true)
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
        read pod_name ns <<< "$line"
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
        read pod_name ns <<< "$line"
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

# pvc::
kpvcd() {
    read namespace pvcname <<< $(kubectl get pvc -A | fzy | awk '{print $1, $2}')
    kubectl delete pvc "$pvcname" -n "$namespace"
}

kpvd() {
    read namespace pvcname <<< $(kubectl get pv -A | fzy | awk '{print $1, $2}')
    kubectl delete pv "$pvcname" -n "$namespace"
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
    skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false --multi-arch=all docker://${SRC_REGISTRY}/${TAG} docker://${DST_REGISTRY}/${TAG}
}

# fix windows wsl clock drift
sync_time(){
    if sudo echo Starting time sync in background
    then
        sudo nohup watch -n 10 hwclock -s > /dev/null 2>&1 &
    fi
}

# Helper function to set common API keys and environment variables
_set_common_api_keys() {
    export TAVILY_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/tavilykey.gpg)
    export DEEPSEEK_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/deepseekkey.gpg)
    export DEEPSEEK_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/deepseekbase.gpg)
    export MOONSHOT_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/msapikey.gpg)
    export MOONSHOT_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msapibase.gpg)
    export MOONSHOT_IAPI_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapikey.gpg)
    export MOONSHOT_STAFF_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapikey.gpg)
    export MOONSHOT_IAPI_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapibase.gpg)
    export MOONSHOT_IAPI_AN_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msiapianbase.gpg)
    export GEMINI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/geminikey.gpg)
    export MOONSHOT_APM_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msapmbase.gpg)
    export MOONSHOT_APM_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/msapmapikey.gpg)
    export MOONSHOT_RESEARCH_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/researchkey.gpg)
    export MOONSHOT_RESEARCH_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/researchbase.gpg)
    export RESEARCH_MCP_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/researchmcpbase.gpg)
    export RESEARCH_MCP_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/researchmcpkey.gpg)
    export TOKENISM_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/tokenismkey.gpg)
    export MSUSER=$(gpg --quiet --decrypt ${HOME}/.gpgs/msgituser.gpg)
    export MSGITTOKEN=$(gpg --quiet --decrypt ${HOME}/.gpgs/msgittoken.gpg)
    export MSGITPROXYBASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msproxybase.gpg)
    export MSDOMAINBASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/msdomainbase.gpg)
    export GOPROXY=$MSUSER:$MSGITTOKEN@$MSGITPROXYBASE,https://goproxy.cn,direct
    export GITHUB_PERSONAL_ACCESS_TOKEN=$(gpg --quiet --decrypt ${HOME}/.gpgs/githubtoken.gpg)
    export GROQ_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/groqapikey.gpg)
    export GROQ_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/groqapibase.gpg)
    export LOCAL_ENDPOINT=$MOONSHOT_API_BASE
    export LOCAL_ENDPOINT_API_KEY=$MOONSHOT_API_KEY
    export MORPH_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/morphapikey.gpg)
}

# Set environment for Wild API
ew() {
    export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapikey.gpg)
    export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)/v1
    export OPENAI_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)/v1
    export CUSTOM_ANTHROPIC_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapikey.gpg)
    export CUSTOM_ANTHROPIC_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)
    export CUSTOM_ANTHROPIC_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/wildapibase.gpg)
}

# Set environment for BH API
eallinone() {
    # BH API specific settings
    export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapikey.gpg)
    export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapibase.gpg)/v1
    export OPENAI_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapibase.gpg)/v1
    export CUSTOM_ANTHROPIC_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapikey.gpg)
    export CUSTOM_ANTHROPIC_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapibase.gpg)
    export CUSTOM_ANTHROPIC_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/bhapibase.gpg)

    # Common API keys and environment variables
    _set_common_api_keys
}

# Set environment for AI Hub Mix
eallinoneai() {
    # AI Hub Mix specific settings
    export OPENAI_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixkey.gpg)
    export OPENAI_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixbase.gpg)/v1
    export OPENAI_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixbase.gpg)/v1
    export CUSTOM_ANTHROPIC_API_KEY=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixkey.gpg)
    export CUSTOM_ANTHROPIC_BASE_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixbase.gpg)
    export CUSTOM_ANTHROPIC_API_BASE=$(gpg --quiet --decrypt ${HOME}/.gpgs/aihubmixbase.gpg)

    # Common API keys and environment variables
    _set_common_api_keys
}

eg() {
    export GITLAB_TOKEN=$(gpg --quiet --decrypt ${HOME}/.gpgs/gitlabkey.gpg)
    export GITLAB_URL=$(gpg --quiet --decrypt ${HOME}/.gpgs/gitlabbase.gpg)
}

# clean sensitive env && make gpg require password immediately
alias clai="unset OPENAI_API_KEY && unset OPENAI_API_BASE && unset CUSTOM_ANTHROPIC_API_KEY && unset CUSTOM_ANTHROPIC_API_BASE && unset CUSTOM_ANTHROPIC_BASE_URL && unset TAVILY_API_KEY && unset DEEPSEEK_BASE_URL && unset DEEPSEEK_API_KEY && unset MOONSHOT_API_KEY && gpgconf --kill gpg-agent"
alias clan="unset ANTHROPIC_API_KEY && unset ANTHROPIC_API_BASE && unset ANTHROPIC_BASE_URL && unset ANTHROPIC_SMALL_FAST_MODEL && unset ANTHROPIC_MODEL"
alias clgit="unset GITLAB_TOKEN && unset GITLAB_URL && gpgconf --kill gpg-agent"

yolo() {
    if [[ "$1" == "update" ]]; then
        npm install -g @anthropic-ai/claude-code@latest
    else
        claude --dangerously-skip-permissions "$@"
    fi
}

cdx() {
    if [[ "$1" == "update" ]]; then
        npm install -g @openai/codex@latest
    else
        codex -c model_reasoning_effort="high" --enable web_search_request "$@"
    fi
}

gmi() {
    if [[ "$1" == "update" ]]; then
        npm install -g @google/gemini-cli@latest
    else
        gemini "$@"
    fi
}

# if custom aliases file exists, source it
if [ -f "${HOME}/.aliases_custom.zsh" ]; then
    source "${HOME}/.aliases_custom.zsh"
fi
