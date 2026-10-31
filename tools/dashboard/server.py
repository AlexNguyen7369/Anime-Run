#!/usr/bin/env python3
"""Anime Run local dashboard: orchestration state, board, handoff, git, test gate. Stdlib only, read-only."""

import argparse
import json
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATIC = Path(__file__).parent / "static"
STATE = ROOT / ".agents" / "orchestrator.json"
GATE = ROOT / ".agents" / "gate.json"  # written after a harness run: {"end": "[CARTEST] END pass=N fail=N", "commit": sha}


def git(*args):
	r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
	return r.stdout.strip()


def read_text(path):
	try:
		return Path(path).read_text()
	except OSError:
		return ""


def read_json(path):
	try:
		return json.loads(Path(path).read_text())
	except (OSError, ValueError):
		return None


def meta():
	return {
		"root": str(ROOT),
		"developer": git("config", "user.name"),
		"branch": git("branch", "--show-current"),
		"head": git("rev-parse", "--short", "HEAD"),
		"dirty": git("status", "--short").splitlines(),
		"commits": [dict(zip(("sha", "date", "author", "subject"), l.split("\t", 3)))
			for l in git("log", "-15", "--pretty=%h%x09%ad%x09%an%x09%s", "--date=short").splitlines()],
		"worktrees": [l.split()[:3] for l in git("worktree", "list").splitlines()],
	}


def gate():
	g = read_json(GATE)
	if not g or not g.get("end"):
		return {"verdict": "unknown", "text": "No harness result recorded yet (.agents/gate.json)"}
	m = re.search(r"pass=(\d+) fail=(\d+)", g["end"])
	if not m:
		return {"verdict": "unknown", "text": "Unreadable harness result: " + g["end"]}
	fail = int(m.group(2))
	if fail:
		return {"verdict": "red", "text": f"Harness failing: {g['end']}", **g}
	changed = git("diff", "--name-only", g.get("commit", "HEAD"), "--", "src") if g.get("commit") else ""
	if changed or git("status", "--short", "--", "src"):
		return {"verdict": "stale", "text": f"src changed since last green harness ({g['end']}): rerun it", **g}
	return {"verdict": "green", "text": f"Harness green: {g['end']}", **g}


ROUTES = {
	"/api/meta": meta,
	"/api/gate": gate,
	"/api/orchestrator": lambda: read_json(STATE) or {},
	"/api/board": lambda: {"text": read_text(ROOT / "docs" / "BOARD.md")},
	"/api/handoff": lambda: {"text": read_text(ROOT / "handoff.md")},
	"/api/owner": lambda: {"text": read_text(ROOT / "docs" / "OWNER_QUESTIONS.md")},
}


class Handler(BaseHTTPRequestHandler):
	def do_GET(self):
		path = self.path.split("?")[0]
		if path in ROUTES:
			body, ctype = json.dumps(ROUTES[path]()).encode(), "application/json"
		elif path == "/":
			body, ctype = (STATIC / "index.html").read_bytes(), "text/html; charset=utf-8"
		else:
			self.send_error(404)
			return
		self.send_response(200)
		self.send_header("Content-Type", ctype)
		self.send_header("Cache-Control", "no-store")
		self.end_headers()
		self.wfile.write(body)

	def log_message(self, *a):
		pass


if __name__ == "__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("--port", type=int, default=8766)  # 8765 is the IVS dashboard
	ap.add_argument("--lan", action="store_true", help="bind 0.0.0.0 (read-only; there are no write endpoints)")
	a = ap.parse_args()
	host = "0.0.0.0" if a.lan else "127.0.0.1"
	print(f"Anime Run dashboard: http://127.0.0.1:{a.port}", flush=True)
	ThreadingHTTPServer((host, a.port), Handler).serve_forever()
