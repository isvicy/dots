Print instructions for refreshing the Playwright browser session storage state.

## What to do

Tell the user to run this in a separate terminal:

```bash
bash ~/.claude/scripts/save-browser-session.sh
```

Then explain the workflow:
1. It launches kimi with a persistent (non-isolated) Playwright browser
2. Tell kimi to open each site you need (e.g. "open https://github.com")
3. Log in manually in the browser
4. Ask kimi to save the storage state (e.g. "save storage state to ~/.playwright-profiles/storage-state.json")
5. Exit kimi

All agents using `--isolated --storage-state` in `~/.mcp/default.json` will pick up the new sessions.
