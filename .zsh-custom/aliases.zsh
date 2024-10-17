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
alias setp="export ALL_PROXY=socks5h://127.0.0.1:7890; export HTTP_PROXY=socks5h://127.0.0.1:7890; export HTTPS_PROXY=socks5h://127.0.0.1:7890; export no_proxy='localhost,127.0.0.1,.megvii-inc.com'"
alias usetp="unset ALL_PROXY"
alias cip="curl 'http://ip-api.com/json/?lang=zh-CN'"
# kube
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
# try different nvim distro
[[ -s "${HOME}/.nvim_appnames" ]] && source "${HOME}/.nvim_appnames" || true
# docker
isize() {
    local image_tag=$1
    docker history --no-trunc --format "{{.Size}}, {{.CreatedBy}}" "${image_tag}" | grep -v 0B
}
dc() {
  docker container ls | percol | awk '{print $1}' | xargs -I {} sh -c 'docker stop {} && docker rm {}'
}
dl() {
  docker container ls | percol | awk '{print $1}' | xargs -I {} sh -c 'docker logs -f {}'
}
di() {
  docker image ls | percol | awk '{print $1":"$2}' | xargs -I {} docker image rm {}
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
# clean sensitive env && make gpg require password immediately
alias cl="unset OPENAI_API_KEY && unset OPENAI_API_BASE && gpgconf --kill gpg-agent"
