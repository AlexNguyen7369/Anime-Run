# Agent handoff

## State — 2026-10-28
- Specs written (no code yet): `docs/GAME_DESIGN_REQUIREMENTS.md`, `TEAM_AND_STAMINA_SPEC.md`,
  `CHARACTER_GACHA_SPEC.md`, `NPC_RIVAL_SPEC.md`, `RESEARCH.md`.
- Owner decisions: original characters, stamina refills every run, exhaustion cashes out the bank.

## Next
1. Owner: answer design doc section 8 open questions; approve the launch cast and stamina numbers.
2. Fork code from IVS: copy `default.project.json`, `src/` and the harness; rename car -> character
   (`CarCatalog` -> `CharacterCatalog`, `EquippedCar` -> `Team`); drop `CarPhysics`/`CarFactory` for a rigged runner on
   the `RaceService` rail.
3. Tests first: `team`, `stamina` (see `TEAM_AND_STAMINA_SPEC.md`), then implement `Shared/StaminaConfig` and the
   stamina tick + swap in `RaceService`.
