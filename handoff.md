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

- Owner 2026-10-30: tracks very long (984 x F x 1.25^(n-1), F proposed 3, Track 1 gets a new layout) and biomes
  researched from public info on each anime, matched closely, section 5 safeguards kept. Written into design doc
  4.9 / section 8, TRACKS_AND_BIOMES_SPEC (References section), TEAM_AND_STAMINA_SPEC, goals w3/w4. Open: F (stamina retune done below).

- Owner 2026-10-30 (later): speed over stamina. Base stamina 20/22/24/27/30 (placeholder), Mythic 36, Secret 43;
  Legendary trio clears 10 tracks in ~90 s using its stamina; Marathoner cruise x0.8, stamina x2.0 (proposed),
  Sprinter stamina x0.8 (proposed). NPC speeds unchanged. Owner same day: category speed
  after damping, F = 3 confirmed, Speed stat x(1e15 / 3e5) so 1 Qd = 300K old (design doc 4.11; code not done:
  RaceConfig HALF_STAT / GAIN_PER_SECOND / MAX_STAT, WorkshopConfig.BASE_RATE, 4 CarTest files). Open: old saves.

- 2026-10-30 w1 LANDED (merge d5e851b on feature/alex/anime-world, pushed): full harness pass=45 fail=0, audit PASS.
  Also landed: Speed rescale 4.11 (5bcad37, 97bc576, 9d6ce42, 3344c99) and log-scaled Speed board LB_Speed_v3
  (b92e777). Owner rulings 2026-10-30 in WORLD_REDESIGN_SPEC 2 and design doc 4.11 / change log.
  Studio: 3 IVS leftovers (ReplicatedStorage.RacingGarage, RaceStartPavilion, CarModels) deleted in Edit; OWNER
  MUST SAVE THE PLACE. Owner's /givespeed 1e22 reverted (it lives in Players.<name>.BaseSpeed, not leaderstats).
  Rojo 34873 serves this folder again; the Studio plugin needs Connect after each Rojo restart.
  Harness polling: execute_luau waits of >~2 min time out; poll in <=115 s calls. Play must restart to pick up
  Rojo-synced code.

## Next
1. DONE 2026-10-28: fork-ivs merged into main (PR #1, 039ad28), goal closed. Integration branch for anime-world:
   feature/alex/anime-world.
2. Owner: confirm anime-world deliverables w1-w5 (docs/ORCHESTRATOR_GOALS.md, "proposed, owner to confirm").
3. DONE w1, DONE w2 (merge cca9d50, pushed). Next: anime-world w3 (track tests + layouts 1-10), then w4. Old w2 note: (world layout + plaza hub + 7 Dojo plots), task branch orch/anime-world/w2, tests first
   (`world_layout`, `dojo`, `spawn_area`), WORLD_REDESIGN_SPEC sections 3-5.

- 2026-10-30 w2 LANDED (merge cca9d50 on feature/alex/anime-world, pushed): full harness `[CARTEST] END pass=47
  fail=0`, spawn_area green at the restored tight tolerances. Owner 2026-10-30: plaza centre = world origin, track
  chain moved to TrackBuilder.CHAIN_ORIGIN (-118, TRACK_LIFT, 80); WORLD_REDESIGN_SPEC 3 values are the owner's;
  IVS hub-check retirements approved. Studio id is now 6ea5e972; harness attributes live on ReplicatedStorage and
  the run starts only when CarTestRun changes to true. Startup warning rbxassetid://203785492 = "Pop Close Sound"
  (audio), not referenced by the game; probably a Studio plugin. Rojo 34873 restarted from this folder (Studio
  plugin needs Connect). Worktree ../AnimeRun-orch/w3-research holds 77151e7 (biome References) not yet merged.

- 2026-10-30 w3 PAUSED by owner (tests paused). Worktree ../AnimeRun-orch/w3 (orch/anime-world/w3): tests committed
  49b1ca0; implementer code UNCOMMITTED (10 spiral layouts, TrackValidator TARGET_LENGTH, Ground tiling in
  TrackBuilder/BiomeDressing, per-track yield in Main, VfxArea x=2800). Owner 2026-10-30: track ids kept, full drives
  in full harness, spiral = mean distance, sector = ring band (all in specs, uncommitted in w3 doc edit for ring band).
  Partial harness (Studio af833537): chain PASS, npc PASS (~12 min now), auto_toggle PASS; track:Oval FAIL
  race_path_curvature_shifted=-1 (no sample, Scenarios.luau:391-397, not diagnosed); track:Hill FAIL
  race_path_spacing=17.075>15 (TrackBuilder.Layout 6 deg per turn waypoint; fix: step = max(ceil(|a|/6),
  ceil(arc/12))); world_layout + spawn_area TIME OUT (non-yielding overlap loops WorldTests.luau:129-253, 279-310,
  Scenarios.luau:8577-8597; test-writer fix: broad phase + yields). Not run: track:DragRace..Space, environment.
  Rojo 34873 serves the w3 worktree. Owner wants w4 started after w3 lands.
- 2026-10-30 later: w3 fixes done (uncommitted in ../AnimeRun-orch/w3): TrackBuilder turn step by arc (<=12 studs) +
  S-bend inflection curvature 0 (fixes Hill spacing, Oval -1); test-writer broad-phase + yields in overlap loops
  (TrackChainTests.footprintOverlaps); owner 2026-10-30 ruling: wider bends on Tracks 7-10 so NPC times match the
  spec table (sim within +0.7%); world now spans about +-4150 studs; VfxArea x=5000. Audit: NEEDS OWNER on NPC
  times, answered (wider bends); otherwise clean. Full harness started on the PRE-widening code, then PAUSED by owner.
  Next on resume: full harness on current w3 code, re-audit Tracks 7-10 diff, land w3, start w4 (owner asked).
- Paused full-harness attempt (Studio id now 67a61451-caee-40ec-ada9-80adcbcec7c9): no scenario finished. Only
  START + WARMUP printed; Play stopped by itself ~17 min in (cause unknown; Team Create collaborator present). First
  scenario `runner` drives the whole ~98k-stud route at normal (~88 studs/s, ~18.5 min) and max speed, so it may be slow,
  not hung. On resume: run CarTestOnly="runner" alone and time it; consider a local (non-Team-Create) place copy.
