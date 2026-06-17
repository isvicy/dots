---
name: track
description: Manage multi-repo feature specs. Track what's being built across repo groups, keep specs updated, and let multiple agents stay aligned. Use when user says /track or when starting/finishing feature work.
argument-hint: "[new|switch|update|read|compact|verify|list|done|archive|unarchive|reindex] [N|name|all|archived|--session N|--full|--archive] [feature-name]"
user-invocable: true
---

# Track Skill

Manage feature specs in `~/.agents/.features/` — a global directory shared across all repos and agents.

## Spec Model: Event-Sourced (v2)

A long-running feature's spec behaves like an **event-sourced log**: an append-only stream of work events plus a small, rewritable snapshot of the current state. Forcing both into one growing file is what made specs balloon to hundreds of KB, race on numbering, and become unreadable in one call. v2 splits them physically:

| Event sourcing | v2 spec | Container |
|---|---|---|
| snapshot / HEAD (derived, bounded, **overwritable**) | `## Current State` block | `spec.md` |
| event stream (append-only, **frozen once written**) | one session per file | `sessions/<NNN>-<slug>.md` |
| read-path truncation ≠ deletion | rolled-up old sessions | `archive.md` |

Recovery for a fresh agent = **Current State + the most recent few sessions**, never the whole history.

**Layout detection** — a feature directory is **v2** if it contains a `sessions/` subdirectory; otherwise it is a **legacy** single-file spec. Every subcommand detects this and branches. Legacy specs keep working untouched; only `/track new` creates v2, and `/track update` may opportunistically initialize v2 (see below).

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
│
├── auth-refactor/            # v2 feature
│   ├── spec.md               #   stable header + Current State snapshot + Sessions TOC
│   ├── sessions/
│   │   ├── 001-oauth-dal.md  #   one session per file, append-only, frozen once written
│   │   └── 002-jwt-mw.md
│   └── archive.md            #   rolled-up old sessions (one line each)
│
└── old-feature/              # legacy feature (still supported)
    └── spec.md               #   single file, inline sections
```

`.index.json` is a JSON array of feature summaries, rebuilt on every mutation (`new`, `update`, `done`, `archive`, `unarchive`). It lets `/track list` read one file instead of scanning all directories. If missing or suspected stale, any subcommand rebuilds it by scanning all `*/spec.md` files.

## Feature Index (`.index.json`)

**Path**: `~/.agents/.features/.index.json`

A JSON array kept in sync by every mutating subcommand:

```json
[
  {
    "name": "auth-refactor",
    "group": "main",
    "status": "in-progress",
    "description": "OAuth2 + session-token auth middleware",
    "branch": "auth-refactor",
    "repos": ["backend", "proto", "frontend"],
    "layout": "v2",
    "created": "2026-04-04",
    "updated": "2026-04-04"
  }
]
```

Fields mirror frontmatter plus `name` (directory name), `repos` (flattened to a name list), and `layout` (`"v2"` if `sessions/` exists, else `"legacy"`).

**`description` source**: the frontmatter `description` (≤80 chars). For v2 specs this is the first line / one-liner of `## Current State`. NEVER the full rolling digest — that bloat is exactly what v2 removes.

**Rebuild logic**: list all directories in `~/.agents/.features/` containing `spec.md`. For each, parse frontmatter, detect layout. Build the array, sort by `updated` desc, write `.index.json`.

**When to rebuild**: after `new`, `update`, `done`, `archive`, `unarchive`. Also rebuild if `.index.json` is missing. Subcommands may patch a single entry rather than full-rebuild, but full-rebuild is always acceptable and preferred when uncertain.

## Context Detection

**Every subcommand** starts by detecting the current group:

```bash
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"  # bare repo path
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
WORKTREE="$(git rev-parse --show-toplevel)"
```

Match `GIT_COMMON_DIR` against config `repos[*].bare` (expand `~`) to find the repo short name, then look up its group → `$GROUP`.

**Resolving group repos**: read `groups[$GROUP].repos` from `.config.yaml` for the repo short names; for each read `repos[<name>]` for its `bare` (or `path`) and `default_branch`. This is how `/track new` knows which repos to create worktrees for and how `/track update` knows which worktrees to gather git context from.

