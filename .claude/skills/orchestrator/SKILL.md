---
name: orchestrator
description: Project orchestrator. Watches every running session (Claude, Codex, collaborators), picks the next task from the project's board, checks it against the project's design rules, delegates it to the right subagent, verifies it with the project's tests, commits it to a feature branch and keeps the handoff and boards current. Adapts per repo through `.claude/orchestrator.md`. Use for /orchestrate, "run the orchestrator", "keep development going", "manage the sessions", or as the body of a /loop.
argument-hint: "[tick | loop | dry | goals]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill, Workflow, WebFetch, WebSearch, AskUserQuestion, ScheduleWakeup, SendMessage, ListAgents, TaskStop, Monitor, EnterWorktree, ExitWorktree, mcp__Roblox_Studio, mcp__blender, mcp__claude-artifacts, mcp__claude_ai_Claude_Docs, mcp__claude_ai_Google_Drive
---

# Orchestrator

You run one **tick** of the project's development loop. A tick ends after one task is landed, blocked or handed back. You can also end a tick when there is nothing to do. `/loop` (dynamic) or `/schedule` paces the next tick. Never spin inside one turn waiting for work.

Arguments:
- `tick` (default): one full tick.
- `dry`: steps 1-4 only. Report what you would do, and change nothing.
- `goals`: run step 0b only. Review or extend the goals with the owner.
- `loop`: start `/loop` with `/orchestrate tick` in dynamic mode. When a tick ends idle, use ScheduleWakeup with 1200-1800 s.
- `run`: start the 24/7 runner (section "Context windows"). Every tick then runs in a fresh window.
- `stop`: create `.agents/orchestrator.stop`. The runner stops after its current session.

## 0. Load the project config

Read `.claude/orchestrator.md` at the repo root. Its YAML front matter gives every repo-specific fact: rules docs, handoff file, task board, bugs, owner channel, bus, branch, test and post-commit commands, exclusive resources, roster and forbidden edits. Its body holds project notes; follow them.

**No config?** Discover what you can:
- CLAUDE.md / AGENTS.md;
- docs/ design or spec files;
- TODO / handoff files;
- `.claude/agents` and `.claude/commands`;
- test commands from package files or Makefiles.

Write a draft `.claude/orchestrator.md` with the same keys, and mark the guesses with `# guess`. Stop and ask the owner to review it. Do not run a tick on a draft config.

## 0b. Vision: goals and deliverables

Read the config's `goals` file. Ask the owner (AskUserQuestion, full sentences, one question per gap) in any of these cases:
- the file is missing;
- no goal is `active`;
- an active goal has no deliverables or definition of done;
- the board's next task does not map to any goal;
- the owner asked for `goals`.

Ask for:
1. The end goal: what the player or user gets, in one sentence.
2. The deliverables: concrete outputs (features, files, assets, a playable build).
3. The definition of done: the exact tests, checks or demo that prove each deliverable.
4. The priority order and any deadline.
5. What is out of scope.

Write the answers to the goals file with the date, in this form:
`## <goal-id>: <title>`, then `Status: active|done|paused`, `Owner-confirmed: <date>`, `Branch: <integration branch>`, `Deliverables:` (one line each: id, output, done-when), `Out of scope:`.

Read the answers back in one short summary, and get a yes before acting on them. Never invent a goal or a deliverable. Ask again only when one of the cases above appears, not on every tick.

Every task picked in step 3 must serve an active goal's deliverable. Name both in every brief.

## 1. Sync state

Run these together:
- Read the handoff file.
- Run the bus `context` and `inbox` commands, if a bus is configured.
- Call `ListAgents` to see live local or cloud sessions.
- Run `git status --short`, `git branch --show-current` and the `overview` command, if one is configured.
- Read the task board.

Build a picture of three things:
- who is working on what, and which files they claim;
- what is uncommitted;
- what is `doing` or `next` on the board.

## 2. Resolve messages

Answer bus and session messages. Route each one to the session that owns its topic. Use the bus `send` command or `SendMessage`.

Some messages need the owner: a question about a rule, a request that conflicts with the docs, or a choice between designs. Never decide those yourself. Pass them on through the owner channel (step 4).

## 3. Pick the task

Pick in this order:
1. Your own unfinished task from the handoff.
2. The board's `doing` item.
3. Open bugs of kind `failure`.
4. The board's `next` item.

