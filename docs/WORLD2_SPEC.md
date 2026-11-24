# World 2: spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.47 (owner 2026-11-23), sections 3, 4.2, 4.8, 4.9, 4.13, 4.15 and 5.
Numbers are **proposed** unless the design doc fixes them. Plan of record:
`~/.claude/plans/scalable-meandering-pearl-of-3527e5c6-6209-4188-9740-d8306567b15b.md`.

## Place
- One source tree, two places. `default.project.json` builds World 1; `world2.project.json` is the same tree plus
  `ReplicatedStorage.WorldId` (IntValue 2). Keep the two files in step when the tree changes.
- `Shared/WorldConfig`: `Id`, `PLACES` (World 1 = 102957063656302; World 2 = nil until the owner creates the place in
  universe 10773557968), `GATE_OPEN = false`, `PROGRESS_KEYS`.
- `Shared/TrackRegistry` loads `Shared/Tracks/World2/` in World 2.

## Save
- One save per player (`PlayerStats_v2`, VERSION unchanged at 19 so live World 1 servers never go read-only).
- `Shared/WorldSave.View` swaps `BestTrack`, `Checkpoint`, `RaceBestTimes`, `Team` and `Equipped` (`WorldConfig.PROGRESS_KEYS`)
  for the world's own on load (a fresh World 2 team is the starter);
  `WorldSave.Fold` writes them to `Worlds.W2` and never touches World 1's top-level keys.

## Travel and gate
- `Server/WorldTravel.Go(player, id)`: saves with the lock released, then `TeleportService:TeleportAsync`. Refused in
  Studio (teleports do not run there) and while the target place id is missing.
