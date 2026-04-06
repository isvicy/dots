---
name: track
description: Manage multi-repo feature specs. Track what's being built across repo groups, keep specs updated, and let multiple agents stay aligned. Use when user says /track or when starting/finishing feature work.
argument-hint: "[new|switch|update|read|list|done|archive|unarchive|reindex] [N|name|all|archived] [feature-name]"
user-invocable: true
---

# Track Skill

Manage feature specs in `~/.agents/.features/` — a global directory shared across all repos and agents.

## Configuration

**Config file**: `~/.agents/.features/.config.yaml`

```yaml
repos:
  backend:
    bare: ~/repos/team/backend.git
    default_branch: main
  proto:
    bare: ~/repos/team/proto.git
    default_branch: main
  frontend:
    bare: ~/repos/team/frontend.git
    default_branch: main

groups:
  main:
    repos: [backend, proto, frontend]
    primary: backend
```

`repos`: flat registry of short names → bare repo paths + default branch.
`groups`: which repos move together. `primary` is the main repo in the group.

## Directory Layout

```
~/.agents/.features/
├── .config.yaml
├── .index.json               # feature index (auto-maintained)
├── finished_features.md      # LEGACY read-only archive (do not append)
├── auth-refactor/
│   └── spec.md
├── api-migration/
│   └── spec.md
└── search-v2/
    └── spec.md
```

`.index.json` is a JSON array of feature summaries, rebuilt on every mutation (`new`, `update`, `done`, `archive`, `unarchive`). It enables `/track list` to read one file instead of scanning all directories. If missing or suspected stale, any subcommand should rebuild it by scanning all `*/spec.md` files.

## Feature Index (`.index.json`)

**Path**: `~/.agents/.features/.index.json`

A JSON array kept in sync by every mutating subcommand. Structure:

```json
[
  {
    "name": "auth-refactor",
    "group": "main",
    "status": "in-progress",
    "description": "Refactor auth middleware to support OAuth2 and session tokens",
    "branch": "auth-refactor",
    "repos": ["backend", "proto", "frontend"],
    "created": "2026-04-04",
    "updated": "2026-04-04"
  }
]
```

Fields mirror frontmatter plus `name` (directory name) and `repos` (flattened to a name list for display).

**Rebuild logic**: List all directories in `~/.agents/.features/` that contain `spec.md`. For each, parse frontmatter. Build the array. Sort by `updated` desc. Write to `.index.json`.

**When to rebuild**: after `new`, `update`, `done`, `archive`, `unarchive`. Also rebuild if `.index.json` is missing when any subcommand runs.

**Partial update**: For efficiency, subcommands may patch a single entry in the array rather than full-rebuilding. But full-rebuild is always acceptable and preferred when uncertain about the current state.

## Context Detection

**Every subcommand** must start by detecting the current group:

```bash
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"  # bare repo path
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
WORKTREE="$(git rev-parse --show-toplevel)"
```

Match `GIT_COMMON_DIR` against config `repos[*].bare` (expand `~`) to find the repo short name. Then look up which group that repo belongs to → this gives `$GROUP`.

**Resolving group repos**: Read `groups[$GROUP].repos` from `.config.yaml` to get the list of repo short names in this group. For each, read `repos[<name>]` to get its `bare` path (or `path` for non-bare repos) and `default_branch`. This is how `/track new` knows which repos to create worktrees for, and how `/track update` knows which worktrees to gather git context from.

**Auto-onboarding** (repo not in config): If `GIT_COMMON_DIR` doesn't match any config entry, the agent auto-detects repo info and offers to register it. See `/track new` step 2 for the full flow.

To auto-detect a repo's properties:
```bash
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"   # bare path (or .git for non-bare)
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
# Fallback: check for main/master if above fails
REMOTE_URL="$(git remote get-url origin 2>/dev/null)" # derive short name from last path segment
```
Short name: derive from the bare repo directory name or remote URL last segment (e.g., `backend.git` → `backend`).