Only tasks that serve an active goal (step 0b) qualify. Parallel tasks are allowed only when their file sets do not overlap. Split a task, or run it later, rather than let two agents touch one file.

Skip a task in either case:
- Its files overlap a file another session claims, or another collaborator's unmerged branch (`overview`).
- It needs an exclusive resource (for example a single Studio) that someone else holds.

If nothing is pickable, report the idle state and end the tick.

## 4. Rules gate

Do this before any code is written.
- Read the top design doc and every spec the task touches (from the config's `rules`).
- Values the docs mark as tunable (the config says how they are marked) may change. Every other value is fixed.

Stop the task when any of these is true:
- the task conflicts with the docs;
- the code it would change conflicts with the docs;
- it is a new feature that has no rule written yet.

When the task stops:
- Write an entry to the owner channel with why, what it blocks and the exact question.
- Send a bus message to `user`.
- Mark the task blocked on the board, with a note.
- Do not delegate. Go on to the next pickable task, or end the tick.

Write down the rules the task relies on, with doc file and section. They go into every brief.

## 5. Delegate

1. Branches:
   - Each goal has one **integration branch**, started with the config's `branch_start` command the first time; it is the goal's `Branch:`.
   - Each task gets its own **task branch** `orch/<goal-id>/<task-id>`, made from the integration branch, in its own worktree: `git worktree add <worktrees_dir>/<task-id> -b orch/<goal-id>/<task-id> <integration branch>`.
   - Never work on a protected branch.
2. Claim: run the bus `status` command with the task and its files.
3. Brief the right agent from the config's `roster`. Give it:
   - the goal;
   - the rules from step 4;
   - its files;
   - the forbidden edits;
   - "done" stated as the exact test result.
4. Run the agent in that task worktree. Tell it the absolute worktree path, and that it may edit only there.
   - An exclusive resource with an `isolate` recipe in the config (for example one app instance per task) is set up for the task by following those steps, so the task runs asynchronously. On any break listed in `fallback_when`, tear down what you started and put the task in the resource's `queue`; it waits its turn.
   - A resource with no recipe is always queued. Record `resource`, `instance` and `port` (or `queued`) in the task's state entry. Exclusive resources (the config's `exclusive_resources`) are used by one agent at a time. Claim each one through the bus before use, and release it after.

5. Record the task in the config's `state` file (see "State file").

You may use every skill, plugin, MCP server, agent type and Workflow the task needs. Pick the specialist one when it exists, for example a Roblox skill or the Studio MCP for Studio work. The orchestrator skill's own invocation counts as the opt-in for Workflow fan-out. Keep it at or under the session's workflow size guideline.

## 6. Verify

- Run the config's `tests` that fit the change.
- Spawn `rules-auditor` (or the auditor the config names) with the diff and the step-4 rules.
- Red results go back to the implementer and are verified again. There is no round cap.
- Three rounds in a row with identical failures: change strategy once. If they repeat after that, escalate to the owner (step 4 channel) and end the tick.

Every bug a subagent finds goes to the config's `bugs` command.

## 7. Land

Land only when the tests are green and the auditor says PASS.
1. In the task worktree, `git add` only the task's files (never `-A`). Commit with a clear message and the attribution trailers from the system reminder.
2. In the integration worktree, check for conflicts with `git merge-tree --write-tree <integration> <task branch>`, then run `git merge --no-ff <task branch>`. If there is a conflict, do not resolve it by guessing. Send the task back, or ask the owner.
3. Re-run the fast checks on the integration branch.
4. Push only the integration branch (`git push origin <integration branch>`).
5. Remove the task worktree and delete its task branch (both were created by this orchestrator).
6. Run every `post_commit` step.

Committing and pushing feature, integration and task branches is always allowed.

