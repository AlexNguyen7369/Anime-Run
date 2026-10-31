# Board

## Doing
- b2 Track 5 Neon Cursed City (PirateCoast): ../AnimeRun-orch/t5 -> studio worktree; then Tracks 6-10
- cam: track-aligned camera setting (owner 2026-10-31), ../AnimeRun-orch/cam (orch/core/cam), code only until Studio free
- fw4: Blocks halls float in the 44-60 shoulder band (T4 15/34, worst 4.8 studs)

## Paused
- b2 implementation PAUSED by owner 2026-10-31 after Track 3; resume on owner's "continue". Open fw2 items: 25 Docks houses + Track 1 VillageHouse (3.6) / ElderHouse (7.0) still float on slopes with Pad; TileRing max gap 11.4 (not ~0); 4 pinned heroes warn "reaches into a road corridor" (Landmark_259, _263, _315, _49); final screenshot set not retaken after fw2 rounds 5-6
- c1 (paused by owner 2026-10-30 for biomes; committed on orch/core/c1, unverified) Team of 3 + stamina + swap + exhaustion + run bank + HUD (tests first, f947f51 / 31a4ff7)

## Next
- b2 Tracks 4-10, one track at a time (after owner says continue), screenshots per track
- c2 Runner categories, Stamina stat point, Stamina potion, team bonus
- c3 Full compatibility check (full harness + rules audit, includes anime-world w5)

## Backlog
- Team of 3 + stamina + swap (TEAM_AND_STAMINA_SPEC)
- Series / preset team bonus, Stamina stat point, Stamina potion

## Done
- 2026-10-31 b2 Track 4 Wisteria Night Mountain + fw3 (merge 4d1b112): pass=3 fail=0, 23 rows auditor-signed, no per-track approval (owner); fw3 houses gap 0 on T2, TileRing 0.7, 0 hero warnings; Creator Store backdoor skybox caught and removed (BUGS)
- 2026-10-31 b2 Track 3 Pirate Harbor Isle + fw2 (merge d6b1402, pushed): OWNER APPROVED visuals; terrain_built, assets_ip, server_lighting_unchanged pass=3 fail=0 (terrain 27.1 s); 25-row ledger auditor-signed; fw2: embank on ramps, BasePivot bob, midline clamp slide/delete, 2-hero floor, pinned heroes never deleted + natural-height pads, house pads, Rock 8A6E52; Track 2 sand road, Embank + BiomeBob back on; Track 3 dock-wood road
- 2026-10-31 t1-review: rules auditor signed Reviewed after close-up IP re-review, PASS (merge d058e8f, pushed)
- 2026-10-31 b2 Track 2 Tournament Wasteland (merge cdf69e3): pass=3 fail=0, auditor-signed ledger (18 rows), screenshots shown to owner
- 2026-10-31 b2 Track 1 Leafwind Village (merge 23a0ffc, OWNER APPROVED 2026-10-31 from screenshots): terrain_built, assets_ip, server_lighting_unchanged pass=3 fail=0; framework: craters, sections, At pin, road z-fight, snap; audit FAIL (builder-signed Reviewed, 4 meshes need close-ups) -> t1-review
- 2026-10-30 b1 Biome environment framework (merge b289cb8): terrain_built, zone_switch, server_lighting_unchanged, assets_ip all pass; terrain 27.0 s / 1600 chunks; audit FAIL fixed (ledger bypass in client); owner: skybox Faces rows, Craters field
- 2026-10-30 b0 BIOME_ENVIRONMENT_SPEC approved (merge 19ad0bf); owner: free Creator Store assets (Lane D), one track at a time
- 2026-10-30 w4 Anime biome themes 1-10 (merge 1de11ce): environment pass=450 fail=0, IVS mesh assets removed; owner rulings: Blossom Shrine Path, Track 1 gate = plaza torii, length-scaled budget, closer horizon
- 2026-10-30 w3 Spiral track layouts 1-10 at 984 x 3 x 1.25^(n-1) (merge 2751d36): chain, world_layout, spawn_area green; wide bends on 7-10 for NPC times
- 2026-10-30 w2 Anime town plaza hub at the world origin, 7 Dojo plots, Dojo squad rule (merge cca9d50): full harness `[CARTEST] END pass=47 fail=0`, spawn_area green after 3 loosened tolerances restored, audit violations fixed; owner 2026-10-30: track chain moved to (-118, TRACK_LIFT, 80), spec section 3 values confirmed, IVS hub-check retirements approved
- 2026-10-30 w1 Placeholder runner replaces the car body, car physics scrapped (merge d5e851b): full harness `[CARTEST] END pass=45 fail=0`, audit PASS after 3 rounds; Speed stat rescale x1e15/3e5 + log-scaled Speed board (LB_Speed_v3) landed with it
- 2026-10-28 f3 Full harness in the Anime Run private experience: `[CARTEST] END pass=49 fail=0` (integration 89c0e81), audit PASS; default SpawnLocation and IVS RedesignCarModels removed from the place
- 2026-10-28 f2 Cars renamed to characters, 33 placeholder characters (9a652dd): full harness pass=47 fail=2, both fixed (sorted-id test, default SpawnLocation removed), data,spawn_area pass=2 fail=0, stylua clean, selene 0 errors, audit PASS
- 2026-10-28 f1 IVS code copied in (IVS 29f3fab): rojo build OK, stylua clean, selene 0 errors / 4 inherited test-file warnings, audit PASS
- 2026-10-28 Design specs, cast approved
