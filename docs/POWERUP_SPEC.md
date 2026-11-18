# Track power-ups: design spec

Rules: design doc 4.44 (owner 2026-11-11). This spec never contradicts it. Values marked **proposed** are
orchestrator defaults the owner may change.

## Placement
- Regular track runs on Tracks 1-10 only. None in boss arenas or duels (**proposed**).
- Rolled by the server for each player when a track starts, fresh every run (a loss reset rerolls) (**proposed**).
- Count `ceil(trackLength / 500)` (owner 2026-11-16 "more per track"; the number is a placeholder, design doc). Spots
  between 10% and 90% of the track, at least 150 studs apart (**proposed**; was 300 at 1 per 1,000). Type 50/50 Speed / Stamina (**proposed**).
- On the player's lane, on the rail the runner follows, so each one is picked up when the runner's distance passes it.

## Types
| Type | Effect | Notes |
|---|---|---|
| Speed | cruise x1.2 for 1 s (owner 2026-11-16; was 2 s, before that x1.5 for 3 s) | May pass `MAX_CRUISE` (owner). A second Speed while one is active resets the timer to 1 s, no stacking (**proposed**). Applies to whoever runs, so it carries across a tag-in (**proposed**). |
| Stamina | no stamina drain for 2 s (owner 2026-11-16; was +3 s / +2 s of overfill) | Holds whoever runs, so it carries across a tag-in (**proposed**). A second Stamina while one is active resets the timer to 2 s, no stacking (**proposed**). `Stamina<n>` never exceeds 100. |

## Server
- `Shared/PowerUpConfig`: `SPEED_MULTI 1.2`, `SPEED_SECONDS 1`, `STAMINA_SECONDS 2`, `PER_STUDS 500`, `EDGE 0.1`,
  `MIN_GAP 150`.
- `RaceService` (only with `options.PowerUps`, which `Attach` sets for real runs; test runs keep exact timings): rolls
  on track start, sends the set to the owner only (`RunEvent { Kind = "PowerUps", Track, Route, List }`), takes each
  one on the tick that passes it (`RunEvent { Kind = "PowerUpTaken", Id, Type, Track }`), applies the effect. The
  boost multiplies the run's speed after the cap; the `Cruise` attribute keeps the character's own cruise. Player attribute
  `PowerSpeedUntil` (server time) while a Speed boost runs, `PowerStaminaUntil` while a Stamina boost runs (the stamina
  drain skips while `run.StaminaLeft > 0`; a track-loading hold pauses both).

## Client (display only)
- `Client/PowerUpView`: draws the owner's set on the player's lane from `RunRoutes`, plays the idle animation,
  a pickup effect on `"Taken"`, clears on run end. REDUCED EFFECTS drops particles and lights.
- Team row: the running slot's seconds number turns blue while `PowerStaminaUntil` is in the future.
- Look (design doc 4.44): a ring standing across the player's lane, about 12 studs across (**proposed**), its centre
  6 studs over the rail. Speed orange (255, 154, 31) with a "»" inside; Stamina the stamina bar's Full blue (`StaminaConfig.COLORS.Full`, 60, 150, 255) with "+" (plain
  text symbols, no image asset, **proposed**; a drawn chevron / drop image can replace them). Idle (owner 2026-11-11): the dashed rim pattern turns (one turn per 4 s, **proposed**) and the glow breathes
  (1.6 s, **proposed**); REDUCED EFFECTS keeps only the turn. Pickup: the ring scales up 1.4x and fades in 0.25 s (**proposed**). Rim of 16 pieces, glow light range 14, HUD badge 26 px (**proposed**, display constants).
- HUD (draft H2): `Client/TeamHud` shows a badge on the running portrait's top-right corner while `PowerSpeedUntil`
  is in the future, its ring draining to that time. The seconds number turns blue while `PowerStaminaUntil` is ahead.

## Tests (to write first)
- `powerups`: count per track and spacing; two players on one track get different sets; Speed x1.2 for 1 s then
  back, passes 800 on a Secret, reset on a second pickup; Stamina holds the running slot's stamina for 2 s, never
  above 100, then drains again; none in boss or duel runs; NPC time unchanged.
- UI: number blue during a Stamina boost; active power-up HUD shows and hides with the boost.
