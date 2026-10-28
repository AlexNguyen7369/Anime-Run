# Agent handoff

## State — 2026-10-28
- Specs written (no code yet): `docs/GAME_DESIGN_REQUIREMENTS.md`, `TEAM_AND_STAMINA_SPEC.md`,
  `CHARACTER_GACHA_SPEC.md`, `NPC_RIVAL_SPEC.md`, `RESEARCH.md`.
- Owner decisions: tweaked-name real anime characters (was original, changed 2026-10-28), stamina refills every run, exhaustion cashes out the bank.
- Owner 2026-10-28 (later): Stamina stat point, Stamina potions, runner categories, Series + preset team bonus.
  Written into design doc 4.5-4.8, `TEAM_AND_STAMINA_SPEC.md`, `CHARACTER_GACHA_SPEC.md` (6 tweaked-name real-anime series).

## Next
1. Owner: approve the 30-character cast, 6 series, preset trios and the section 5 safeguards, and the placeholder numbers.
2. Fork code from IVS: copy `default.project.json`, `src/` and the harness; rename car -> character
   (`CarCatalog` -> `CharacterCatalog`, `EquippedCar` -> `Team`); drop `CarPhysics`/`CarFactory` for a rigged runner on
   the `RaceService` rail.
3. Tests first: `team`, `stamina` (see `TEAM_AND_STAMINA_SPEC.md`), then implement `Shared/StaminaConfig` and the
   stamina tick + swap in `RaceService`.
