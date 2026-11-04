# Board

## Doing
- first-impression fi3 first-join flow (next)
- c4 Workshop stat boost (owner 2026-11-03, design doc 4.19): orch/core/c4 in ../AnimeRun-orch/c4, implementer running

## Paused
- b2 Tracks 8-10 PAUSED by owner until 2026-11-03 (branches: t8 714b8fc+f6b0ac1 phase 1 Sky Islands -> to be redone as Skypeia; t9 Volcano phase 2 partial; t10 5e3bb17+da0852d phase 1)
- t7 Blossom Shrine Path SUPERSEDED (05cc80e on orch/biomes/t7, reference only)
- b2 implementation PAUSED by owner 2026-10-31 after Track 3; resume on owner's "continue". Open fw2 items: 25 Docks houses + Track 1 VillageHouse (3.6) / ElderHouse (7.0) still float on slopes with Pad; TileRing max gap 11.4 (not ~0); 4 pinned heroes warn "reaches into a road corridor" (Landmark_259, _263, _315, _49); final screenshot set not retaken after fw2 rounds 5-6
- c1 (paused by owner 2026-10-30 for biomes; committed on orch/core/c1, unverified) Team of 3 + stamina + swap + exhaustion + run bank + HUD (tests first, f947f51 / 31a4ff7)

## Next
- char-art: owner reviews assets/characters/contact_sheet.png; then Studio import + R15 rig + `Model` field (new deliverable, owner to confirm)
- c1 must add: exhaustion pays per-distance share of the current track's pad cash (owner 2026-11-01; Track 1 not shortened)
- Tests: retarget CarTest/UiTest off leaderstats.Speed, SetCheckpoint, StatFor, speed admin cmds, EQUIP labels / MarketEquip (slot buttons), GachaService.SpeedMulti (before c3)
- c2 Stamina stat point, upgrade tree Stamina branch, Stamina potion, team bonus, category info card, team row + stamina bar polish: BUILT 2026-11-03, uncommitted, needs Studio check
- c3 Full compatibility check (full harness + rules audit, includes anime-world w5)

## Backlog
- Team of 3 + stamina + swap (TEAM_AND_STAMINA_SPEC)
- Series / preset team bonus, Stamina stat point, Stamina potion

## Done
- 2026-11-03 first-impression fi1 + fi2 (5759bae): plaza and Dojo meshes, loading screen, Market and Race Start landmarks: world_layout, spawn_area, dojo, workshop pass=4 fail=0; rules audit PASS round 2
- 2026-11-03 char-art marks pass: 15 characters' logos and symbols altered, overall designs unchanged, uploaded; rules audit PASS; Studio load check of the new assets open (Studio held)
- 2026-11-03 char-art other 26 in the target look, uploaded; all 30 in game: Studio 30 of 30 with 6 meshes, 0 model load failures; audit 0 violations after the marks ledger fix; real race and harness not run
- 2026-11-03 char-art 4 pilots to the owner's target look + rig scale 0.8 (c26d9ae): rules audit 0 violations, owner ruled on hard facets and series initials; Studio: 4 load, Best Roll correct; full harness and real race not run
- uipolish 2026-11-03: rebirth +5% cruise and speed tile, stamina bar fixes, team row rebuilt with a stamina arc
- 2026-11-03 char-art a1-a3: 30 draft character models (shared chibi Blender base, headless build), art reference sheet, contact sheet (merge 4ae6d23, push failing): rules audit PASS, all 30 Reviewed; owner visual review open
- 2026-11-01 u4 per-slot aura/trail + slot UI, Speed Doubler passes removed, Best Roll fed, upgrade Speed branch +% cruise (merge 98fdad5): Studio: equip slot 1 -> Cruise 24.95, move to slot 2, remove, slot 4 refused, Backpack slot buttons OK, no Speed Doubler in Shop, 0 errors
- 2026-11-01 u1 fixed cruise (rarity x category), Speed stat removed, rebirth luck/XP/point, info-only sensei, workshop pays Money (merge c448a79): Studio smoke: Cruise=20 Common, leaderstats Money only, 0 errors; CarTest/UiTest still reference removed Speed APIs
- 2026-11-01 welcome popup Studio-checked ("Tournament Wasteland" 0.4/2/0.6 s), moved to y 0.22 under AUTO RACE; fixed sky look-ahead nil crash (58190ae)
- 2026-11-01 u2 leaderboards off the plaza (stores untouched), biome welcome popup, speed-scaled sky switch + sky preload (no Studio; open: Best Roll pedestal)
- 2026-11-01 u3 high-speed loading: preload zone + next-track mesh/texture/sky ids, stream-ahead 1.5 s, streaming radius 1024/256 (no Studio; owner open: hero landmark SLIM pop-in)
- 2026-11-01 Track 4 twilight neon + particles (owner): screenshots only (test pause)
- 2026-11-01 b2 Track 10 Green Alien Planet (merge dbb84e1): 25 rows signed; no scenarios (owner test pause); visual pass (haze, teal sea, islets out)
- 2026-11-01 b2 Track 7 Shibuyo Underground (owner redesign; wide tunnel, fight scene) + tunnel framework fw5-fw9 (merge a96717a): Studio pass=4 fail=0, 50 rows signed, rules audit PASS
- 2026-11-01 b2 Track 9 Spirit Realm Desert: pass=3 fail=0, 22 rows signed, live floats max 0.86
- 2026-10-31 b2 Track 8 Skypeia (owner redesign): pass=3 fail=0, 18 rows signed, live floats max 1.05
- 2026-10-31 b2 Track 5 rebuild Burning Cursed City (owner redesign): pass=3 fail=0, 21 rows signed; storefront mesh swapped to parts (face reading)
- 2026-10-31 b2 Track 6 Hero Academy City + fw4 (merge 9858032): pass=3 fail=0, 27 rows auditor-signed; live padded floats T1 0 / T6 0 / T4 2 (1.55)
- 2026-10-31 b2 Track 5 Neon Cursed City + track camera setting (merge 0962287): pass=3 fail=0, 24 rows auditor-signed; camera max yaw step 2.4 deg, OFF regular
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