**Auto-onboarding** (repo not in config): if `GIT_COMMON_DIR` doesn't match any config entry, auto-detect and offer to register. See `/track new` step 2.

```bash
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"   # bare path (or .git for non-bare)
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
REMOTE_URL="$(git remote get-url origin 2>/dev/null)" # derive short name from last path segment
```
Short name: derive from the bare repo directory name or remote URL last segment (`backend.git` → `backend`).

**Active feature detection**: read `.index.json`, find the entry where `group` matches `$GROUP` AND `branch` matches `$BRANCH` (0 or 1 match). This is the "you are here" feature — used by `/track update`, `/track read` (no args), `/track done` (no args), `/track compact`, and the `>` marker in `/track list`.

`FEATURES_DIR` is always `~/.agents/.features`. `FEATURE_DIR` = `$FEATURES_DIR/<name>`.

## Frontmatter Format

```yaml
---
group: main
branch: dev-cc
status: in-progress
description: "Full-stack website workflow: version routing + FUSE screenshots"
created: 2026-03-25
updated: 2026-03-30
repos:
  backend:
    worktree: /home/user/repos/team/backend.git/dev
  proto:
    worktree: /home/user/repos/team/proto.git/dev
---
```

- `group`: repo group this feature belongs to
- `branch`: shared branch name across all repos
- `status`: `in-progress`, `finished`, or `archived`
- `description`: **one line, ≤80 chars.** The feature's elevator pitch / current focus. Derived from `## Current State`. Do NOT stuff a rolling session digest here.
- `created` / `updated`: YYYY-MM-DD
- `repos`: absolute worktree paths per repo

## Spec Structure (v2)

### `spec.md`

```markdown
---
<frontmatter>
---
# {Feature} — Spec

## Current State            ← SNAPSHOT / HEAD: derived, bounded (≤~6KB), OVERWRITE in place

### Decisions               # key→latest-conclusion; dedupe by key, last write wins
- `oauth-keying`: full-URL (strip query/fragment), not origin. Reason: RFC8707 multi-tenant.
- `host-kind`: author interface.hostKind > stdio-derived > hosted default.

### Open Risks & TODOs       # ⚠️ VERBATIM — never compacted
- [ ] MR !2910 + !564 待合主干
- [ ] Phase 2: cross-repo author-declared MCP transport

### Key Files                # dedupe by repo|file
| Repo | File | Purpose |
|------|------|---------|

### Verify Status            # current pass/fail + deployed revision
- darkmatter HEAD 658ad5b36 / argo kimi Synced+Healthy

### Active Sessions          # pointer(s) to in-progress / most-recent session files
- → sessions/036-mcp-transport.md (Phase 1 done, Phase 2 TODO)

## Sessions (TOC)            ← auto-generated, newest-first
| #   | Slug          | Date  | Status                 | One-liner                 |
|-----|---------------|-------|------------------------|---------------------------|
| 036 | mcp-transport | 06-14 | ✅code+test+ship+e2e   | baidu SSE transport over… |
| 035 | paid-plugin   | 06-13 | ✅                     | paid-plugin quota notice  |
```

`## Current State` is a **derived snapshot** — in principle reconstructible from all sessions — so overwriting it loses nothing. That is why it may be rewritten in place while sessions never can.

### `sessions/<NNN>-<slug>.md`

Formalizes the session-block pattern agents self-organized. One file per session, **append-only, frozen once written**.

```markdown
# SESSION 036 — MCP transport (SSE vs streamable) — ✅ code+test+ship+e2e

**date**: 2026-06-14 · **agent**: <optional, fill when running concurrently> · **status**: Phase 1 done / Phase 2 TODO

> Crux: baidu plugin authorizes OK but won't connect at runtime — materialized MCPUserSetting hardcodes HTTP; baidu is SSE.

## 设计结论 (user-confirmed)
…
## 实现 (repo HEAD / commit / file anchors)
…
## Ship + 真机 e2e
…
## 待办 / 教训
- [[reference_mcp_transport_per_host_override]]
```

