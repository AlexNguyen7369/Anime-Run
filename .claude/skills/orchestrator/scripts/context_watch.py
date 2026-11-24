#!/usr/bin/env python3
"""Context-window overseer for orchestrator sessions (Claude Code hook; wired in ~/.claude/settings.json).

Acts only in a repo with .claude/orchestrator.md, and only for orchestrator sessions: started by the runner
(env CLAUDE_ORCH=1) or whose prompt invoked /orchestrate. Every other session gets no output.

  UserPromptSubmit  register the session when the prompt is /orchestrate (or the orchestrator skill)
  PostToolUse       measure the context from the transcript's newest usage; write it to the state file;
                    at WARN tell the agent to tidy, at HANDOFF tell it to write the handoff and end the turn
  PreCompact        log an event (auto-compaction is the fallback when the handoff did not happen in time)
  SessionStart      after compact / clear / resume, or a runner start: inject the handoff + state so work continues

Config (front matter of .claude/orchestrator.md, all optional): context_window (default 200000),
context_warn (0.60), context_handoff (0.75), state, handoff.
"""
import datetime
import json
import os
import re
import sys

DEFAULTS = {"context_window": 200000, "context_warn": 0.60, "context_handoff": 0.75,
            "state": ".agents/orchestrator.json", "handoff": "handoff.md"}


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def config(root):
    try:
        text = open(os.path.join(root, ".claude", "orchestrator.md"), encoding="utf-8").read()
    except OSError:
        return None
    cfg = dict(DEFAULTS)
    front = text.split("---")[1] if text.startswith("---") else ""
    for key in DEFAULTS:
        m = re.search(rf"^{key}:\s*([^#\n]+)", front, re.M)
        if m:
            v = m.group(1).strip()
            cfg[key] = type(DEFAULTS[key])(v) if not isinstance(DEFAULTS[key], str) else v
    return cfg


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, path)


def context_tokens(transcript):
    """Tokens in the context at the newest assistant turn (input + cache read + cache write + output)."""
    try:
        with open(transcript, "rb") as f:
            f.seek(0, 2)
            f.seek(max(0, f.tell() - 400_000))
            lines = f.read().decode("utf-8", "ignore").splitlines()
    except OSError:
        return None
    for line in reversed(lines):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        u = (e.get("message") or {}).get("usage") if e.get("type") == "assistant" else None
        if u:
            return sum(u.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens",
                                                "cache_creation_input_tokens", "output_tokens"))
    return None


def emit(event, text):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}))


def resume_brief(root, cfg, why):
    st = read_json(os.path.join(root, cfg["state"]), {})
    open_tasks = [t for t in st.get("tasks") or [] if t.get("status") not in ("merged",)]
    tasks = "\n".join(f"- {t.get('id')} [{t.get('status')}] {t.get('title', '')} | branch {t.get('branch', '')} | "
                      f"worktree {t.get('worktree', '')} | {t.get('note', '')}" for t in open_tasks) or "- none"
    try:
        handoff = open(os.path.join(root, cfg["handoff"]), encoding="utf-8").read()
    except OSError:
        handoff = "(no handoff file)"
    if len(handoff) > 12000:
        handoff = handoff[:12000] + "\n... (truncated; read the file for the rest)"
    return (f"ORCHESTRATOR RESUME ({why}). This is a fresh context window. Continue the orchestrator from its "
            f"saved state; do not restart finished work.\n"
            f"State file {cfg['state']}: phase={st.get('phase')} tick={st.get('tick')} "
            f"resume_step={st.get('resume_step', '')}\nOpen tasks:\n{tasks}\n"
            f"Next: run the orchestrator skill (tick). Step 3 picks your own unfinished task from the handoff first.\n"
            f"--- {cfg['handoff']} ---\n{handoff}")


def main():
    try:
        hook = json.load(sys.stdin)
    except ValueError:
        return
    root = os.environ.get("CLAUDE_PROJECT_DIR") or hook.get("cwd") or os.getcwd()
    cfg = config(root)
    if not cfg:
        return
    event = hook.get("hook_event_name", "")
    sid = hook.get("session_id", "")
    reg_path = os.path.join(root, ".agents", "orchestrator_sessions.json")
    reg = read_json(reg_path, {})
    if os.environ.get("CLAUDE_ORCH") == "1" and sid and sid not in reg:
        reg[sid] = {"since": now(), "levels": []}
        write_json(reg_path, reg)
    if event == "UserPromptSubmit" and re.search(r"/orchestrate\b|orchestrator skill", hook.get("prompt", "")) and sid not in reg:
        reg[sid] = {"since": now(), "levels": []}
        write_json(reg_path, reg)
    if sid not in reg:
        return

    state_path = os.path.join(root, cfg["state"])
    if event == "SessionStart":
        src = hook.get("source", "startup")
        if src in ("compact", "clear", "resume") or os.environ.get("CLAUDE_ORCH") == "1":
            reg[sid]["levels"] = []  # a fresh window: warnings may fire again
            write_json(reg_path, reg)
            emit("SessionStart", resume_brief(root, cfg, f"session {src}"))
        return
    if event == "PreCompact":
        st = read_json(state_path, {})
        st.setdefault("events", []).append({"at": now(), "kind": "compact", "from": "orchestrator", "to": "orchestrator",
                                            "text": "auto-compaction: handoff was not written in time"})
        st["events"] = st["events"][-200:]
        write_json(state_path, st)
        return
    if event not in ("PostToolUse", "UserPromptSubmit"):
        return

    used = context_tokens(hook.get("transcript_path", ""))
    if used is None:
        return
    pct = used / cfg["context_window"]
    st = read_json(state_path, {})
    st["context"] = {"session": sid, "tokens": used, "window": cfg["context_window"], "pct": round(pct, 3), "at": now()}
    write_json(state_path, st)
    levels = reg[sid].setdefault("levels", [])
    if pct >= cfg["context_handoff"] and "handoff" not in levels:
        levels.append("handoff")
        write_json(reg_path, reg)
        emit(event, f"CONTEXT {pct:.0%} of {cfg['context_window']} tokens: hand off NOW. 1) Finish or park the current "
             f"step (do not start a new subagent). 2) Update {cfg['handoff']}: state, active files, changes, blockers, exact "
             f"next steps. 3) In {cfg['state']} set phase='handoff' and resume_step to the exact next action, and add an "
             f"event kind 'handoff'. 4) Clear the bus claim only if no work is mid-flight. 5) End your turn with "
             f"'HANDOFF WRITTEN'. The runner (or the next /orchestrate) continues in a fresh window from the handoff.")
    elif pct >= cfg["context_warn"] and not levels:
        levels.append("warn")
        write_json(reg_path, reg)
        emit(event, f"CONTEXT {pct:.0%}: keep tool output small, delegate reads to subagents, and keep "
             f"{cfg['handoff']} current. A handoff is required at {cfg['context_handoff']:.0%}.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # a hook must never break the session
        print(f"context_watch: {e}", file=sys.stderr)