**Active feature detection**: Read `.index.json`, find the entry where `group` matches `$GROUP` AND `branch` matches `$BRANCH`. There may be 0 or 1 match. This is the "you are here" feature — used by `/track update`, `/track read` (no args), `/track done` (no args), and the `>` marker in `/track list`.

`FEATURES_DIR` is always `~/.agents/.features`.

## Frontmatter Format

```yaml
---
group: main
branch: dev-cc
status: in-progress
description: "Extend website workflow to support full-stack apps with backend"
created: 2026-03-25
updated: 2026-03-30
repos:
  backend:
    worktree: /home/user/repos/team/backend.git/dev
  proto:
    worktree: /home/user/repos/team/proto.git/dev
  frontend:
    worktree: /home/user/repos/team/frontend.git/dev
---
```

- `group`: which repo group this feature belongs to
- `branch`: shared branch name across all repos
- `status`: `in-progress`, `finished`, or `archived`. Set to `in-progress` on creation, `finished` by `/track done`, `archived` by `/track archive`.
- `description`: one-line summary of the feature (max ~80 chars). Auto-generated from the Overview section during `/track update`. Can be manually overridden.
- `created`: date the feature was started (YYYY-MM-DD)
- `updated`: date the spec was last modified (YYYY-MM-DD)
- `repos`: absolute worktree paths per repo (handles `dev/` worktree tracking `dev-cc` branch)

## Subcommands

### `/track` (no args) — List Features

Defaults to `/track list`. See below.

### `/track list [all]` — List Features

1. Read `.index.json`. If missing, rebuild it (same as `/track reindex`).
2. Detect current group and branch from repo context.

**`/track list`** (default — also invoked by `/track` with no args):
- Filter to **current group only**.
- Exclude `archived` features.
- Show all `in-progress` features. If fewer than 10, fill remaining slots with most recent `finished` features from the same group.
- Sort: in-progress first (by `updated` desc), then finished (by `updated` desc).
- Cap at 10.

**`/track list all`**:
- All groups, all statuses **except `archived`**.
- Ordered by `updated` desc, no cap.

**`/track list archived`**:
- Show only `archived` features from **current group**.
- Ordered by `updated` desc, no cap.
- Use this to find archived features by name for `/track unarchive` or `/track switch`.

Output format:

```
#  Feature                      Status       Description                          Updated
1> auth-refactor                in-progress  Refactor auth middleware to supp...   2026-04-04
2  search-v2                    in-progress  Full-text search with filters        2026-03-28
3  api-migration                finished     Migrate REST endpoints to gRPC...    2026-04-02
```

- `>` marks the feature matching the current branch (if any) — "you are here"
- Numbers are ephemeral, valid for the current invocation only
- Description truncated to ~40 chars with `...` if longer

### `/track new <feature-name>` — Create Multi-Repo Feature

1. **Validate**: lowercase alphanumeric + hyphens. Check directory doesn't exist.
2. **Detect context**: identify current repo from `git-common-dir`, look up its group in config. If the repo **is already in a group** → proceed to step 3.

   **If repo is NOT in config** (auto-onboarding):
   1. Auto-detect the current repo's properties (bare path, default branch, short name — see Context Detection → Auto-onboarding).
   2. Scan **all working directories** in the current session (primary + additional from `/add-dir`). For each, run `git rev-parse --git-common-dir` and auto-detect properties. Skip any that are already registered in config.
   3. Present the discovered repos and ask the user to confirm:
      ```
      Detected repos not in config:
        backend   ~/repos/team/backend.git   (default: main)
        proto     ~/repos/team/proto.git     (default: main)
        frontend  ~/repos/team/frontend.git  (default: main)

      Add to existing group? [list existing groups]
      Or create new group? Name:
      ```
   4. If **existing group**: add repos to that group's `repos` list and register them in `repos:`.
   5. If **new group**: ask for group name and which repo is `primary`. Create the group with all discovered repos.
   6. Write updated `.config.yaml`. Proceed to step 3 with the now-resolved group.

