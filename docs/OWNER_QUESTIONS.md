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
