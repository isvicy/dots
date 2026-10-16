#!/usr/bin/env python3
"""Push a computed per-pane display name to the `$display` sidebar token.

Priority: custom agent name (herdr agent rename) > herdr pane label (herdr
pane rename) > agent terminal title > meaningful tab label > agent type.
Terminal titles may be generated or manually renamed; their spelling does
not tell us which. Accept readable titles, including CJK and spaces, but skip
known default titles such as "Claude Code". For Codex, remove the trailing
current-directory segment from its default title. Bare-number tab labels
("1", "8") are skipped.
Values carry a TTL, so panes that vanish stop being reported and the token
disappears from the sidebar on its own.

Runs as a herdr plugin [[startup]] hook: herdr launches this when the server
starts and kills it on shutdown, so no LaunchAgent/systemd unit is needed.
"""
import json
import os
import shutil
import subprocess
import time

SOURCE = "plugin:isvicy.display-name"
POLL_SECONDS = 3
TTL_MS = "15000"

def find_herdr_bin():
    # herdr injects HERDR_BIN_PATH into plugin commands; fall back to PATH
    # and well-known locations for running standalone (e.g. debugging).
    return (
        os.environ.get("HERDR_BIN_PATH")
        or os.environ.get("HERDR_BIN")
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


HERDR_BIN = find_herdr_bin()


def herdr_env():
    # Plugins inherit HERDR_SOCKET_PATH from herdr, so `herdr` CLI calls land
    # on the right session socket automatically. When run standalone, allow
    # an explicit override via the environment.
    env = dict(os.environ)
    return env


def herdr(*args):
    proc = subprocess.run(
        [HERDR_BIN, *args],
        capture_output=True,
        text=True,
        env=herdr_env(),
    )
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout).get("result")
    except (json.JSONDecodeError, AttributeError):
        return None


def title_name(agent):
    title = (agent.get("terminal_title_stripped") or "").strip()
    kind = (agent.get("agent") or "").casefold()
    cwd = agent.get("foreground_cwd") or agent.get("cwd") or ""
    directory = os.path.basename(cwd.rstrip("/"))
    defaults = {"", kind}
    if kind == "claude":
        defaults.add("claude code")
    elif kind == "codex":
        # Strip only a verified directory suffix, not arbitrary pipes in a
        # session name. Without a thread name, Codex shows just the directory.
        suffix = f" | {directory}"
        if directory and title.endswith(suffix):
            title = title[:-len(suffix)].strip()
        elif directory:
            defaults.add(directory.casefold())
    elif kind == "pi" and directory:
        defaults.add(f"π - {directory}".casefold())
    return title if title.casefold() not in defaults else None


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
