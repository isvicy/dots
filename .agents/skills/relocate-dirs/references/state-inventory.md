# State that records absolute paths

What breaks when a directory moves, how `relocate.sh` handles it, and what it
deliberately leaves alone. Extend this table (and the script and tests) when a
new tool shows up on the host.

## Handled by relocate.sh

| State | Where | Handling |
|---|---|---|
| git worktrees | `<git dir>/worktrees/*/gitdir`, `<worktree>/.git` | `git worktree repair` per main repo, also when only the main repo or only the worktree moves; bare repos included |
| jj workspace pointer | `<workspace>/.jj/repo` (relative to `.jj`, no trailing newline) | recomputed when the workspace and its repo end up in different relative positions |
| jj workspace list | `<repo>/.jj/repo/workspace_store/index` (protobuf: name, path relative to `.jj/repo`) | entries recomputed the same way; other bytes copied |
| jj per-repo config | `~/.config/jj/repos/*/metadata.binpb` (protobuf: repo path) | path rewritten |
| direnv allowances | `~/.local/share/direnv/allow` (hash of the `.envrc` path as found) | `direnv allow` from each new dir, including symlinked `.envrc` files |
| absolute symlinks | inside the moved trees and under `~` (depth 6), e.g. `~/.agents/skills/*` | relinked to the new target |
| Claude Code projects | `~/.claude/projects/<encoded cwd>` (every non-alphanumeric char becomes `-`) | dirs renamed |
| Claude Code config and memory | `~/.claude.json`, `~/.claude/settings*.json`, `projects/*/memory` | text rewrite |
| Claude Code prompt history | `~/.claude/history.jsonl`; the up-arrow list is filtered by `project` | only `project` values rewritten; `display` (what was typed) kept verbatim |
| pi sessions | `~/.pi/agent/sessions/--<path with / as ->--/*.jsonl`; line 1 `cwd` | dirs renamed, line-1 `cwd` rewritten with mtime kept (pi refuses to resume when the header cwd is missing) |
| herdr | `~/.config/herdr/session.json`: pane `cwd`, workspace `identity_cwd`, pi session file paths | text rewrite; verify checks every path-based `agent_session` file exists |
| codex trust list | `~/.codex/config.toml` `[projects."<path>"]` | text rewrite |
| identity scoping | git `includeIf "gitdir:~/repos/"`, jj `--when.repositories` | text rewrite; an exact nested OLD (`["~/repos"]`) needs `--retarget` |
| other text config | `~/.config`, `~/.agents` (track specs), `~/.dots`, `~/.work.zsh`, `~/.kimi`, `~/.pi/agent`, `--root` extras | text rewrite of absolute, `~`, `$HOME`, `${HOME}` and encoded forms |
| node shims | `node_modules/.bin/*` (`NODE_PATH`, `cmd-shim-target`) | listed by `--stale`; rebuild by hand (see SKILL.md) |
| Python venvs | `.venv/bin/*` shebangs | listed by `--stale`; `uv` puts a `*` `.gitignore` in `.venv`, so search with `--no-ignore` |

## Left alone on purpose

| State | Effect | Notes |
|---|---|---|
| session transcripts (Claude/codex/pi `*.jsonl` bodies), shell history, zoxide | old paths stay in history | rewriting history changes what was recorded |
| atuin `history.db` `cwd` | with `filter_mode_shell_up_key_binding = "directory"` the shell's up arrow no longer shows commands run in the old dirs | `history` rows derive from the synced record store; `atuin store rebuild` or a restore on another machine brings the old cwd back. Not handled; the user decided against rewriting it |
| codex `state_5.sqlite` thread cwd | `codex resume` (picker) filters by cwd, so old threads are hidden; resuming by id asks which dir to use | `codex resume --all`, or resume by id and pick "Use current directory" |
| herdr panes without `agent_session` (codex) | not resumed after restart | resume by hand, see SKILL.md step 6 |
| `~/.dots/.agents/**` | doc examples keep their paths | default `--skip`; this skill's own docs live there |
| `target/`, `.direnv`, nix gcroots | rebuilt / re-evaluated on next use; old gcroots only affect GC | nothing to do |

## Known ambiguities

- Claude's project dir encoding is lossy: `~/repos/work-foo` and
  `~/repos/work/foo` both encode to `-home-u-repos-work-foo`. A name that
  already looks like it is under a NEW is treated as new. Claude also hashes
  names longer than 200 characters; those are not renamed.
- Text forms are matched with path boundaries: `~/repos/workshop` maps,
  `~/repos/work/x` does not move twice, `/mnt/home/u/repos` and `file~/repos`
  are left alone. Check unusual strings with `--preview`.
