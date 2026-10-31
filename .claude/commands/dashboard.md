---
description: Start the Anime Run dashboard (orchestration state, board, handoff, commits, harness gate) and print its URL.
argument-hint: "[--port N] [--lan]"
---

Start the local Anime Run dashboard with the options: $ARGUMENTS

1. If `curl -s -m 2 http://127.0.0.1:<port>/api/meta` (default port 8766; 8765 is the IVS dashboard) already answers, it is running: just print the URL.
2. Otherwise run `python3 tools/dashboard/server.py $ARGUMENTS` with `run_in_background: true`, wait until `/api/meta` answers, and print the URL.
3. Tell the user what the gate light currently says (`/api/gate` `text`).

The server is read-only. `--lan` binds 0.0.0.0 so teammates on the same network can view it.
The gate reads `.agents/gate.json` (`{"end": "[CARTEST] END pass=N fail=N", "commit": "<sha>"}`), written after a harness run.
