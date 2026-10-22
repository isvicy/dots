---
name: relocate-dirs
description: Move or rename directory trees under $HOME on a Linux dev host (e.g. ~/repos -> ~/repos/work, ~/oss -> ~/repos/oss) and repair everything that recorded their absolute paths — git worktrees, jj workspaces and repo config, direnv, symlinks, Claude Code / pi / codex / herdr state, prompt history, path-baked node_modules and venvs — with dry run, backup, verify and rollback. Use when the user wants to reorganize, rename or move repo/work directories on a host where coding agents run.
---

# Relocate directories

`scripts/relocate.sh` does the move and the repair; this file is the workflow
around it. `references/state-inventory.md` lists every kind of state that
records absolute paths, what the script does with it, and what it leaves alone.

## Mapping semantics

`--map OLD=NEW` (repeatable, `~` allowed, applied in the order given, longest
OLD wins when maps overlap):

- NEW inside OLD (`~/repos=~/repos/work`): OLD's children move into NEW; OLD
  itself stays, so references to OLD itself (a Claude project for `~/repos`,
  `--when.repositories = ["~/repos"]`) are left alone. The dry run lists such
  exact references in config; pass `--retarget FILE` for each one whose meaning
  should follow the move (identity scoping usually should).
- Otherwise OLD is renamed to NEW.
- OLD that does not exist: only references are rewritten (stale paths such as
  an old `~/repos/github` that was already moved by hand).

`--preview` rewrites stdin with the same rules; use it to sanity-check how a
specific string will come out.

## Workflow

Run everything on the host being migrated, from `~`. If the skill is not
present there, copy `scripts/relocate.sh` over (it is self-contained).

1. **Plan.** Agree the maps with the user. Run the dry run and read every
   section: counts, tracked dotfiles that will change, exact-reference hints,
   jj pointer rows.

   ```sh
   cd ~ && bash relocate.sh --map '~/repos=~/repos/work' --map '~/oss=~/repos/oss' \
     --retarget ~/.config/jj/conf.d/local.toml
   ```

2. **Stop what writes to the moved trees or agent state — do this yourself**
   instead of handing it to the user, after checking what is in flight:
   - `herdr agent list` — note any agent that is not idle, and panes whose
     agent has no `agent_session` (codex today): they will need a manual resume.
   - Copy `~/.config/herdr/session.json` aside, then `herdr server stop` (it
     writes the session on the way out). Kill leftover plugin processes.
   - `claude daemon stop --any`, then its `bg-pty-host` / `bg-spare` leftovers.
   - Services and jobs with a cwd in a moved tree (the preflight lists them).
     Before stopping a service, record how to restart it: `/proc/<pid>/cmdline`,
     `cwd`, where fd 1/2 point, listening ports (`ss -ltnp`).
   - Never `pkill -f` a pattern that also appears in your own command line (an
     ssh `zsh -c '...'` matches itself and kills the session). Kill by pid.
   - Rerun the dry run until preflight says `ok`. Do not set
     `MIGRATE_SKIP_PROCESS_CHECK` outside tests.

3. **Apply.**

   ```sh
   cd ~ && bash relocate.sh <same maps and --retarget> --apply 2>&1 | tee ~/relocate-apply.log
   ```

   It ends with `[verify ok]` and the backup dir. `repair: gitdir incorrect`
   lines are `git worktree repair` reporting what it fixed. On `[verify FAILED]`
   or an early exit: read `~/relocate-backup-*/progress.log`, run
   `relocate.sh --rollback <backup dir>`, dry-run again, report. Never patch
   forward by hand; fix the cause, roll back, rerun from scratch.

4. **Check by hand** what verify does not cover: `git config user.email` /
   `jj config get user.email` inside and outside the moved trees, `jj st` in a
   moved jj repo, broken symlinks (`find -L ~/.agents/skills -maxdepth 2 -type l`
   — some may have been broken before; check where they point).

5. **Rebuild path-baked build state.** `relocate.sh <maps> --stale` lists
   `node` (lockfile root with stale `node_modules/.bin` shims) and `venv`
   projects. For each:
   - node: `rm -rf` every `node_modules` under that root, then
     `direnv exec . pnpm install --frozen-lockfile` (or the repo's manager).
     A plain reinstall says "Already up to date" and keeps stale shims, and
     workspace sub-packages carry their own `.bin`.
   - venv: `rm -rf .venv && direnv exec . uv sync` (keep the Python version).
   - Lockfiles must not change; compare a hash before and after.
   - Rerun `--stale` until it prints nothing. `target/`, `.direnv` and nix gcroots
     need nothing (rebuilt or re-evaluated on next use).

6. **Restart and restore.**
   - Restart the services recorded in step 2 from their new paths (`setsid
     nohup ... </dev/null &`, same log target) and probe them.
   - Start herdr headless (`setsid nohup herdr server ... &`), wait, then
     `herdr agent list`: every pane cwd should be under the new paths and every
     agent `idle`. Read a few panes (`herdr pane read <id> --source visible`),
     including any pi pane.
   - A pane showing `No conversation found with session ID` usually means a
     nested `claude -p` (tests, scripts) reported its own throwaway session id
     to herdr. Find the real session by the pane title (`aiTitle` in
     `~/.claude/projects/<dir>/*.jsonl`) and `herdr pane run <pane> "claude
     --resume <id>"`.
   - Panes without a recorded session (codex): look the thread up by title in
     `~/.codex/session_index.jsonl`, `herdr pane run <pane> "cdx resume <id>"`,
     skip the update prompt, and pick "Use current directory" when asked.
   - Claude background sessions stopped with the daemon resume with
     `claude --resume <id>`.

7. **Dotfiles.** Show `git -C ~/.dots diff` / `status`, commit and push only
   the files the migration changed after the user confirms (commitlint style).

8. **Report**: steps and verify output, rebuilt projects, restored panes, what
   was interrupted, the backup dir. The user removes the backup, the apply log
   and the copied session.json once satisfied, and reopens shells (their `$PWD`
   still points at the old paths).

## Testing changes to the script

`tests/run.sh [mktemp template]` builds a throwaway HOME with every supported
kind of state (git plain/bare/cross-boundary worktrees, jj workspaces inside
and across the boundary, direnv with a symlinked `.envrc`, Claude/pi/herdr
state, history, identity configs), checks the rewrite rules through
`--preview`, runs a full apply with assertions, verifies rollback restores an
identical tree, and crashes after every phase (`MIGRATE_FAIL_AFTER=<phase>`) to
test partial rollback. Run it with a dotted template too
(`/tmp/relocate-test.XXXXXX`): Claude's encoding turns `.` into `-`, pi's keeps
it, and bugs hide in that difference. Run `shellcheck -S warning` on both files.