3. **Branch strategy** — ask the user:
   - "Create new branch or reuse current branch `<branch>`?"
   - If new branch: ask base (default: repo's `default_branch`). The **same branch name** is used across ALL repos in the group.
4. **Create worktrees** for each repo in the group:
   - If the branch already has a worktree in that repo → record existing path
   - If the branch exists but has no worktree → `git worktree add <branch> <branch>`
   - If the branch doesn't exist → `git worktree add -b <branch> <branch> <default_branch>`
   - Worktree directory name = branch name (unless reusing existing like `dev/` for `dev-cc`)
5. **Create spec** with frontmatter + template:

```markdown
---
group: {group}
branch: {branch}
status: in-progress
description: ""
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
repos:
  {repo1}:
    worktree: {path1}
  ...
---
# {Title-Cased Name} — Feature Spec

## Overview

_Describe what this feature does and why._

## Architecture

_Key components, data flow, repos involved._

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|

## Progress

- [ ]

## Key Files

| Repo | File | Purpose |
|------|------|---------|

## Design Decisions

1.

## Issues Encountered & Fixes

_What broke, root cause, fix applied._

## Lessons Learned

_Non-obvious knowledge discovered during this work — things that prevent repeating mistakes._
```

6. **Update index**: Read `.index.json` (or initialize empty array if missing). Append a new entry for this feature. Write back.
7. Print all worktree paths.

### `/track switch <N|name>` — Context Import

This is purely a **context import** action — no persistent state change. Use it to load a feature's full spec into the current agent session.

1. **Resolve the target feature:**
   - If argument is a **number N**: Read `.index.json`, apply the same sort/filter as `/track list` (current group, in-progress first, then finished, up to 10), pick the Nth entry (1-indexed). If N is out of range, error with the valid range.
   - If argument is a **string name**: Look up `~/.agents/.features/<name>/spec.md` directly.
   - If **no argument**: run `/track list` and stop.
2. Read the target spec's full `spec.md`.
3. Print worktree paths + full spec:
   ```
   Feature: auth-refactor (group: main, branch: auth-refactor)

   Worktrees:
     backend   /path/to/backend.git/auth-refactor
     proto     /path/to/proto.git/auth-refactor
     frontend  /path/to/frontend.git/auth-refactor

   --- spec ---
   [full spec.md contents]
   ```

### `/track read [N|name]` — Read a Feature Spec

- **`/track read`** (no extra arg): Detect feature from current branch (see Context Detection → Active feature detection). If found, print the full `spec.md`. If not: "No tracked feature on branch `{BRANCH}`. Use `/track list` to see features."
- **`/track read <N>`** (number): Read `.index.json`, apply same sort/filter as `/track list` (current group), pick Nth entry (1-indexed), read and print its `spec.md`.
- **`/track read <name>`** (string): Read `~/.agents/.features/<name>/spec.md` directly. If not found: "Feature `<name>` not found."

No summarization — always print the full spec.

### `/track update` — Update Spec from Multi-Repo Changes

1. **Detect feature from current branch** (see Context Detection → Active feature detection). If no match: "No tracked feature on branch `{BRANCH}`. Use `/track list` to see features."
2. Read the feature's `spec.md`.
3. **Gather context from ALL repos** in the frontmatter, sequentially:
   ```bash
   # For each repo:
   cd <worktree-path>
   git log --oneline -20
   git diff --stat HEAD~5..HEAD
   ```
4. **Update the spec** — preserve structure, only add/refine:
   - Prefix commits with repo name: `[backend] a1b2c3d fix: something`
   - Update "Implementation Status" with per-repo progress
   - Check/uncheck items in "Progress" checklist, add new items as needed
   - Update "Key Files" with repo column: `backend | src/auth/... | ...`
   - Add to "Design Decisions" as needed
   - Add to "Issues Encountered & Fixes" if anything broke and was resolved
   - Add to "Lessons Learned" if non-obvious knowledge was discovered
   - **NEVER remove content**
5. **Auto-generate description**: Read the Overview section. Extract a one-line summary (~80 chars). If the current `description` in frontmatter is empty or materially outdated, update it.
6. Update the `updated` date in frontmatter to today. Ensure `status` is `in-progress`.
7. Write updated spec back.
8. **Update index**: Read `.index.json`. Find the entry by name. Update `description`, `updated`, and any changed fields. Write back.
9. **Memory check:** Review what was done since the last update. If there are new lessons, gotchas, or feedback worth persisting across sessions, update the relevant memory files under the project's `memory/` directory (check `MEMORY.md` for the index). Only add things that are non-obvious and would prevent repeating mistakes.
10. **Docs check:** If the work changed how the system operates (new components, changed behavior, new commands), check if project docs (README, CLAUDE.md) need updating. If so, note what needs updating in the spec's "Lessons Learned" section — or update the docs directly if the change is clear.
11. Print summary of changes.

### `/track done [N|name]` — Finish Feature

1. **Resolve the target feature:**
   - No argument: detect from current branch (see Context Detection). If no match, error.
   - Number N: resolve from `.index.json` (same sort as `/track list` for current group).
   - String name: resolve directly.
2. Read the full `spec.md`.
3. Set `status: finished` in frontmatter. Update `updated` date to today.
4. Write updated spec back.
5. **Update index**: find entry by name, set `status: finished`, update `updated`. Write back.
6. Feature directory stays intact (browsable archive).
7. Print confirmation:
   ```
   Finished: auth-refactor (group: main)
   Spec retained at ~/.agents/.features/auth-refactor/spec.md
   To clean up worktrees: `git worktree remove <path>` in each repo.
   ```

**Do NOT append to `finished_features.md`** — it is a legacy archive retained for historical reference only.

### `/track archive [N|name]` — Archive Feature

Soft-delete a feature. Archived features are hidden from all lists (`/track list`, `/track list all`) but remain on disk. Use this when exploring multiple design approaches — archive the ones not chosen, keep the one you want.

1. **Resolve the target feature:**
   - No argument: detect from current branch (see Context Detection). If no match, error.
   - Number N: resolve from `.index.json` (same sort as `/track list` for current group).
   - String name: resolve directly.
   - If the feature is already archived: print "Already archived." and stop.
2. Set `status: archived` in frontmatter. Update `updated` date to today.
3. Write updated spec back.
4. **Update index**: find entry by name, set `status: archived`, update `updated`. Write back.
5. **Remove worktrees**: For each repo in the feature's frontmatter, remove its worktree:
   ```bash
   cd <bare-repo-path>
   git worktree remove <worktree-path>
   ```
   - If the worktree is the **current working directory**, warn and skip: "Skipped removing worktree `<path>` — it is the current directory. Remove manually after switching."
   - If the worktree has **uncommitted changes**, `git worktree remove` will fail. In that case, print a warning: "Worktree `<path>` has uncommitted changes — skipped. Force with `git worktree remove --force <path>` if safe."
   - If the worktree is already gone (path doesn't exist), skip silently.
6. **Delete branches**: After worktrees are removed, delete the feature branch in each repo:
   ```bash
   cd <bare-repo-path>
   git branch -d <branch>
   ```
   - Use `-d` (safe delete) — it will refuse if the branch has unmerged commits. In that case, print a warning: "Branch `<branch>` in `<repo>` has unmerged commits — skipped. Force with `git branch -D <branch>` if safe."
   - If the branch is the current branch in any worktree (e.g., `main` worktree checked out to it), skip with a warning.
   - If the branch doesn't exist, skip silently.
   - Do NOT delete remote branches — only local.
7. Feature directory stays intact (spec is the archival record).
8. Print confirmation:
   ```
   Archived: search-v2-experiment (group: darkmatter)
   Spec retained at ~/.agents/.features/search-v2-experiment/spec.md
   Removed worktrees and branches: backend, proto, frontend
   Use `/track list archived` to see archived features.
   To restore: `/track unarchive <name>`
   ```

### `/track unarchive <name>` — Restore Archived Feature

Restore an archived feature back to `in-progress`, recreating worktrees.

1. Look up `~/.agents/.features/<name>/spec.md`. If not found: "Feature `<name>` not found."
2. If status is not `archived`: "Feature `<name>` is not archived (status: {status})." and stop.
3. **Recreate worktrees** for each repo in the frontmatter, using the same logic as `/track new` step 4:
   - If the branch already has a worktree → record existing path
   - If the branch exists but has no worktree → `git worktree add <worktree-path> <branch>`
   - If the branch doesn't exist locally but exists on remote → `git worktree add -b <branch> <worktree-path> origin/<branch>`
   - If the branch is gone both locally and remotely → create from default branch: `git worktree add -b <branch> <worktree-path> <default_branch>`
   - Update worktree paths in frontmatter if they changed.
4. Set `status: in-progress` in frontmatter. Update `updated` date to today.
5. Write updated spec back.
6. **Update index**: find entry by name, set `status: in-progress`, update `updated`. Write back.
7. Print worktree paths + confirmation: "Restored: <name> (status: in-progress)"

Note: `/track unarchive` requires an explicit feature name — no N-based resolution since archived features are not numbered in regular lists. Use `/track list archived` to find the name.

### `/track reindex` — Rebuild Feature Index

Rebuild `.index.json` from scratch by scanning all `*/spec.md` files in `~/.agents/.features/`.

1. List all directories in `~/.agents/.features/` containing `spec.md`.
2. For each, parse frontmatter. Extract: name (directory name), group, status, description, branch, repos (list of keys), created, updated.
3. For specs **missing `status`**: infer from `finished_features.md` — if the feature name appears in a `## {Name} (completed ...)` heading, set `finished`; otherwise `in-progress`. Write the inferred `status` back into the spec's frontmatter.
4. For specs **missing `description`**: leave empty (will be populated on next `/track update`).
5. For specs **missing `created`**: use the `updated` date as a fallback. Write it back into frontmatter.
6. Sort by `updated` desc. Write `.index.json`.
7. Print: "Rebuilt index: N features (M in-progress, K finished, J archived)."

## Design Reference Workflow

When starting work on a new feature that may share patterns with past features:

1. Run `/track list all` to see all features with descriptions across all groups.
2. Identify features with similar scope, architecture, or repo involvement.
3. Run `/track read <name>` on relevant past features.
4. Review their Architecture, Design Decisions, Issues Encountered, and Lessons Learned sections.
5. Apply relevant patterns and avoid documented pitfalls.

This is especially valuable for:
- Features in the same repo group (likely similar architecture)
- Features that modified the same components
- Features where past issues (e.g., symlink breakage, env var naming, migration ordering) recur

The `description` field in frontmatter enables quick scanning without reading full specs.

## Multi-Agent Coordination

- **New session context import**: Agent starts with `/track list`, picks the target feature with `/track switch N`, which prints the full spec as initial context.
- **During work**: Agent is on the feature's branch — `/track update` and `/track read` auto-detect the feature.
- **After work**: Agent calls `/track update` to record changes into the spec and index.
- No file locking — specs are append-mostly. `/track update` reconstructs from git history.

## Migration

On first access after updating to v2:
- If `.index.json` does not exist, trigger a full reindex (same as `/track reindex`). This backfills `status`, `created`, and generates the index.
- Delete any `.current-{group}` or `.current` files found in `~/.agents/.features/` — they are no longer used.
- `finished_features.md` is retained as a read-only archive. `/track reindex` reads it to infer `status: finished` for specs that lack the field. Do not append to it.

## Important

- NEVER read an archieved feature's spec, archieved feature are failed experiments that should not be used as reference for new work.
- `~/.agents/.features/` is global — works from any repo, any worktree
- Same branch name across all repos in a group
- Feature names: lowercase-hyphenated
- `/track update` never removes spec content
- If config is missing, create `~/.agents/.features/.config.yaml` via the auto-onboarding flow in `/track new`
- Absolute worktree paths in frontmatter — no guessing
- `.index.json` is auto-maintained — do not hand-edit it. Run `/track reindex` if it seems stale.
- `finished_features.md` is legacy — do not append to it.
- `/track list` numbers are ephemeral (valid for the current invocation only). Always show the list before using a number with `/track switch N`.
