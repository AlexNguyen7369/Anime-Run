# Board

## Doing
- c1 Team of 3 + stamina + swap + exhaustion + run bank + HUD (tests first, f947f51 / 31a4ff7)

## Next
- c2 Runner categories, Stamina stat point, Stamina potion, team bonus
- c3 Full compatibility check (full harness + rules audit, includes anime-world w5)

## Backlog
- Team of 3 + stamina + swap (TEAM_AND_STAMINA_SPEC)
- Series / preset team bonus, Stamina stat point, Stamina potion

## Done
- 2026-10-30 w4 Anime biome themes 1-10 (merge 1de11ce): environment pass=450 fail=0, IVS mesh assets removed; owner rulings: Blossom Shrine Path, Track 1 gate = plaza torii, length-scaled budget, closer horizon
- 2026-10-30 w3 Spiral track layouts 1-10 at 984 x 3 x 1.25^(n-1) (merge 2751d36): chain, world_layout, spawn_area green; wide bends on 7-10 for NPC times
- 2026-10-30 w2 Anime town plaza hub at the world origin, 7 Dojo plots, Dojo squad rule (merge cca9d50): full harness `[CARTEST] END pass=47 fail=0`, spawn_area green after 3 loosened tolerances restored, audit violations fixed; owner 2026-10-30: track chain moved to (-118, TRACK_LIFT, 80), spec section 3 values confirmed, IVS hub-check retirements approved
- 2026-10-30 w1 Placeholder runner replaces the car body, car physics scrapped (merge d5e851b): full harness `[CARTEST] END pass=45 fail=0`, audit PASS after 3 rounds; Speed stat rescale x1e15/3e5 + log-scaled Speed board (LB_Speed_v3) landed with it
- 2026-10-28 f3 Full harness in the Anime Run private experience: `[CARTEST] END pass=49 fail=0` (integration 89c0e81), audit PASS; default SpawnLocation and IVS RedesignCarModels removed from the place
- 2026-10-28 f2 Cars renamed to characters, 33 placeholder characters (9a652dd): full harness pass=47 fail=2, both fixed (sorted-id test, default SpawnLocation removed), data,spawn_area pass=2 fail=0, stylua clean, selene 0 errors, audit PASS
- 2026-10-28 f1 IVS code copied in (IVS 29f3fab): rojo build OK, stylua clean, selene 0 errors / 4 inherited test-file warnings, audit PASS
- 2026-10-28 Design specs, cast approved
