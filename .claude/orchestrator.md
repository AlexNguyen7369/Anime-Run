---
# Project config for the universal `orchestrator` skill (~/.claude/skills/orchestrator). Owner must review
# every `
rules:
  top: docs/GAME_DESIGN_REQUIREMENTS.md
  specs: docs/*_SPEC.md
  tunable_marks: ["placeholder", "proposed", "open question"]
handoff: handoff.md
goals: docs/ORCHESTRATOR_GOALS.md
state: .agents/orchestrator.json
context_window: 200000
context_warn: 0.60
context_handoff: 0.75
worktrees_dir: ../AnimeRun-orch
board: docs/BOARD.md
bugs: append to docs/BUGS.md (name, kind fault|failure, file:line, found-by, summary)
owner_channel:
  file: docs/OWNER_QUESTIONS.md
  bus: none
bus: none
overview: git branch -r --no-merged origin/main
branch_start: git switch -c feature/alex/<slug> origin/main && git push -u origin feature/alex/<slug>
protected_branches: [main]
merge:
  open: gh pr create --base main --head <integration branch> --title "<goal title>" --body "<deliverables, tests, rules>"
  reviewer: general-purpose
  merge: gh pr merge <number> --merge
tests:
  always: ["stylua src", "selene src"]
  harness: Studio test harness copied from IVS (`[CARTEST] END fail=0`), run through the Roblox Studio MCP
  ui: none yet
  large_change: full harness on the integration branch
exclusive_resources:
  studio:

    queue:
      rule: check that no other session (IVS orchestrator included) is using Studio before a test run; one run at a time
    fallback_when: always (no isolate recipe yet)
auditor: general-purpose with the rules-auditor brief from ~/Documents/RobloxGames/.claude/agents/rules-auditor.md
roster:
  tests_write: general-purpose (tests only, written red first)
  general: general-purpose
  world: world-builder
forbidden:
  - test files, except by the test-writing agent
  - renaming or reusing a character `Id` in src/shared/Characters/ or a series `Id`
  - real character or series names in ids, the game title, description, thumbnails, badges or product names (design doc section 5)
  - the "Based on" column leaving docs/ (it never ships)
post_commit: [/progress-tracker]
bookkeeping:
  - handoff.md
  - current_progress.md (via /progress-tracker)
  - docs/BOARD.md
---

# Notes for the orchestrator

- Read `CLAUDE.md` once per session. A new feature goes into the design doc and its spec before any code.
- The game is forked from Idle Vehicle Simulator (`~/Documents/RobloxGames`). Copy code from it; never edit that repo
  from an Anime-Run task.
- Studio is shared with IVS work on this machine: one test run at a time.
