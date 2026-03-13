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
4. Ask kimi to save the storage state by running this code via `browser_run_code` (use the actual path printed by the script):

```js
async (page) => {
  const context = page.context();
  await context.storageState({ path: '<HOME>/.playwright-profiles/storage-state.json' });
  return 'done';
}
```

Replace `<HOME>` with the actual home directory (e.g. `/Users/username` on macOS, `/home/username` on Linux).

5. Exit kimi

All agents using `--isolated --storage-state` in `~/.mcp/default.json` will pick up the new sessions.