- Admin: `/world2 [player]`, `/world1 [player]`.
- Gate: `SpawnArea.WorldGate`, hub-local (194, -176) on the plaza's south-east corner, facing the spawn: a dais, two
  leaning obsidian monoliths, a 16-segment stone ring with a neon lip and a glowing portal disc. In World 1 it is locked:
  crossed chains, a padlock plate, an invisible barrier, "WORLD 2 / COMING SOON". In World 2 it is open ("WORLD 1 /
  ENTER") and its Portal (tag `WorldGate`, attribute `TargetWorld`) sends a touching player back.

## Tracks
Routes are World 1's (same segments, so lengths and the spiral hold); `Shared/Tracks/World2/W2*.luau`.

| Track | Id | Biome key | Series | Biome (working name) | Enemy (based on) |
|---|---|---|---|---|---|
| 1 | W2DevilTokyo | DevilTokyo | Saw Man | Devil Hunter City | Katanah Man (Katana Man) |
| 2 | W2DemonCastle | DemonCastle | Solo Levelup | Demon King's Castle | Barran (Baran) |
| 3 | W2RuinedCityZ | RuinedCityZ | One Punch | Ruined City Zed | Garoo (Garou) |
| 4 | W2HauntedTunnel | HauntedTunnel | Dandadan | Haunted Tunnel Road | Turbo Grammy (Turbo Granny) |
| 5 | W2KaijuBase | KaijuBase | Kaiju No. 8 | Wrecked Kaiju Base | Kaijo No. 9 (Kaiju No. 9) |
| 6 | W2ElvenPlains | ElvenPlains | Frieren | Elven Ruin Plains | Ora (Aura the Guillotine) |
| 7 | W2AntIsland | AntIsland | Solo Levelup | Ant Island | Berru (Beru) |
| 8 | W2MonsterDen | MonsterDen | One Punch | Monster Den | Orochy (Orochi) |
| 9 | W2GoldenCity | GoldenCity | Frieren | Golden City | Machto (Macht) |
| 10 | W2HellGate | HellGate | Saw Man | Hell's Gate | Makina (Makima) |

The "Based on" names stay in docs and never ship (design doc 5).

## Blender first
- `tools/blender/world2/chain.py`: a port of `TrackBuilder.Layout` and the chain; writes `build/world2/chain.json` and
  asserts each length within 5% of target.
- `kit.py` (helpers), `build_track.py` (build, save `build/world2/trackNN_<Key>.blend`, render review shots to
  `assets/world2_draft/trackNN_<Key>/`), `biomes/<Key>.py` (one per biome; parts only, in-house, no signs with text).
- Each prop mesh is one planned asset (`W2_<Key>_<Prop>`, tris printed). Props stay 24+ studs from the road centre line;
  overhead pieces clear the road by 14+.
- Runs headless (`Blender -b --factory-startup --python tools/blender/world2/build_track.py -- <n|all> [--fast]`) or in the
  live Blender through the MCP (`build_track.run(n)`).
- After the owner approves the render set: export the approved props, upload them under the asset ledger rules
  (BIOME_ENVIRONMENT_SPEC 4.4), and write the game BiomeThemes from the same data.

### Render set approvals
- Bar before the owner sees a track: an independent reviewer scores it 7/10 or more against the source refs, scene
  shots and hero-model close-ups together (owner 2026-11-23).
- A track whose score stalls is shown to the owner as-is, with its score and the reviewer's open gaps, instead of
  looping further (owner 2026-11-23).
- Approved by the owner 2026-11-23: Track 4 HauntedTunnel (round 8, commit 0d4ad6d), Track 8 MonsterDen (round 6,
  eecf599), Track 10 HellGate (round 6, aa95d45). These are frozen: no edits without the owner's word.
- Approved by the owner 2026-11-23 (second batch, as shown on the page at their last reviewed commit): Track 1
  DevilTokyo (6fbb25e), Track 3 RuinedCityZ (11045e6), Track 6 ElvenPlains (dfe607d), Track 7 AntIsland (24c6008). Frozen.
  Unreviewed partial rounds started after those commits are kept in git stash, not applied.
- Not approved, work continues: Track 9 GoldenCity (owner 2026-11-23).
- Approved by the owner 2026-11-24 as-is after stalling at 6/10: Track 2 DemonCastle (round 8, 2455c6f). Frozen.
- In game (owner 2026-11-23): props placed from an approved draft keep the draft's clearance (24+ studs from the road
  centre line, overhead 14+, checked by tools/blender/world2/clearance.py). World 1's 8-stud road-edge clearance
  (BiomeDressing.CLEARANCE) does not prune them.
- Approved by the owner 2026-11-23 after rework: Track 5 KaijuBase (round 16, c96b876). Frozen.

## Cast in game (owner 2026-11-24, design doc 4.47; numbers **proposed**)
- Character files carry `World = 2` (absent = 1). `CharacterCatalog.All(world)` and `Rollable(world)` default to the place's
  world; `Everything()` is every world's. `GachaConfig.Roll`, `Odds` and `OddsPercents` take an optional `world`.
- `RaceConfig.Cruise(spec, multi, world)`: `CARRY_CRUISE` 0.1 for a spec with `World = 1` in World 2. No `World` (starter, starter
  picks): no carry. Kami's `AdminCruise` is never reduced.
- `NpcConfig.World2[n].Model` is the villain's own id. Until its model is uploaded the enemy is the plain rig and its
  portrait the live rig; a character with no upload is the same.
- Saves: nothing new. `Cars`, `Copies`, `Sidekicks` and `CharacterGear` are shared and keep every id; `Worlds.W2` as before.
- Sidekicks: `docs/SIDEKICK_SPEC.md` "World 2 set". Tests: `world2_cast`.

