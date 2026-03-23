# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/). Files at the repo root mirror `$HOME` — Stow symlinks them into place. The `.stow-local-ignore` file excludes repo-only files (hack/, Makefile, node_modules, etc.) from being linked.

## Key Commands

```bash
make link          # Symlink dotfiles into $HOME (runs hack/stow-with-backup.sh)
make prepare       # Run full machine setup (hack/setup-machine.sh)
```

## Commit Convention

Commits are enforced via **commitlint** (conventional commits) through a husky pre-commit hook. Use the `type(scope): message` format (e.g., `feat(zsh): add alias`). Run `pnpm install` to set up the hook.

## Architecture

- **Stow root** — Top-level dotfiles (`.zshrc`, `.tmux.conf`, `.vimrc`, `.p10k.zsh`, `.tigrc`) are symlinked directly to `$HOME`.
- **`.zsh-custom/`** — Modular zsh config sourced by `.zshrc`: `init.zsh` (pre-zinit), `env.zsh`, `config.zsh`, `aliases.zsh`, `thirdparty.zsh`, `post.zsh`. Machine-specific overrides go in `~/.$(hostname).zsh`.
- **`.config/`** — App configs (kitty, ghostty, yazi, lazygit, alacritty, etc.) symlinked to `~/.config/`.
- **Secrets** — Managed via pass (GPG backend) in a separate git repo. Decrypted at runtime via `pass show`.
- **`.mcp/`** — MCP server configs. `default.json` and `full.json` use `$ENV_VAR` placeholders expanded at runtime via `envsubst`. Secret-containing configs (e.g. `gitlab.sops.json`) are encrypted via SOPS (age backend). Contains `anki-mcp` as a git submodule.
- **`.claude/`** — Claude Code config (CLAUDE.md, statusline.sh).
- **`hack/`** — Bootstrap and setup scripts. `bootstrap-machine.sh` → `bootstrap-dots.sh` (clone) → `setup-machine.sh` (install deps + link). Platform-specific: `setup-mac.sh`, `setup-ubuntu.sh`.
- **`template/`** — API test scripts (curl snippets for OpenAI, Anthropic, Gemini, etc.).
- **`docs/`**, **`prompts/`** — Reference docs and prompt templates.

## Shell Aliases Worth Knowing

- `yolo` / `yolo update` — Run Claude Code with MCP config / update Claude Code
- `_set_common_api_keys` — Load API keys from pass into env
- `clai` / `clan` — Clear sensitive env vars
- `setp` / `usetp` — Set/unset HTTP proxy
- `fly` / `work` — Run commands through proxychains with different configs
- `y` — Yazi file manager with cd-on-exit
- Kubernetes: `kpd`, `kpl`, `kpc`, `kd`, `kdd`, `ksc`, `krdn` — fzf-powered kubectl wrappers
- Docker: `dcr`, `dcl`, `dis`, `dir`, `dic` — fzf-powered docker wrappers
