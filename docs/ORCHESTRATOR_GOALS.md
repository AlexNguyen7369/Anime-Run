# Orchestrator goals

Owner's end goals for `/orchestrate` (config `.claude/orchestrator.md`). Only the owner adds, changes or closes a goal.
Game rules stay in `docs/GAME_DESIGN_REQUIREMENTS.md` and the specs.

## Global
- Definition of done (every deliverable): its harness scenarios green, the full harness `[CARTEST] END fail=0`, rules
  audit PASS (owner 2026-10-28).

## fork-ivs: Idle Vehicle Simulator code forked into AnimeRun
Status: active
Owner-confirmed: 2026-10-28
Branch: feature/alex/fork-ivs (created on the first task)
Deliverables:
- f1 | IVS code copied in (`default.project.json`, `src/`, harness, `stylua.toml` / `selene.toml`, place file) | `rojo build` succeeds; `stylua --check src` and `selene src` clean
- f2 | Car -> character rename in names and ids (`CarCatalog` -> `CharacterCatalog`, `src/shared/Cars/` -> `src/shared/Characters/` holding the 30 approved characters as placeholder entries with neutral ids, design doc section 5); gameplay unchanged | harness green; no real names in ids
- f3 | Full harness green on an AnimeRun place in Studio | `[CARTEST] END fail=0`; rules audit PASS
Out of scope: new mechanics (team, stamina, bonuses, potions, stat point), final character art, Robux products,
merging into `main` (owner's call).

## anime-maps: Longer tracks and anime biomes
Status: active (after fork-ivs)
Owner-confirmed: 2026-10-28 (request, numbers and deliverables)
Branch: feature/alex/anime-maps (created on the first task)
Deliverables:
- m1 | Track tests for Tracks 1-10 (target length +-5%, validator rules, chain, 0 flips / 0 off-track) written red | tests exist and fail on the old layouts
- m2 | Track layouts 2-10 at the new lengths, Track 1 unchanged | every track test green; full harness `[CARTEST] END fail=0`
- m3 | Biome themes 1-10 (TRACKS_AND_BIOMES_SPEC.md table) | `environment` scenario green; prop clearance green; IP check (no logos / real names) PASS
- m4 | Rules audit PASS on the integration branch | `RULES AUDIT: PASS`
Out of scope: final character art, Robux products, merging into `main`.
