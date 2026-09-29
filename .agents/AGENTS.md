## General Guidelines

- **Tools**: Use rg instead of grep and fd instead of find; tree is installed.
- **Comments**: Prefer self-documenting code. Add a comment only when a senior developer would need it to understand
  the code; skip comments that restate what the code does.
- **Secrets**: Tool output and replies end up in terminal scrollback and session logs, so refer to secrets by name
  (env var, pass entry, file path) and do not print environment variable values or the contents of config files that
  contain credentials.
- **Subagents**: Delegate to a subagent for broad research or exploration that spans many files, directories, or
  sources, or for genuinely independent work that can run in parallel. Do lookups that take a handful of tool calls
  (a known file, a single rg) directly, and do not spawn subagents to double-check your own work.
- **Approval**: Architectural and UI/UX changes are the user's call, and so is the plan for a new tool or feature:
  propose it and get approval before implementing. Small, clearly scoped changes (a one-line fix, a rename, an edit
  the user fully specified) and routine choices within an agreed plan can proceed directly.
- **MR merges**: Merging MRs and enabling auto-merge are the user's call; agents may push, open MRs, address review
  comments and monitor CI.
- **Chinese writing**: When writing Chinese documents, reports, tables, or MR/PR descriptions, load the `zh-writing`
  skill first.

## Communication

- Keep responses focused and concise; skip non-essential context, keep examples minimal, and keep caveats short.
- Match the length of written documents to what the task needs; no filler sections, redundant summaries, or
  boilerplate.

## VCS Conventions

- Let pre-commit hooks and CI checks run on every commit (no `--no-verify`); they enforce commitlint and secret
  scanning that the repos rely on.
- Run the project's lint and test commands before committing. Check the README or local dev docs for the right
  commands if unsure.
- Repos whose path ends in `jj` are managed with jj; repos ending in `.git` are managed with git.
- Create worktrees/workspaces with `mkws <dir> [args]` from inside an existing one; it carries the ignored `.envrc`
  and `*.local.md` files over.

## Compact Instructions

If the current task is associated with a tracked feature, run `/track update` at each milestone so the spec stays
current, and run `/track read <feature name>` after compaction to recover the context.

Preserve in the summary:

1. Architecture decisions, verbatim rather than summarized
2. Modified files and key changes
3. Current verification status (pass/fail commands)
4. Open risks, TODO, rollback notes
