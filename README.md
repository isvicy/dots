# dots

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Bootstrap

> Note: you should first test your ssh key is valid by running `ssh -T git@github.com`

```bash
GITHUB_USERNAME=$USER bash -c \
  "$(curl -fsSL 'https://raw.githubusercontent.com/isvicy/dots/refs/heads/main/hack/bootstrap.sh')"
```
