---
name: nightly-run
description: Unattended work mode. The user is asleep or away for an extended period and will not answer questions. Finish every task in the queue end to end, treat every decision the user would normally approve as pre-approved, pause only on things that cannot be pre-approved (irreversible, destructive, external, money, owner-only rules), and move on to the next task instead of waiting. Use for /nightly-run, "I'm going to sleep", "I'll be away for a while", "run unattended", "keep going without me".
argument-hint: "[task list or focus, optional]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, Skill, Workflow, WebFetch, WebSearch, ScheduleWakeup, SendMessage, ListAgents, TaskStop, Monitor, EnterWorktree, ExitWorktree
---

# Nightly run

The user is away and cannot answer. From now until they return, you are the approver. Do not ask. Do not offer. Do not stop with "let me know". Work the queue to the end and leave a report.

Arguments (optional): a task list or a focus. If given, it is the queue. If not, build the queue from the project's own sources, in this order: the user's last instructions in this conversation, `handoff.md`, `current_progress.md` (What's Next), the project board if one exists, then open TODOs in the current branch's diff.

## Pre-approved (do it, no question)

Anything the user would normally say yes to and that can be undone:

- Reading, editing, creating files inside the repo. Running tests, linters, formatters, builds.
- Committing to the current feature branch. Creating a new feature branch. Pushing a feature branch to its remote.
- Opening or updating a draft PR against the default branch.
- Spawning subagents, running project skills (progress tracker, test harnesses, verify steps).
- Tunable values marked placeholder, proposed or open question in design docs.
- Choosing between implementation approaches. Pick the smallest complete one and note why in the report.
- Installing a dev dependency the task clearly needs.

When the model's own instinct is to ask ("Want me to…?", "Shall I…?", AskUserQuestion), answer yourself with the choice a careful colleague would make, write the choice and its reason in the report, and keep going.

## Never pre-approved (pause, log, move on)

Stop that task at the point where the decision is needed. Do not guess. Record it as BLOCKED with the exact question, then start the next task.

- Anything irreversible or destructive: force push, deleting branches or remote refs, `git reset --hard` on shared work, dropping data, rewriting published history, deleting files outside the repo.
- Merging to the default branch, or marking a PR ready for review when the project owner reviews PRs.
- Publishing or sending to anything outside the repo: public pages, Slack or email to others, uploads to a marketplace or asset store, store listings, anything indexed or cached by a third party.
- Spending money or credits: paid APIs, asset generation with per-call cost, cloud resources.
- Changing a rule the project's docs reserve for the owner (fixed design values, game rules, pricing, saved-data schema), or resolving a conflict between docs.
- Anything an authenticated interactive step would need (logins, 2FA, approving an OAuth prompt).
- Anything the user explicitly said to check with them about, earlier in the conversation or in CLAUDE.md.

Harness permission prompts are not yours to bypass. If a tool call is denied, treat the task as BLOCKED on that permission and move on. For a truly unattended run the user starts the session in a permission mode that auto-approves edits and commands; say so in the report if you hit prompts.

## Loop

For each task in the queue:

1. Read what the task touches (specs, callers, tests) before editing.
2. Do the full task: code, tests, callers, fixtures, docs the project requires. Partial work is not done work.
3. Verify with the project's own checks (tests, lint, format, Studio verify if the project has it). Fix what you broke. A failing check you cannot fix within the task's scope is BLOCKED, not done.
4. Commit on the feature branch with a clear message. Run any commit-triggered project skill (progress tracker etc.).
5. Append one line to the report (below). Next task.

If a task is BLOCKED, leave the work in a committed, non-breaking state (or stash it with a named stash) so the next task starts clean. Never leave the tree half-edited across tasks.

Do not stop because the conversation is long or the queue is long. Use context summaries and keep going. Only end the turn when every task is DONE or BLOCKED.

## Report

Keep a running report at the project root in `nightly-report.md` (create if missing, append a dated section if present). Also update the project's handoff file if it has one. Format:

```
## Nightly run <YYYY-MM-DD HH:MM> → <HH:MM>

### Done
- <task>: <what changed>, <how verified>, <commit sha>

### Decisions I made for you
- <task>: chose <X> over <Y> because <reason>. Revert: <how>.

### Blocked (needs you)
- <task>: stopped at <point>. Question: <exact question>. State: <branch/stash>, <what is left>.

### Skipped
- <task>: <why it could not start>
```

The final chat message is the report's Done / Decisions / Blocked sections, nothing else. Blocked items come first so the user sees them before anything else in the morning.
