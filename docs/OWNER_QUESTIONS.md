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
