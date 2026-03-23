# Device Migration Guide

Set up a new machine with dotfiles, secrets, and SOPS-encrypted configs.

## Prerequisites

- SSH key added to GitHub (`ssh -T git@github.com`)
- GPG private key exported from an existing machine (see [Export GPG Key](#export-gpg-key))

## 1. Bootstrap dotfiles

```bash
GITHUB_USERNAME=$USER bash -c \
  "$(curl -fsSL 'https://raw.githubusercontent.com/isvicy/dots/refs/heads/main/hack/bootstrap-machine.sh')"
```

## 2. Install tools (NixOS)

```bash
cd ~/nix && sudo nixos-rebuild switch --flake ~/nix
```

Required packages (already in `nix/home/programs/common.nix`): `pass`, `age`, `sops`, `gitleaks`.

For non-NixOS (macOS/Ubuntu), install manually:
```bash
# macOS
brew install pass age sops gitleaks gnupg

# Ubuntu
sudo apt install pass age sops gnupg
# gitleaks: download from https://github.com/gitleaks/gitleaks/releases
```

## 3. Import GPG key

```bash
gpg --import /path/to/private-key.gpg

# Set trust to ultimate (replace <KEY_ID> with your key fingerprint)
gpg --edit-key <KEY_ID> trust
# Select 5 (ultimate trust), confirm, quit
```

## 4. Clone password store

```bash
git clone git@github.com:isvicy/password-store.git ~/.password-store
```

## 5. Verify

```bash
# Should prompt GPG passphrase once, then cached by gpg-agent
pass show ai/tavily/key

# Second call — no prompt (gpg-agent cached)
pass show git/github/token

# SOPS decryption via age key in pass (piped, never in env or on disk)
pass show age/identity | SOPS_AGE_KEY_FILE=/dev/stdin sops --decrypt ~/.dots/.mcp/gitlab.sops.json | head -3
```

## 6. Link dotfiles

```bash
cd ~/.dots && make link
```

---

## Export GPG Key

On an existing machine, export the private key for transfer:

```bash
gpg --export-secret-keys <KEY_ID> > ~/private-key.gpg
```

Transfer via secure channel (scp, USB):
```bash
scp ~/private-key.gpg newmachine:~/
```

Delete the exported file after import:
```bash
rm ~/private-key.gpg          # on source machine
rm ~/private-key.gpg          # on target machine after import
```

---

## Daily Usage

### pass — managing secrets

```bash
# List all secrets
pass ls

# Show a secret
pass show category/service/key

# Add a new secret (interactive)
pass insert category/service/key

# Add a new secret (pipe)
echo "value" | pass insert -m category/service/key

# Generate a random password
pass generate category/service/key 32

# Edit an existing secret
pass edit category/service/key

# Remove a secret
pass rm category/service/key

# Sync with remote
cd ~/.password-store && git pull   # pull
cd ~/.password-store && git push   # push
```

### psops — managing SOPS-encrypted configs

`psops` is a wrapper that pipes the age key from `pass` via stdin so the key never touches disk or env vars.

```bash
# Edit in place (decrypts in $EDITOR, re-encrypts on save)
psops .mcp/gitlab.sops.json

# Decrypt to stdout
psops --decrypt .mcp/gitlab.sops.json

# Encrypt a new file (must match .sops.yaml path_regex)
psops --encrypt --in-place .mcp/newservice.sops.json

# Show a specific key
psops --decrypt --extract '["mcpServers"]["gitlab"]["env"]' .mcp/gitlab.sops.json
```

### Shell functions

```bash
# Load common API keys into env (prompts GPG passphrase once per session)
_set_common_api_keys

# Load GitLab token
eg

# Clear sensitive env vars
clai
clgit
```

## Syncing Between Devices

```bash
# Pull latest secrets
cd ~/.password-store && git pull

# Pull latest dotfiles
cd ~/.dots && git pull && make link
```
