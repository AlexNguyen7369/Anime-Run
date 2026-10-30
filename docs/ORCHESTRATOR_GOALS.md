# Orchestrator goals

Owner's end goals for `/orchestrate` (config `.claude/orchestrator.md`). Only the owner adds, changes or closes a goal.
Game rules stay in `docs/GAME_DESIGN_REQUIREMENTS.md` and the specs.

## Global
- Definition of done (every deliverable): its harness scenarios green, the full harness `[CARTEST] END fail=0`, rules
  audit PASS (owner 2026-10-28).

## fork-ivs: Idle Vehicle Simulator code forked into AnimeRun
Status: done (merged into main 2026-10-28, PR #1, 039ad28)
Owner-confirmed: 2026-10-28
Branch: feature/alex/fork-ivs (created on the first task)
Deliverables:
- f1 | IVS code copied in (`default.project.json`, `src/`, harness, `stylua.toml` / `selene.toml`, place file) | `rojo build` succeeds; `stylua --check src` and `selene src` clean
- f2 | Car -> character rename in names and ids (`CarCatalog` -> `CharacterCatalog`, `src/shared/Cars/` -> `src/shared/Characters/` holding the 30 approved characters as placeholder entries with neutral ids, design doc section 5); gameplay unchanged | harness green; no real names in ids
- f3 | Full harness green on an AnimeRun place in Studio | `[CARTEST] END fail=0`; rules audit PASS
Out of scope: new mechanics (team, stamina, bonuses, potions, stat point), final character art, Robux products,
merging into `main` (owner's call).

## anime-world: World redesign, every car model scrapped (replaces anime-maps)
Status: active (next after fork-ivs; before anything else, owner 2026-10-28)
Owner-confirmed: 2026-10-28 (scope); deliverables w1-w5 confirmed by owner 2026-10-28
Branch: feature/alex/anime-world (created on the first task)
Spec: docs/WORLD_REDESIGN_SPEC.md, docs/TRACKS_AND_BIOMES_SPEC.md
Deliverables:
- w1 | Placeholder anime runner on the rail replaces the car body; car physics and car-physics scenarios retired | `runner` + `scrap` scenarios green; full harness `[CARTEST] END fail=0`
- w2 | World layout + anime town plaza hub + 7 Dojo plots (Dojo squad rule) | `world_layout` + `dojo` + `spawn_area` green
- w3 | Track tests for Tracks 1-10, then layouts 1-10 at 984 x F x 1.25^(n-1) (F = 3) along the spiral, each researched from its anime (spec References) | every track test + chain green
- w4 | Biome themes 1-10, researched from public info on each anime and matched closely within section 5 | `environment` + clearance green; IP check PASS
- w5 | Rules audit PASS on the integration branch | `RULES AUDIT: PASS`
Out of scope: final character art, Robux products, merging into `main`.
