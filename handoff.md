# Agent handoff

## State — 2026-10-28
- Specs written (no code yet): `docs/GAME_DESIGN_REQUIREMENTS.md`, `TEAM_AND_STAMINA_SPEC.md`,
  `CHARACTER_GACHA_SPEC.md`, `NPC_RIVAL_SPEC.md`, `RESEARCH.md`.
- Owner decisions: tweaked-name real anime characters (was original, changed 2026-10-28), stamina refills every run, exhaustion cashes out the bank.
- Owner 2026-10-28 (later): Stamina stat point, Stamina potions, runner categories, Series + preset team bonus.
  Written into design doc 4.5-4.8, `TEAM_AND_STAMINA_SPEC.md`, `CHARACTER_GACHA_SPEC.md` (6 tweaked-name real-anime series).

- Orchestrator 2026-10-28: config `.claude/orchestrator.md`, goal `fork-ivs` (docs/ORCHESTRATOR_GOALS.md), integration
  branch `feature/alex/fork-ivs`. f1 landed (IVS 29f3fab copied in; rojo build OK, stylua clean, selene 0 errors with 4
  inherited warnings in CarTest test files; audit PASS). Repo moved to ~/Documents/Github/personal-projects/AnimeRun.

- Studio: Anime Run experience placeId 102957063656302 (universe 10773557968). AnimeRun Rojo = `rojo serve --port 34873`
  from this folder; IVS keeps 34872. Every Studio MCP call names the Anime Run studio id, never Racer RNG.

- f2 LANDED 2026-10-28 (merge 9a652dd on feature/alex/fork-ivs, pushed). Full harness in Anime Run Studio:
  pass=47 fail=2; fixed: data.unknown_ids_preserved (test expected an unsorted id list, fixed by test-writer) and
  spawn_area.spawn_only_spawn_location (default Workspace.SpawnLocation deleted in Edit; owner must save the place).
  Re-run data,spawn_area pass=2 fail=0. Audit PASS. Worktree ../AnimeRun-orch/f2 and branch removed. Rojo 34873 now
  serves this folder.
- Owner 2026-10-28: Anime Run keeps only IVS gameplay logic and concepts; every visual and asset is new.
- Dashboard: `/dashboard` -> http://127.0.0.1:8766 (tools/dashboard, uncommitted; 8765 is IVS).
- 2026-10-28 17:15: Roblox_Studio MCP added to this project (local scope); needs a session restart to load. Resume:
  restart `rojo serve --port 34873` from ../AnimeRun-orch/f2 if not listening, owner connects Anime Run Studio,
  Studio MCP health check (list studios, pick Anime Run, never Racer RNG), run harness for f2.
  Owner wants every relevant skill/plugin used for the redesign (anime-world goal, w1-w5 deliverables still
  "proposed, owner to confirm"): roblox-game-development-lifecycle, roblox-game-skill, roblox-ui(-implementation),
  roblox-vfx, world-builder agent. Blender MCP added (local scope).

- f3 DONE 2026-10-28: full harness `[CARTEST] END pass=49 fail=0` in Anime Run Studio on feature/alex/fork-ivs
  (89c0e81), audit PASS. oq2 answered: Anime Run private experience, no IVS visual content copied. First f3 run was
  lost to a Wi-Fi drop (Team Create disconnect 276); rerun green. All fork-ivs deliverables done.

## Next
1. Owner: close goal fork-ivs (only the owner closes a goal); merging into `main` is the owner's call (out of scope).
2. Owner: confirm anime-world deliverables w1-w5 (docs/ORCHESTRATOR_GOALS.md, "proposed, owner to confirm").
3. Then anime-world w1 (placeholder runner replaces the car body) on feature/alex/anime-world, tests first.
