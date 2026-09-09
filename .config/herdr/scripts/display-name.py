#!/usr/bin/env python3
"""Push a computed per-pane display name to the `$display` sidebar token.

Priority: custom agent name (herdr agent rename) > herdr pane label (herdr
pane rename) > slug-like terminal title (assigned by launch scripts, e.g.
"compactor-fable-0726") > meaningful tab label > agent type.
Terminal titles that are not slugs (prompt excerpts, URLs, "Claude Code",
CJK text, anything with spaces) are treated as unnamed and skipped, as are
tab labels that are bare numbers ("1", "8").
Values carry a TTL, so panes that vanish stop being reported and the token
disappears from the sidebar on its own.
"""
import json
import os
import re
import shutil
import subprocess
import time

SOURCE = "display-name"
POLL_SECONDS = 3
TTL_MS = "15000"

# A title only counts as an explicit name when it looks like a slug the
# launch tooling would assign: lowercase ASCII, digits, dots, underscores,
# dashes. Anything else (prompt excerpts, URLs, "Claude Code", CJK) means
# the pane was never given a real name.
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")

HERDR_BIN = (
    os.environ.get("HERDR_BIN")
    or shutil.which("herdr")
    or next(
        (
            path
            for path in [
                os.path.expanduser("~/.local/bin/herdr"),
                "/opt/homebrew/bin/herdr",
                "/usr/local/bin/herdr",
            ]
            if os.path.exists(path)
        ),
        "herdr",
    )
)


def herdr(*args):
    proc = subprocess.run([HERDR_BIN, *args], capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout).get("result")
    except (json.JSONDecodeError, AttributeError):
        return None


def title_name(agent):
    title = agent.get("terminal_title_stripped")
    if title and SLUG_RE.match(title):
        return title
    return None


def tick():
    agents = (herdr("agent", "list") or {}).get("agents", [])
    tabs = {t["tab_id"]: t.get("label") for t in (herdr("tab", "list") or {}).get("tabs", [])}
    pane_labels = {
        p["pane_id"]: p["label"]
        for p in (herdr("pane", "list") or {}).get("panes", [])
        if p.get("label")
    }
    for agent in agents:
        pane_id = agent.get("pane_id")
        if not pane_id:
            continue
        custom = agent.get("name") or pane_labels.get(pane_id)
        label = tabs.get(agent.get("tab_id"))
        if not (label and not label.isdigit()):
            label = None
        display = custom or title_name(agent) or label or agent.get("agent")
        if display:
            herdr(
                "pane", "report-metadata", pane_id,
                "--source", SOURCE,
                "--token", f"display={display}",
                "--ttl-ms", TTL_MS,
            )


def main():
    while True:
        try:
            tick()
        except Exception:
            pass  # never die on a bad tick; retry next round
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