**Into main, only through a reviewed PR.** When every deliverable of a goal is done and its goal-level check (the config's `tests.large_change`) is green:
1. Open a PR from the integration branch into the protected branch (config `merge.open`). The PR body lists the deliverables, the test results and the rules relied on.
2. Spawn a **fresh** reviewer: the config's `merge.reviewer` agent, or `general-purpose` with the same brief. Give it ONLY the PR number and the repo path. No summary, no conclusions, no task history, so its review is not anchored on yours.
3. On `MERGE REVIEW: APPROVE`, merge with the config's `merge.merge` command and set the goal's `Status: done`.
   On `MERGE REVIEW: CHANGES`, turn each blocking item into a task on the same goal, fix it, push, and run a new fresh review.
   After 2 CHANGES rounds on the same item, ask the owner.
4. Tell the owner the PR link and the result.

## 8. Bookkeeping

- Update the handoff file: state, changes, blockers and exact next steps.
- Update the board: done to `done` with the date, and the next item to `doing`.
- Update every other file the config's `bookkeeping` lists.
- Clear the bus claim.

End with a short report:
- task;
- result;
- tests (exact pass/fail counts);
- commit sha and branch;
- what was skipped and anything blocked on the owner.

## State file

Keep the config's `state` file (JSON) current at every step, because the dashboard draws the orchestration flow from it:

```json
{"updated": "<iso>", "tick": 12, "phase": "sync|vision|pick|gate|delegate|verify|land|idle|blocked",
 "goals": [{"id": "", "title": "", "status": "active", "branch": "", "deliverables": [{"id": "", "output": "", "done_when": "", "status": "open|done"}]}],
 "tasks": [{"id": "", "goal": "", "deliverable": "", "title": "", "agent_type": "", "agent_id": "",
            "branch": "orch/<goal>/<task>", "worktree": "<abs path>", "files": [],
            "status": "queued|running|verifying|green|merged|blocked|failed",
            "resource": "isolated|queued|none", "instance": "<studio_id>", "port": 0, "tests": "", "audit": "PASS|FAIL|NEEDS OWNER|", "started": "", "finished": "", "note": ""}],
 "studio_queue": ["<task-id>"],
 "events": [{"at": "", "kind": "", "task": "", "text": ""}]}
```

Write it atomically: write a temporary file, then rename it over the state file. Keep the last 200 events.

## Context windows (always on while this skill is active)

`scripts/context_watch.py` is a hook: global in `~/.claude/settings.json`, or per repo in `.claude/settings.json` when the skill lives in the repo's `.claude/skills/`. It watches every orchestrator session: one the runner started (`CLAUDE_ORCH=1`), or one whose prompt was `/orchestrate`. It measures the context after every tool call and writes `context` (tokens, pct) into the state file; the dashboard shows it.
- **At `context_warn` (60%):** keep tool output small, delegate reads to subagents, keep the handoff current.
- **At `context_handoff` (75%):** stop starting new work. Update the handoff file (state, active files, changes, blockers, exact next steps). In the state file set `phase: "handoff"`, set `resume_step` to the exact next action, and add an event of kind `handoff`. End the turn with `HANDOFF WRITTEN`.
- **New window:** after a compact, clear or resume, and on every runner start, the hook injects the handoff and the open tasks, so the work continues where it stopped. Step 3 picks your own unfinished task first. Never redo a finished step; check git and the state file first.
- **Fallback:** if auto-compaction comes first, the hook logs a `compact` event and the same brief is injected afterwards.

**Runner (24/7, a fresh window per tick):** `python3 <this skill's directory>/scripts/runner.py <repo>`, kept alive by launchd on macOS (`scripts/install_launchd.sh <repo>`) or a systemd user service on Linux (`scripts/install_systemd.sh <repo>`). After each session it reads `phase`:
- `handoff`: it starts a fresh session at once.
- `idle` or `blocked`: it sleeps 25 minutes.
- anything else, or a state file the session never updated: it counts a failure. After 3 failures in a row it stops and tells the owner on the bus.

**Unattended sessions** (`CLAUDE_ORCH=1`) never use AskUserQuestion. Owner questions, including the goals step, go to the owner channel and the bus, and the task is marked blocked. Set `phase` at the start of every tick (`sync`) and before ending (`idle`, `blocked` or `handoff`).

## Hard limits (config cannot override)

- Never commit to or push a protected branch (`main`, the default branch, or the config's `protected_branches`) directly. Merging into it happens only through an open PR that a fresh merge reviewer approved (step 7).
- Never force-push, rewrite history, reset hard, or delete a branch or file you did not create in this tick.
- Never weaken, skip or delete a test or a target to get green. Never edit the config's `forbidden` paths.
- Never decide a design conflict or invent a rule. The owner decides.
- Never post outside the bus, `SendMessage` to project sessions, and the owner channel. That means no Slack, issues or PR comments unless the owner asked for it this session.
- Never use an exclusive resource another session holds.
- Report results as they are. Show failing output. Name every skipped step.
