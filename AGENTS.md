## What This Is

A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/). Files at the repo root
mirror `$HOME` — Stow symlinks them into place. The `.stow-local-ignore` file excludes repo-only files (hack/, Makefile,
node_modules, etc.) from being linked.

## Key Commands

```bash
make link          # Symlink dotfiles into $HOME (runs hack/stow-with-backup.sh)
make bootstrap     # Run full machine bootstrap (hack/bootstrap.sh)
```

## Commit Convention

Commits are enforced via **commitlint** (conventional commits) through a husky pre-commit hook. Use the
`type(scope): message` format (e.g., `feat(zsh): add alias`). Run `pnpm install` to set up the hook.

## Architecture

- **Stow root** — Top-level dotfiles (`.zshrc`, `.tmux.conf`, `.vimrc`, `.p10k.zsh`, `.tigrc`) are symlinked directly to
  `$HOME`.
- **`.zsh-custom/`** — Modular zsh config sourced by `.zshrc`: `init.zsh` (pre-zinit), `env.zsh`, `config.zsh`,
  `aliases.zsh`, `thirdparty.zsh`, `post.zsh`. Machine-specific overrides go in `~/.$(hostname).zsh`.
- **`.config/`** — App configs (kitty, ghostty, yazi, etc.) symlinked to `~/.config/`.
- **Secrets** — Managed via pass (GPG backend) in a separate git repo. Decrypted at runtime via `pass show`.
- **`.mcp/`** — MCP server configs. `default.json` and `full.json` use `$ENV_VAR` placeholders expanded at runtime via
  `envsubst`. Secret-containing configs (e.g. `gitlab.sops.json`) are encrypted via SOPS (age backend). Contains
  `anki-mcp` as a git submodule.
- **`.claude/`** — Claude Code config (CLAUDE.md, statusline.sh, commands/).
- **`.config/herdr/plugins/`** — Herdr plugins (currently `herdr-display-name/`, which pushes per-pane display names
  to the `$display` sidebar token). Previously managed via LaunchAgent (`Library/LaunchAgents/dev.herdr.display-name.plist`)
  and a standalone script (`.config/herdr/scripts/display-name.py`); both removed in favor of the plugin's `[[startup]]`
  hook. See "Stow tree folding" below for why this needs special directory handling.
- **`hack/`** — Bootstrap and setup scripts. `bootstrap.sh` is the single entry point for all platforms (macOS, NixOS,
  Ubuntu). Also contains `stow-with-backup.sh` for symlink management.
- **`template/`** — API test scripts (curl snippets and Python scripts for OpenAI, Anthropic, Gemini, etc.) and WSL
  startup scripts.
- **`docs/`** — Reference docs.

### Stow tree folding and runtime directories

Stow's default behavior is **tree folding**: if a target directory doesn't exist, stow symlinks the entire source
directory instead of creating the target directory and linking only the contents. This causes problems when an app
writes runtime files into its config directory.

**Example problem:** `~/.config/herdr/plugins/` contains both our plugin source (`herdr-display-name/`) and herdr's
runtime files (`config/`, `state/`, etc.). Without pre-creating the target directory, stow folds the whole `plugins/`
into a symlink, causing herdr's runtime files to leak into the dots repo.

**Solution:** `hack/stow-with-backup.sh` pre-creates runtime directories before running stow, so only the intended
files/dirs get linked. Current pre-created dirs:

- `~/.config.bak` — Backup location for conflicting files
- `~/.config` — Base config directory
- `~/.config/direnv`
- `~/.local`, `~/.local/bin`, `~/.local/share`
- `~/.mcp`
- `~/.claude`, `~/.kimi`
- `~/.agents/skills`
- `~/.config/herdr`, `~/.config/herdr/plugins` — Prevents stow from folding herdr's plugin runtime files

**When adding a new app config under `.config/`:** If the app writes runtime files into its config directory (logs,
caches, state files, sockets, etc.), add the directory to `stow-with-backup.sh`'s `ensureTargetDir` list to prevent tree
folding.
