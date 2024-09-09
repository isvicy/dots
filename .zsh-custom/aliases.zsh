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
alias setp="export ALL_PROXY=socks5h://127.0.0.1:7890; export HTTP_PROXY=socks5h://127.0.0.1:7890; export HTTPS_PROXY=socks5h://127.0.0.1:7890; export no_proxy='localhost,127.0.0.1,.megvii-inc.com'"
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
# systemctl
alias scs="sudo systemctl status"
alias sct="sudo systemctl start"
alias scr="sudo systemctl restart"
# clean sensitive env && make gpg require password immediately
alias cl="unset OPENAI_API_KEY && unset OPENAI_API_BASE && gpgconf --kill gpg-agent"