To overturn a prior conclusion, write a NEW session saying so — never edit a frozen session (event-sourcing compensating event). Cross-link memory with `[[name]]` and other sessions by filename.

### `archive.md`

Rolled-up old sessions, one line each, read-path-skipped by default:

```markdown
# Archived Sessions

- SESSION 001 (06-01): catalog scaffold + auth bypass → see Decisions `catalog-auth`
- SESSION 002 (06-02): pluginkit JSON schema
```

### Session ID allocation (sequential + slug + collision suffix)

The number only names the file. Atomicity comes from **exclusive create** (`set -o noclobber`): if the target name exists, the create fails and the writer falls back to a suffix (`036b`, `036c`, …). Both files survive — zero overwrite, zero lost work. This is why a sequential number is safe under concurrency here (unlike appending to one shared file). The `036b/036c` form is the same shape agents already produced under contention.

```bash
SESS_DIR="$FEATURE_DIR/sessions"; mkdir -p "$SESS_DIR"
SLUG="mcp-transport"   # kebab-case from the session title, ≤30 chars
NEXT=$(ls "$SESS_DIR" 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1)
NEXT=$(printf '%03d' $(( 10#${NEXT:-0} + 1 )))
FILE=""
for s in '' b c d e f g h; do
  cand="$SESS_DIR/${NEXT}${s}-${SLUG}.md"
  if ( set -o noclobber; : > "$cand" ) 2>/dev/null; then FILE="$cand"; break; fi
done
[ -n "$FILE" ] || { echo "could not allocate session file"; exit 1; }
echo "$FILE"   # now write the session content into $FILE
```

## Subcommands

### `/track` (no args) — List Features

Defaults to `/track list`.

### `/track list [all|archived]` — List Features

1. Read `.index.json`; if missing, rebuild (same as `/track reindex`).
2. Detect current group and branch.

**`/track list`** (default): current group only, exclude `archived`. Show all `in-progress`; if fewer than 10, fill with most recent `finished` from the same group. Sort in-progress first (by `updated` desc), then finished. Cap at 10.

**`/track list all`**: all groups, all statuses except `archived`, by `updated` desc, no cap.

**`/track list archived`**: only `archived` in current group, by `updated` desc, no cap. Use to find names for `/track unarchive` or `/track switch`.

```
#  Feature                      Status       Description                          Updated
1> auth-refactor                in-progress  OAuth2 + session-token auth mid...   2026-04-04
2  search-v2                    in-progress  Full-text search with filters        2026-03-28
3  api-migration                finished     Migrate REST endpoints to gRPC...    2026-04-02
```

`>` = current branch. Numbers are ephemeral (this invocation only). Description truncated to ~40 chars.

### `/track new <feature-name>` — Create Multi-Repo Feature

1. **Validate**: lowercase alphanumeric + hyphens. Directory must not exist.
2. **Detect context**: identify current repo from `git-common-dir`, look up its group. If already in a group → step 3.

   **If repo is NOT in config** (auto-onboarding):
   1. Auto-detect the current repo's properties (bare path, default branch, short name).
   2. Scan **all working directories** in the session (primary + `/add-dir`). Auto-detect each; skip already-registered.
   3. Present and confirm:
      ```
      Detected repos not in config:
        backend   ~/repos/team/backend.git   (default: main)
        proto     ~/repos/team/proto.git     (default: main)

      Add to existing group? [list existing groups]
      Or create new group? Name:
      ```
   4. **Existing group**: add repos to its `repos` list and register in `repos:`.
   5. **New group**: ask group name and `primary`. Create with all discovered repos.
   6. Write `.config.yaml`. Proceed to step 3.

