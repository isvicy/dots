Ensure the browser session is authenticated for a given URL. Loads existing state, checks login status, waits for manual login if needed, then saves updated state.

Argument: URL to authenticate (e.g. `https://manus.im`)

## What to do

Run the following steps. The state file is `~/.browser-profiles/storage-state.json`.

### 1. Load existing state (if any) and open the URL

```bash
STATE_FILE=~/.browser-profiles/storage-state.json
[ -f "$STATE_FILE" ] && agent-browser state load "$STATE_FILE"
agent-browser --headed open "$URL"
agent-browser wait --load networkidle
```

### 2. Check if already authenticated

Take a snapshot and inspect the page. Common signs of NOT being logged in:
- URL contains `/login`, `/signin`, `/auth`, `/sso`
- Page has login form elements (username/password fields, "Sign in" button)
- Page shows "Log in", "Sign up", or similar prompts

```bash
agent-browser get url
agent-browser snapshot -i
```

If the page looks authenticated (dashboard, profile, app content), skip to step 4.

### 3. Wait for manual login

Tell the user:
> The browser is open at `$URL`. Please log in manually in the browser window. Let me know when you're done.

After the user confirms, re-check:
```bash
agent-browser get url
agent-browser snapshot -i
```

Verify the page now shows authenticated content. If still on a login page, tell the user and wait again.

### 4. Save state and close

```bash
agent-browser state save ~/.browser-profiles/storage-state.json
agent-browser close
```

Tell the user the session has been saved and will be available to all browser automation skills (website-debug, agent-browser, etc.).
