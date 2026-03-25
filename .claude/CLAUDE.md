## General Guidelines

- **Tools**: Use rg not grep, fd not find, tree is installed
- **Style**: Prefer self-documenting code over comments, and as of comments, you should make sure it's necessary for
  senior developers, don't add comments for obvious things.

## Git Conventions Section

- Never use `--no-verify` when committing. Always let pre-commit hooks and CI checks run.
- Always run lint and test commands before committing. Check the project README or local dev docs for the correct
  commands if unsure.

## Workflow Section

- When asked to build a tool or implement a feature, make a plan first and confirm with the user before starting
  implementation. Do not start coding autonomously without alignment.

## Compact Instructions

Preserve:

1. Architecture decisions (NEVER summarize)
2. Modified files and key changes
3. Current verification status (pass/fail commands)
4. Open risks, TODOs, rollback notes
