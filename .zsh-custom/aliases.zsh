# basic
alias tree='tree -a -I .git'
# git
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
alias gri="git rebase -i"
# proxy
alias setp="export ALL_PROXY=socks5://127.0.0.1:8899"
alias usetp="unset ALL_PROXY"
alias cip="curl 'http://ip-api.com/json/?lang=zh-CN'"
# kube
alias kl="kubectl"
# try different nvim distro
[[ -s "${HOME}/.nvim_appnames" ]] && source "${HOME}/.nvim_appnames" || true
# docker
isize() {
    local image_tag=$1
    docker history --no-trunc --format "{{.Size}}, {{.CreatedBy}}" "${image_tag}" | grep -v 0B
}