| Id | Name | Series | Rarity | Cat. | Chance (1 in N) |
|---|---|---|---|---|---|
| `punch_rider` | Mumon Rider | One Punch | Common | Marathoner | 1 |
| `dan_hex` | Jijo | Dandadun | Uncommon | Balanced | 12 |
| `kaiju_ice` | Rino | Kaijo No. 8 | Uncommon | Balanced | 25 |
| `fr_axe` | Stork | Frierin | Uncommon | Marathoner | 50 |
| `solo_vice` | Jinhu | Solo Levelup | Uncommon | Marathoner | 160 |
| `saw_nervous` | Kobene | Saw Man | Uncommon | Marathoner | 180 |
| `punch_cyborg` | Genus | One Punch | Rare | Sprinter | 550 |
| `dan_idol` | Airah | Dandadun | Rare | Balanced | 650 |
| `kaiju_axe` | Kikuru | Kaijo No. 8 | Rare | Sprinter | 1,600 |
| `fr_staff` | Ferne | Frierin | Rare | Balanced | 2,500 |
| `solo_mage` | Jongen | Solo Levelup | Rare | Balanced | 5,000 |
| `saw_fox` | Akki | Saw Man | Rare | Balanced | 6,000 |
| `punch_speed` | Speedo Sonik | One Punch | Epic | Sprinter | 60,000 |
| `dan_medium` | Seika | Dandadun | Epic | Balanced | 140,000 |
| `kaiju_blade` | Hoshena | Kaijo No. 8 | Epic | Sprinter | 350,000 |
| `fr_hero` | Himmal | Frierin | Epic | Balanced | 600,000 |
| `saw_blood` | Powah | Saw Man | Epic | Sprinter | 800,000 |
| `saw_katana` | Katanah Man | Saw Man | Epic | Sprinter | 1,100,000 |
| `dan_granny` | Turbo Grammy | Dandadun | Epic | Sprinter | 1,400,000 |
| `solo_blade` | Sha Hain | Solo Levelup | Epic | Sprinter | 1,800,000 |
| `punch_psychic` | Tatsumako | One Punch | Legendary | Balanced | 1.2e7 |
| `dan_psychic` | Momu | Dandadun | Legendary | Balanced | 3.5e7 |
| `kaiju_captain` | Mena Ashiru | Kaijo No. 8 | Legendary | Balanced | 6e7 |
| `fr_cut` | Ubbel | Frierin | Legendary | Sprinter | 1.2e8 |
| `fr_scales` | Ora | Frierin | Legendary | Marathoner | 1.8e8 |
| `kaiju_nine` | Kaijo No. 9 | Kaijo No. 8 | Legendary | Balanced | 2.5e8 |
| `saw_bomb` | Rezi | Saw Man | Legendary | Sprinter | 4e8 |
| `solo_beast` | Yunho | Solo Levelup | Legendary | Marathoner | 6e8 |
| `solo_flame` | Barran | Solo Levelup | Legendary | Balanced | 7e8 |
| `punch_fist` | Bange | One Punch | Mythic | Marathoner | 6e9 |
| `dan_turbo` | Okaron | Dandadun | Mythic | Sprinter | 2e10 |
| `kaiju_hero` | Kafko | Kaijo No. 8 | Mythic | Balanced | 8e10 |
| `fr_mage` | Frierin | Frierin | Mythic | Balanced | 2e11 |
| `solo_ant` | Berru | Solo Levelup | Mythic | Sprinter | 2e12 |
| `punch_serpent` | Orochy | One Punch | Mythic | Marathoner | 8e12 |
| `fr_gold` | Machto | Frierin | Mythic | Balanced | 2e13 |
| `saw_hero` | Denjy | Saw Man | Mythic | Balanced | 5e13 |
| `punch_monster` | Garoo | One Punch | Mythic | Sprinter | 2e14 |
| `solo_goliath` | Golioth | Solo Levelup | Mythic | Marathoner | 7e14 |
| `solo_monarch` | Jinwu | Solo Levelup | Eternal | Balanced | 6e18 |
| `saw_control` | Makina | Saw Man | Eternal | Marathoner | 7e18 |
| `fr_great` | Serye | Frierin | Eternal | Balanced | 8e18 |
| `punch_void` | Void Saitamo | One Punch | Eternal | Balanced | 9e18 |
