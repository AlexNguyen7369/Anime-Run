# Owner questions

## oq1: Publish AnimeRun.rbxl as a new private experience (2026-10-28)
- Status 2026-10-28: published (placeId 102957063656302, universe 10773557968); Rojo on port 34873.
  DONE 2026-10-28: API access verified (DataStore probe OK). Max Players set by owner (Edit-mode Players.MaxPlayers still
  reads 60; check in a live server).
- Why: own DataStores, products, takedown isolation; f3 data tests need Studio API access.
- Blocks: f3 (full harness on an AnimeRun place).
- When: before f3.
- Steps:
  1. In the Studio window showing AnimeRun.rbxl: File > Publish to Roblox As... > Create new experience, name "Anime Run", private.
  2. Game Settings > Security: Enable Studio Access to API Services, Save.
  3. Game Settings > Places (or Permissions): Max Players 7, Save.
  4. File > Save (AnimeRun.rbxl), then tell Claude the new placeId.

## oq2: f3 place file after "logic only, all visuals new" (2026-10-28)
- Owner said 2026-10-28: Anime Run keeps only IVS gameplay logic and concepts; visuals and assets are all different.
- Conflict: handoff/board f3 says "copy IVS IdleVehicleSimulator.rbxl" as the AnimeRun place.
- Question: should f3 instead be "full harness green in the existing Anime Run place (placeId 102957063656302), no IVS
  place contents copied"? Proposed: yes.
- Also: the default `Workspace.SpawnLocation` was deleted in the Anime Run Studio (Edit mode). Save/publish the place
  (File > Save to Roblox) so the deletion persists.
- Blocks: f3.
- ANSWER 2026-10-28 (owner): yes. f3 runs in the Anime Run private experience (placeId 102957063656302); no visual
  content is copied from IVS. Done the same day: default SpawnLocation and the leftover IVS `RedesignCarModels` folder
  (unreferenced by code) deleted from the place. Remaining IVS-styled visuals (Rojo-managed RacingGarage,
  RaceStartPavilion, SpawnMarketplace, StarterGui, CarModels placeholder body) are replaced by goal anime-world (w1, w2).

## oq3: SnapToTerrain may slide or delete props (fw2, 2026-10-31)
- Audit NEEDS OWNER on fw2 (ef501b3 on orch/biomes/fw2). BIOME_ENVIRONMENT_SPEC 3.2 only says props drop onto the
  lowest sample. fw2 also slides a prop toward its road (4 studs per try, up to 24) when it crosses the gap midline
  or a landmark overhangs more than 6 studs, and deletes it if no slide fits. This can delete hero landmarks
  (4.3 fixes 2-4 per biome) with no floor.
- Question: allow slide/delete? Record it in 3.2 with placeholders first? Keep a floor of 2 landmarks per biome?
- Blocks: land Track 2 (fw2).
- ANSWER 2026-10-31 (owner): slide and delete allowed; never delete hero landmarks below 2 per biome (a hero that
  cannot fit stays and is reported as an error); record in spec 3.2 as placeholders. Done on orch/biomes/fw2.

## oq4: Studio generation tools denied overnight (2026-10-31)
- The auto-mode permission classifier denied `mcp__Roblox_Studio__generate_mesh` ("Modify Shared Resources") for the
  Track 4 builder; `insert_asset` / `upload_image` likely the same. Agents may not work around a denial.
- Orchestrator default (owner delegated): Tracks 4-10 are built with terrain, atmosphere, audio, palettes and
  part-built landmarks/props (no Lane A meshes, no new Lane D inserts); each hero def carries a TODO with its intended
  mesh prompt.
- To do on waking: allow those tools (e.g. `/permissions` or settings allow-list for mcp__Roblox_Studio__generate_mesh,
  insert_asset, upload_image), then run a mesh pass per track.
- ANSWER 2026-10-31 (owner): allow all 3. Standing allow rules added to .claude/settings.local.json (local, gitignored)
  for generate_mesh, insert_asset, upload_image; Tracks 4-10 use Lane A meshes + Lane D again.

## oq5: fw3 rule refinements, orchestrator default (2026-10-31, owner delegated)
- A pinned (At) hero whose footprint reaches a road corridor is pushed outward 4 studs per try (max 24) instead of
  warning; measured pushes 4-8 studs (Landmark_259, _263, _315, _49).
- A padded prop (house) whose footprint reaches a corridor sits at the corridor's lowest ground under it (CorridorLow)
  so it never floats; pads never overlap (9 Docks houses removed by that rule).
- Chosen as the recommended fix (houses gap 0, TileRing gap 0, 0 warnings in the Lune harness). Spec 3.2 fw3 bullet.
  Review in the morning; revert = commit on orch/biomes/fw3.

## Morning review list (overnight run, 2026-10-31)
- Track 5 Neon Cursed City still reads very dark in T5_Road / T5_Landmark even after the builder raised the placeholder
  lighting; proposed: raise Ambient/OutdoorAmbient further or lower Atmosphere Density 0.5 -> 0.35 (spec 7 value).
- Track 4 night was brightened after its scenario run (client atmosphere only).
- Track camera: session-only setting (TrackCamera attribute), not saved across sessions, like the other toggles.
- fw4 (orchestrator default): halls in narrow gaps sit at road level (Track 4: 22 of 35) instead of being dropped; 7 fewer padded props kept overall.
- Track 6: billboards show abstract shapes, not made-up text (spec 7 wording; avoids the generator writing real words).
  ToppledRobot hero ~31 x 25 x 31 placed (under the placeholder 60-220 hero height; the mesh generator caps short sides
  at ~16 studs). AcademyTower stretched 2.6x vertically to ~200 placed.
- Track 7: HilltopShrine gable has a tiny gold roof ornament (auditor: not legible, passed); close shot T7_ShrineGable.jpg for review. StoneFox is a scatter prop only (mesh faces away from road).
- 2026-10-31 owner: continue; finish T5 + T7, then Tracks 8-10 this session (Nov 3 pause lifted); orchestrator takes recommended decisions (logged here).
- NPC rival names (spec: label RIVAL over <Name>) are not implemented in code: NpcConfig has no Name field (label shows track08_NPC). Enelu [Enel] is in the spec only; implementing rival names/models is a separate task (not in biome scope).
- Track 7: heroes sized to fit under the 20-40 stud tunnel ceilings (~23-33 tall), below the placeholder 60-220 hero height; the stalled train stands on a bay platform (framework builds bays as platforms).
- Track 5: BrokenStorefront has a weak 'face' reading (two red upper windows over a blank sign band; auditor passed) - see T5_Storefront.jpg. SlicedTower top floats above the cut; viaduct deck stays level (quality, not IP).
