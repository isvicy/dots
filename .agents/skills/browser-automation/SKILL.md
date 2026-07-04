---
name: browser-automation
description: Pick and drive the right browser-automation tool — agent-browser (default; token-lean, exploratory) vs playwright-cli (scripted flows via run-code, plus tracing/mocking/codegen). Read this BEFORE automating a browser — navigating, clicking, filling forms, scraping, testing a web app, or driving a logged-in site. Routes to the agent-browser and playwright-cli skills. Playwright MCP is intentionally not loaded.
---

# Browser automation — which tool, and how to drive it

Two CLIs are installed and both attach to the **same real Chrome**. Choose by *interaction pattern*, not habit. Playwright MCP is deliberately **not** loaded (~4× the tokens plus a per-call snapshot-latency tax) — use these instead.

## Decision (start here)

- **Default → `agent-browser`** — exploratory / step-by-step work where you snapshot between actions to decide the next one.
- **`playwright-cli` via `run-code`** — a *known, pre-plannable* multi-step flow.
- **`playwright-cli` (any mode)** — when you need Playwright's deeper toolbox: network mocking (`route`), tracing, video, **codegen → durable tests**, Firefox/WebKit, or spec-driven testing.

## Why — measured on a heavy SPA, both attached to the logged-in `:9222` Chrome

| flow: open → agent-mode → send | latency | page snapshot |
|---|---|---|
| agent-browser (per-command) | ~1.9s | 951 chars |
| playwright-cli (per-command) | **~10.4s ⚠️** | 3702 chars |
| playwright-cli `run-code` (batched) | ~1.7s (~1.5s w/ `waitUntil:'commit'`) | — |

The dominant cost is the **per-action page snapshot**, which scales with DOM size. playwright-cli (like Playwright MCP) auto-snapshots after *every* command → per-command driving on a heavy page is slow. Batching with `run-code` takes no inter-step snapshots → fast. agent-browser stays fast per-command because its snapshots are ~4× smaller.

## Rules

1. **Reading page state between steps to decide what to do next?** → `agent-browser` (you pay the snapshot tax every step; its cheap snapshots win).
2. **Flow known up front?** → `playwright-cli run-code "async page => { … }"` (one process, no inter-step snapshots). **Never** drive a heavy SPA as many separate `playwright-cli <cmd>` calls — that's the ~10s trap. Batch it, or add `--raw` to suppress the per-command snapshot.
3. **Tracing / `route` mocking / video / codegen→tests / Firefox|WebKit / spec-driven testing?** → `playwright-cli` only.
4. **Fast `waitUntil`** for scripted navigations: `page.goto(url, {waitUntil:'commit'})`.
5. **Batching caveat** — `run-code` shines when steps are pre-plannable. If each step must *read* the previous result to decide the next, you're back to snapshot-per-action → prefer `agent-browser`.

## Attach to your logged-in Chrome (`:9222` — see the `share-chrome-profiles` skill)

```bash
# agent-browser (default)
agent-browser --cdp 9222 open "https://example.com"
agent-browser --cdp 9222 snapshot -i -c        # compact, ref-based (@eN)

# playwright-cli — attach to the CDP endpoint (official)
playwright-cli attach --cdp=http://localhost:9222
# or (verified working): env var + open
PLAYWRIGHT_MCP_CDP_ENDPOINT=http://localhost:9222 playwright-cli -s=work open

# known flow → ONE run-code call
playwright-cli -s=work run-code 'async page => {
  await page.goto("https://example.com/", {waitUntil:"commit"});
  await page.click(".submit");
}'
```

## Hand off to the tool's own skill

- **agent-browser** → the `agent-browser` skill (`agent-browser skills get core --full`).
- **playwright-cli** → the `playwright-cli` skill (its `SKILL.md` + references: tracing, request-mocking, test-generation, spec-driven-testing).
