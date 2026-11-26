#!/usr/bin/env python3
"""24/7 orchestrator runner: every tick is a fresh `claude -p` session (a fresh context window).

  python3 runner.py <repo>            loop forever
  python3 runner.py <repo> --once     one tick

After each session it reads the state file's phase:
  handoff                   start the next session at once (context was full; it continues from the handoff)
  idle / blocked            sleep --idle seconds (default 1500)
  anything else             sleep 60; after 3 failed or crashed sessions in a row, stop and tell the owner on the bus
Stop: create <repo>/.agents/orchestrator.stop (removed on the next start), or `launchctl bootout` the agent.
Log: <repo>/.agents/orchestrator-runner.log; each session's output: <repo>/.agents/runs/<time>.log
"""
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time

PROMPT = ("Invoke the orchestrator skill with argument: tick. You run unattended (CLAUDE_ORCH=1): never use "
          "AskUserQuestion; anything for the owner goes to the owner channel and the bus, and the task is marked blocked. "
          "Keep the state file's phase current; end with phase idle, blocked or handoff.")


def log(root, text):
    line = f"{datetime.datetime.now().isoformat(timespec='seconds')} {text}"
    print(line, flush=True)
    with open(os.path.join(root, ".agents", "orchestrator-runner.log"), "a", encoding="utf-8") as f:
        f.write(line + "\n")


def state_path(root):
    try:
        front = open(os.path.join(root, ".claude", "orchestrator.md"), encoding="utf-8").read().split("---")[1]
        m = re.search(r"^state:\s*([^#\n]+)", front, re.M)
        return os.path.join(root, m.group(1).strip() if m else ".agents/orchestrator.json")
    except (OSError, IndexError):
        sys.exit(f"no .claude/orchestrator.md in {root}")


def phase(root):
    """(phase, updated) from the state file."""
    try:
        with open(state_path(root), encoding="utf-8") as f:
            st = json.load(f)
        return st.get("phase") or "", st.get("updated") or ""
    except (OSError, ValueError):
        return "", ""


def tell_owner(root, text):
    bus = os.path.join(root, "tools", "dashboard", "agent_bus.py")
    if os.path.isfile(bus):
        subprocess.run([sys.executable, bus, "send", "--from", "claude", "--to", "user", text], cwd=root)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--idle", type=int, default=1500)
    a = ap.parse_args()
    root = os.path.abspath(a.repo)
    os.makedirs(os.path.join(root, ".agents", "runs"), exist_ok=True)
    stop = os.path.join(root, ".agents", "orchestrator.stop")
    if os.path.exists(stop):
        os.remove(stop)
    claude = shutil.which("claude") or "/opt/homebrew/bin/claude"
    env = {**os.environ, "CLAUDE_ORCH": "1"}
    fails = 0
    log(root, f"runner start ({claude})")
    while not os.path.exists(stop):
        out = os.path.join(root, ".agents", "runs", datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + ".log")
        before = phase(root)[1]
        log(root, "tick: fresh session")
        with open(out, "w", encoding="utf-8") as f:
            rc = subprocess.run([claude, "-p", PROMPT], cwd=root, env=env, stdout=f, stderr=subprocess.STDOUT).returncode
        p, updated = phase(root)
        if updated == before:
            p = "stale"  # the session never wrote its state: treat as a failure, never as a handoff
        log(root, f"session exit {rc}, phase {p!r}, output {out}")
        if a.once:
            break
        if rc == 0 and p == "handoff":
            fails = 0
            continue
        if rc == 0 and p in ("idle", "blocked"):
            fails = 0
            wait = a.idle
        else:
            fails += 1
            if fails >= 3:
                log(root, "3 failed sessions in a row: stopping")
                tell_owner(root, f"Orchestrator runner stopped after 3 failed sessions. Last output: {out}")
                break
            wait = 60
        end = time.time() + wait
        while time.time() < end and not os.path.exists(stop):
            time.sleep(5)
    log(root, "runner stop")


if __name__ == "__main__":
    main()
