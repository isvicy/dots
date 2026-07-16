#!/usr/bin/env python3
"""Push a computed per-pane display name to the `$display` sidebar token.

Priority: custom agent name (herdr agent rename) > meaningful tab label > agent type.
Tab labels that are bare numbers ("1", "8") are treated as unnamed and skipped.
Values carry a TTL, so panes that vanish stop being reported and the token
disappears from the sidebar on its own.
"""
import json
import subprocess
import time

SOURCE = "display-name"
POLL_SECONDS = 3
TTL_MS = "15000"


def herdr(*args):
    proc = subprocess.run(["herdr", *args], capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout).get("result")
    except (json.JSONDecodeError, AttributeError):
        return None


def tick():
    agents = (herdr("agent", "list") or {}).get("agents", [])
    tabs = {t["tab_id"]: t.get("label") for t in (herdr("tab", "list") or {}).get("tabs", [])}
    for agent in agents:
        pane_id = agent.get("pane_id")
        if not pane_id:
            continue
        custom = agent.get("name")
        label = tabs.get(agent.get("tab_id"))
        if not (label and not label.isdigit()):
            label = None
        display = custom or label or agent.get("agent")
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
