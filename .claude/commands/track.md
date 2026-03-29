---
description: Track feature development progress across repos and branches
argument-hint: [read [N|name]|update|done|start <name>]
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

# /track — Feature Progress Tracker

You are managing feature tracking files in `~/.features/`. Each feature is bound to a repo+branch combination.

## Data files

- **`~/.features/manifest.json`** — Maps `"<repo_path>:<branch>"` → `"<feature_name>"` for **active** features only. Used by `update`/`done` to find the current branch's feature.
- **`~/.features/<feature_name>/spec.md`** — Feature spec with YAML frontmatter (name, status, created, updated, repo, branch) and markdown body. Kept even after `done` for historical reference.

## Resolving current context

Run these to get the current repo and branch:
```bash
git rev-parse --show-toplevel 2>/dev/null
git rev-parse --abbrev-ref HEAD 2>/dev/null
```
The lookup key is `<repo>:<branch>`.

## Sub-commands

Parse the argument to determine the sub-command:

### No argument → List recent features

1. Scan ALL `~/.features/*/spec.md` files.
2. Parse YAML frontmatter from each (name, status, updated, repo, branch).
3. Sort by `updated` date descending.
4. Resolve current repo + branch.
5. Print a numbered list (most recent first). Mark the current branch's active feature with `← current`.

Output format:
```
Recent features:
  1. feature-name       (in-progress)  repo-basename:branch    2026-03-29  ← current
  2. other-feature      (done)         repo-basename:branch    2026-03-25
  3. old-feature        (done)         another-repo:main       2026-03-20
```

Use only the repo basename (last path component) for brevity.

### `read [N|name]` → Read a feature spec

- **`read`** (no extra arg): Find the feature for current repo+branch from manifest.json. Read and print its `spec.md`. If none, print "No active feature for `<repo>:<branch>`".
- **`read <N>`** (number): Scan all features sorted by `updated` desc (same as listing), pick the Nth entry, read and print its `spec.md`.
- **`read <name>`** (string): Read `~/.features/<name>/spec.md` directly. If not found, print "Feature `<name>` not found".

### `update` → Update progress, memory, and docs

1. Find the current feature's spec.md.
2. Based on the conversation context, update the **Progress** checklist (mark items done, add new items) and **Notes** section.
3. Update the `updated` date in frontmatter.
4. **Memory check:** Review what was done since the last update. If there are new lessons, gotchas, or feedback worth persisting across sessions, update the relevant memory files under the project's `memory/` directory (check `MEMORY.md` for the index). Only add things that are non-obvious and would prevent repeating mistakes.
5. **Docs check:** If the work changed how the system operates (new components, changed behavior, new commands), check if project docs (README, troubleshooting, CLAUDE.md) need updating. If so, note what needs updating in the spec's Notes section — or update the docs directly if the change is clear.
6. Print the updated spec.

### `done` → Mark feature complete

1. Find the current feature's spec.md.
2. Set `status: done` and update the `updated` date in frontmatter.
3. Remove the entry from manifest.json (delete the key, write the file back).
4. Print a completion summary. The spec.md is kept for reference.

### `start <name>` → Start a new feature

1. Resolve repo + branch.
2. Check if there's already an active feature for this repo+branch. If so, warn and ask to `/track done` first.
3. Create directory `~/.features/<name>/`.
4. Ask the user what the goal is (or use context from the conversation).
5. Create `spec.md` with frontmatter (name, status: in-progress, created: today, updated: today, repo, branch) and sections: Goal, Architecture Decisions, Progress, Issues Encountered & Fixes, Lessons Learned.
6. Add entry to manifest.json: `"<repo>:<branch>": "<name>"`.
7. Print the new spec.

## Output format

When printing a feature, use this format:
```
## <name> (<status>)
Repo: <repo> | Branch: <branch>
Updated: <date>

### Goal
<goal text>

### Architecture Decisions
<key choices made and why — what was considered, what was chosen, what was rejected>

### Progress
<checklist>

### Issues Encountered & Fixes
<numbered list: what broke, root cause, fix applied>

### Lessons Learned
<knowledge worth persisting — things that should prevent repeating mistakes>
```
