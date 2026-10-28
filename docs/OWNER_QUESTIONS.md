# Owner questions

## oq1: Publish AnimeRun.rbxl as a new private experience (2026-10-28)
- Why: own DataStores, products, takedown isolation; f3 data tests need Studio API access.
- Blocks: f3 (full harness on an AnimeRun place).
- When: before f3.
- Steps:
  1. In the Studio window showing AnimeRun.rbxl: File > Publish to Roblox As... > Create new experience, name "Anime Run", private.
  2. Game Settings > Security: Enable Studio Access to API Services, Save.
  3. Game Settings > Places (or Permissions): Max Players 7, Save.
  4. File > Save (AnimeRun.rbxl), then tell Claude the new placeId.