3. **Branch strategy** — ask: "Create new branch or reuse current `<branch>`?" If new: ask base (default: repo's `default_branch`). The **same branch name** across ALL repos in the group.
4. **Create worktrees** for each repo:
   - branch already has a worktree → record path
   - branch exists, no worktree → `git worktree add <branch> <branch>`
   - branch doesn't exist → `git worktree add -b <branch> <branch> <default_branch>`
   - Worktree dir name = branch name (unless reusing existing like `dev/` for `dev-cc`)
5. **Create v2 skeleton**:
   - `$FEATURE_DIR/spec.md` with frontmatter (`description: ""`) + this body:
     ```markdown
     # {Title-Cased Name} — Spec

     ## Current State

     ### Decisions

     ### Open Risks & TODOs
     - [ ] (bootstrap)

     ### Key Files
     | Repo | File | Purpose |
     |------|------|---------|

     ### Verify Status

     ### Active Sessions

     ## Sessions (TOC)

     | # | Slug | Date | Status | One-liner |
     |---|------|------|--------|-----------|
     ```
   - `$FEATURE_DIR/sessions/` (empty dir; `mkdir -p`)
   - `$FEATURE_DIR/archive.md` with header `# Archived Sessions`
6. **Update index**: append a new entry (`layout: "v2"`).
7. Print worktree paths.

### `/track switch <N|name>` — Context Import

Pure **context import** — no persistent state change. Loads a feature into the current session for orientation.

1. **Resolve target**:
   - number N → `.index.json`, same sort/filter as `/track list` (current group), Nth (1-indexed); out of range → error with valid range.
   - string name → `$FEATURES_DIR/<name>/`.
   - no arg → run `/track list` and stop.
2. **Print worktrees + orientation**:
   - **v2**: print frontmatter + `## Current State` + `## Sessions (TOC)`. This is the cold-start save-game — NOT the full history. Tell the user to `/track read --session N` for a specific session or `--full` for everything.
   - **legacy**: print the full `spec.md` (it predates v2; if it is very large, print frontmatter + the top ~150 lines, which are newest-first, and note it is a large legacy spec).
   ```
   Feature: auth-refactor (group: main, branch: auth-refactor, layout: v2)

   Worktrees:
     backend   /path/to/backend.git/auth-refactor
     proto     /path/to/proto.git/auth-refactor

   --- Current State ---
   [Current State block]
   --- Sessions (TOC) ---
   [TOC]
   ```

### `/track read [N|name] [--session N|--full|--archive]` — Read a Feature Spec

Resolve the target like `/track switch` (no arg → current-branch feature; number → indexed; name → direct).

**v2 default** (no flag): print frontmatter + `## Current State` + `## Sessions (TOC)`. Bounded and cold-start-friendly.
- `--session <N>`: print `sessions/<N>*.md` (the single session file).
- `--full`: print Current State + every session file in order (paginate by reading files sequentially; warn if total is large).
- `--archive`: print `archive.md`.

**legacy**: print the full `spec.md`. If it exceeds a single read, print frontmatter + top ~150 lines and offer to page through the rest. (The old "always print full" rule is retired — it does not survive large specs.)

If not found: "Feature `<name>` not found." If no current-branch feature: "No tracked feature on branch `{BRANCH}`. Use `/track list`."

### `/track update` — Record Work into the Spec

Writes the agent's OWN session file (no contention with other agents) and refreshes the shared Current State snapshot.

1. **Detect feature from current branch**. If none: "No tracked feature on branch `{BRANCH}`. Use `/track list`."
2. **If legacy layout** (no `sessions/`): you MAY initialize v2 in place — create `sessions/` + `archive.md`, and lift the existing inline "current state"-ish sections into a `## Current State` block at the top of `spec.md` (keep the old sections below for now). If the user hasn't asked to migrate, it is also fine to keep appending in legacy style — do not silently restructure a large legacy spec mid-crunch. Default: initialize v2 only for small/young legacy specs; leave large ones legacy and just append a dated section.
3. **Gather context from ALL repos** in frontmatter, sequentially:
   ```bash
   cd <worktree-path>
   git log --oneline -20
   git diff --stat HEAD~5..HEAD
   ```
4. **Write a new session file** (v2): allocate the filename (see *Session ID allocation*), then write the session using the `sessions/<NNN>-<slug>.md` template. Prefix commits with repo name: `[backend] a1b2c3d fix: …`. Record crux → decisions → implementation (HEAD/commit/file anchors) → ship/e2e → 待办/教训 (`[[memory-links]]`). The session is frozen after this write.
5. **Refresh `## Current State`** (overwrite in place, **incrementally**): take the existing Current State + the session you just wrote → produce the updated block. NEVER re-summarize all sessions from scratch.
   - `### Decisions`: add/overwrite by key (last write wins); drop superseded conclusions.
   - `### Open Risks & TODOs`: carry verbatim; check off resolved, add new. **Never compact this section.**
   - `### Key Files`: merge by repo|file.
   - `### Verify Status`: replace with the latest pass/fail + deployed revision.
   - `### Active Sessions`: point at this session (and any other in-progress ones).
6. **Regenerate `## Sessions (TOC)`**: one row per file in `sessions/` (newest-first) — number, slug, date, status badge, one-liner from the session's title/crux.
7. **Frontmatter**: set `description` to the ≤80-char one-liner from Current State if empty/stale; set `updated` to today; ensure `status: in-progress`.
8. **Compaction check**: if `sessions/` has > 8 non-archived files OR active sessions total > ~12KB, run `/track compact` (or tell the user it is due). See `/track compact`.
9. **Update index**: patch this feature's entry (`description`, `updated`, `layout`).
10. **Memory check**: review work since last update; persist non-obvious lessons/gotchas/feedback to the project's `memory/` (see `MEMORY.md` index). Only what would prevent repeating mistakes.
11. **Docs check**: if behavior/commands/components changed, update project docs (README/CLAUDE.md) or note what needs updating in the session's 教训.
12. Print a summary: session file written + Current State diff highlights.

### `/track compact` — Roll Up Old Sessions

Keeps the live spec bounded without losing history. Borrows recursive incremental summarization (MemGPT/LangChain) + read-path truncation (event sourcing).

1. Detect feature (current branch, or `name`/`N` arg). Must be v2.
2. **Keep the most recent 8 sessions** verbatim in `sessions/` (sliding window).
3. **Fold older sessions** into Current State, one at a time, oldest first: `new_currentstate = refine(current_currentstate + folding_session)`. **Never rebuild from the full history.**
   - durable decisions/constraints → `### Decisions` (dedupe by key)
   - unresolved TODOs / gotchas / pitfalls → `### Open Risks & TODOs` **verbatim (exempt from compaction)**
   - changed files → `### Key Files` (dedupe by repo|file)
4. **Append a one-line digest** of each folded session to `archive.md`: `- SESSION N (date): <≤12-word conclusion>`. Then **move** the folded session file out of `sessions/` into `sessions/archive/` (or delete after confirming its digest+durable content landed). Sessions are not destroyed silently — the digest + the durable bits in Current State are their retained form.
5. Regenerate the Sessions TOC, update `updated`, patch index.

**Retain verbatim vs compress** (cross-method consensus):

| Retain verbatim (exempt) | Compress to one line |
|---|---|
| architectural / design decisions **+ rationale** | full tool/command output → conclusion only |
| open bugs / risks / pitfalls / gotchas ⚠️ | intermediate reasoning / dead ends → "tried A,B; chose C" |
| constraints / invariants / "must do X, never Y" | routine git log/diff dumps → "changed X, Y" |
| TODOs / current progress | redundant / superseded discussion |
| changed files + key code anchors | |
| errors + their fixes (conclusion line) | |
| original user intent | |

**Iron rule**: maximize recall first, then precision. `### Open Risks & TODOs` and any Lessons are **never** compacted (over-compaction drops context that only later proves critical). Current State (conclusions) and sessions (raw) must not restate each other — that double-storage is the bloat v2 removes.

### `/track verify [name|N]` — Reconcile Claims Against Code

Catches drift between what the spec claims and what the code does (replaces the stale Implementation-Status-table problem).

1. Detect feature. Read `## Current State` (Decisions, Key Files, Verify Status) and any "done"/"shipped" claims in recent sessions.
2. For each claimed-complete item, search the code for evidence (the files/symbols it names).
3. Report two lists: **claimed done but no code evidence** and **code clearly done but unrecorded**. Do not edit the spec automatically — surface findings; the user/agent decides what to fix or record.

### `/track done [N|name]` — Finish Feature

1. **Resolve target** (no arg → current branch; N → indexed; name → direct).
2. Read the feature's `## Current State` (v2) or full `spec.md` (legacy).
3. **Output-surface precheck (BLOCKING).** Before flipping status, answer literally, in user-facing text:

   > "List every user-observable path this feature claims to cover. For each, point at the code (file:line) that implements it. List every path you considered and consciously decided NOT to cover, with the reason."

   If the feature is framed in surface-level terms — "every reply", "all messages", "footer on X", "thread-id on every send" — this is REQUIRED. Grep every site producing that surface (e.g. all `Channel.send` / `sendFormatted` / `openReply` / `openProgress` / `sendDraft` / `edit` / `react` callers) and reconcile each against the spec's claimed coverage (`### Key Files` / Decisions / session implementation notes). If a path is missing, implement it now or add an explicit "Out of scope: <path> because <reason>" to `### Open Risks & TODOs`. If a path is claimed but its user-observable behavior has not been demonstrated end-to-end (test, fixture replay, or live verification), it is NOT done — fix it before step 4. Tiny single-file features may state "single-site change, no surface audit needed" and proceed. (Consider running `/track verify` first.)

   Rationale: prevents shipping with fallback / non-canonical paths unfixed. See the `feedback-audit-output-surfaces` memory.
4. Set `status: finished`; `updated` = today.
5. Write back.
6. **Update index**: set `status: finished`, update `updated`.
7. Feature directory stays intact (browsable archive).
8. Print:
   ```
   Finished: auth-refactor (group: main)
   Spec retained at ~/.agents/.features/auth-refactor/
   To clean up worktrees: `git worktree remove <path>` in each repo.
   ```

**Do NOT append to `finished_features.md`** — legacy archive, historical reference only.

### `/track archive [N|name]` — Archive Feature

Soft-delete. Archived features are hidden from all lists but remain on disk. Use when exploring multiple design approaches — archive the ones not chosen.

1. **Resolve target** (no arg → current branch; N → indexed; name → direct). If already archived: "Already archived." and stop.
2. Set `status: archived`; `updated` = today. Write back.
3. **Update index**: `status: archived`, update `updated`.
4. **Remove worktrees** for each repo in frontmatter:
   ```bash
   cd <bare-repo-path>
   git worktree remove <worktree-path>
   ```
   - current working directory → warn and skip: "Skipped `<path>` — it is the current directory. Remove manually after switching."
   - uncommitted changes → `git worktree remove` fails; warn: "Worktree `<path>` has uncommitted changes — skipped. Force with `git worktree remove --force <path>` if safe."
   - already gone → skip silently.
5. **Delete branches** after worktrees removed:
   ```bash
   cd <bare-repo-path>
   git branch -d <branch>
   ```
   - `-d` refuses unmerged → warn: "Branch `<branch>` in `<repo>` has unmerged commits — skipped. Force with `git branch -D <branch>` if safe."
   - current branch in some worktree → skip with warning. Doesn't exist → skip silently. Never delete remote branches.
6. Feature directory stays intact (the spec is the archival record).
7. Print:
   ```
   Archived: search-v2-experiment (group: darkmatter)
   Spec retained at ~/.agents/.features/search-v2-experiment/
   Removed worktrees and branches: backend, proto
   Use `/track list archived` to see archived features. Restore: `/track unarchive <name>`
   ```

### `/track unarchive <name>` — Restore Archived Feature

1. Look up `$FEATURES_DIR/<name>/spec.md`. Not found → "Feature `<name>` not found."
2. Not archived → "Feature `<name>` is not archived (status: {status})." and stop.
3. **Recreate worktrees** (same logic as `/track new` step 4):
   - branch has a worktree → record path
   - branch exists, no worktree → `git worktree add <worktree-path> <branch>`
   - branch only on remote → `git worktree add -b <branch> <worktree-path> origin/<branch>`
   - branch gone everywhere → `git worktree add -b <branch> <worktree-path> <default_branch>`
   - Update worktree paths in frontmatter if changed.
4. Set `status: in-progress`; `updated` = today. Write back.
5. **Update index**: `status: in-progress`, update `updated`.
6. Print worktree paths + "Restored: <name> (status: in-progress)".

Requires an explicit name — no N-based resolution (archived features aren't numbered in regular lists). Use `/track list archived` to find the name.

### `/track reindex` — Rebuild Feature Index

1. List all directories in `$FEATURES_DIR` containing `spec.md`.
2. For each, parse frontmatter; detect `layout` (`sessions/` present → `v2`, else `legacy`). Extract name, group, status, description, branch, repos (keys), created, updated.
3. Missing `status`: infer from `finished_features.md` — name in a `## {Name} (completed …)` heading → `finished`, else `in-progress`. Write it back.
4. Missing `description`: leave empty (next `/track update` fills it). If a v2 spec's description is a giant legacy digest, replace it with the ≤80-char one-liner from `## Current State`.
5. Missing `created`: use `updated`. Write it back.
6. Sort by `updated` desc. Write `.index.json`.
7. Print: "Rebuilt index: N features (M in-progress, K finished, J archived; P v2, Q legacy)."

## Design Reference Workflow

When starting a new feature that may share patterns with past ones:

1. `/track list all` — scan descriptions across groups.
2. Identify features with similar scope/architecture/repos.
3. `/track read <name>` — for v2, read `## Current State` (Decisions, Key Files) first; drill into a session with `--session N` if needed.
4. Review their Decisions, Open Risks, and session 教训.
5. Apply patterns, avoid documented pitfalls.

The `description` field enables quick scanning; `## Current State` is the fast deep-orientation without reading full history.

## Multi-Agent Coordination

The v2 layout is designed for several agents working one feature concurrently — shared truth, independent progress.

- **Cold-start a new session/agent**: `/track list` → `/track switch N`. Switch prints Current State + Sessions TOC (orientation), not the whole history.
- **During work**: each agent is on the feature branch — `/track read --session N` to drill in, `/track update` to record.
- **Recording is contention-free**: each `/track update` writes the agent's **own** `sessions/<NNN>-<slug>.md`. Two agents never write the same session file — exclusive-create + collision suffix (`036` vs `036b`) guarantees it. No numbering races, no merge conflicts on the log.
- **Current State is the one shared mutable surface**: it is small and section-structured, so refreshes are quick and edits can be scoped to a single subsection. Keep updates short; the heavy detail lives in the session file, not here.
- **No file locking** — sessions are append-only-by-construction; Current State is a low-frequency overwrite of a derived snapshot.

## Migration

**v1 → v2** (first access after this update):
- If `.index.json` is missing, run a full reindex (backfills `status`, `created`, `layout`).
- Delete any `.current-{group}` or `.current` files — no longer used.
- `finished_features.md` is read-only; `/track reindex` reads it to infer `finished`. Do not append.
- **Existing single-file specs keep working as `legacy`.** They are not auto-migrated. `/track new` creates v2; `/track update` may initialize v2 for small legacy specs (step 2) but leaves large in-progress legacy specs alone unless the user asks to migrate.
- **Bloated frontmatter `description`** (a multi-KB rolling digest) on a legacy spec: shrink to ≤80 chars on the next `reindex`/`update` by taking the first real one-liner; the long digest's content already lives in the spec body.

To migrate a specific legacy spec to v2 on request: split its newest-first session-like blocks into `sessions/<NNN>-<slug>.md` (preserve order and original numbering where present), build `## Current State` from the most recent block, move the rest into `archive.md`, and back up the original `spec.md` first. This is mechanical and reversible but touches an in-use spec — do it deliberately, not as a side effect.

## Important

- NEVER read an archived feature's spec — archived = failed experiments; stale context pollutes new work.
- `~/.agents/.features/` is global — works from any repo, any worktree.
- Same branch name across all repos in a group. Feature names: lowercase-hyphenated.
- **v2 sessions are append-only & frozen.** To revise a conclusion, write a new session, never edit an old one.
- **`## Current State` is the only rewritable block**, and only because it is a derived snapshot. `### Open Risks & TODOs` and Lessons are never compacted.
- frontmatter `description` is ≤80 chars — never a rolling digest.
- `.index.json` is auto-maintained — do not hand-edit. Run `/track reindex` if stale.
- `/track list` numbers are ephemeral (current invocation only). Always show the list before using a number with `/track switch N`.
- Absolute worktree paths in frontmatter — no guessing. If config is missing, create `.config.yaml` via the auto-onboarding flow in `/track new`.
