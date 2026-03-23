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

## Adding a New Secret

```bash
pass insert category/service/key
# or pipe:
echo "sk-abc123" | pass insert -m category/service/key

# Sync
cd ~/.password-store && git push
```

## Adding a SOPS-encrypted Config

```bash
# Create the file
vim .mcp/newservice.sops.json

# Encrypt (uses .sops.yaml creation rules)
pass show age/identity | SOPS_AGE_KEY_FILE=/dev/stdin sops --encrypt --in-place .mcp/newservice.sops.json

# Edit later (decrypts in $EDITOR, re-encrypts on save)
pass show age/identity | SOPS_AGE_KEY_FILE=/dev/stdin sops .mcp/newservice.sops.json
```

## Syncing Between Devices

```bash
# Pull latest secrets
cd ~/.password-store && git pull

# Pull latest dotfiles
cd ~/.dots && git pull && make link
```
