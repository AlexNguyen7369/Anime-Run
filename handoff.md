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

## Next
1. f2: car -> character rename + 30 placeholder characters (neutral ids, CHARACTER_GACHA_SPEC.md); neutralize the
   Dragon Ball comments in src/shared/VehicleEffects.luau and context/ProjectContext.luau. Gameplay unchanged; harness green.
2. f3: AnimeRun place file (copy IVS IdleVehicleSimulator.rbxl, git-ignored), full harness `[CARTEST] END fail=0` in
   Studio (shared with IVS: one run at a time).
3. Then team of 3 + stamina (TEAM_AND_STAMINA_SPEC.md), tests first.
