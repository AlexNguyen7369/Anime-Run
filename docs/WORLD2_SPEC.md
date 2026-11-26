# World 2: spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.47 (owner 2026-11-23), sections 3, 4.2, 4.8, 4.9, 4.13, 4.15 and 5.
Numbers are **proposed** unless the design doc fixes them. Plan of record:
`~/.claude/plans/scalable-meandering-pearl-of-3527e5c6-6209-4188-9740-d8306567b15b.md`.

## Place
- One source tree, two places. `default.project.json` builds World 1; `world2.project.json` is the same tree plus
  `ReplicatedStorage.WorldId` (IntValue 2). Keep the two files in step when the tree changes.
- `Shared/WorldConfig`: `Id`, `PLACES` (World 1 = 102957063656302; World 2 = 79352569024576, in
  universe 10773557968), `GATE_OPEN = false`, `PROGRESS_KEYS`.
- `Shared/TrackRegistry` loads `Shared/Tracks/World2/` in World 2.

## Track lighting
- Seen in Studio 2026-11-25 (World 2 place, merged code 1a3e5795 plus docs, pictures in
  `assets/world2_draft/audit/lighting_2026-11-25`): all ten tracks' live Lighting values meet the floors below (T8
  OutdoorAmbient read 0.6176 mid-blend); roads and rails read on Tracks 6 to 10 and 1, 4, 8; a placed runner reads on
  night Tracks 1, 4 and 8, and on 4 and 8 in an iPhone 17 Pro emulation. Not seen: real phones, a real run, Tracks 2, 3 and
  5 in pictures, high or low quality settings. Flaws found (docs/BUGS.md): grass through the road on Tracks 6
  and 7 (fixed in code and checked offline, not seen in Studio); near-black scenery props on 1, 4, 6, 7, 8 and 10 (the
  grey tint is fixed in code, previewed in Studio on live meshes only, the code itself not seen there; the export colours
  need the re-export and uploads, not done).
- Owner 2026-11-24: "fix lighting in tracks" (World 2 stays off main until it is fixed; the road-and-runner rule below is
  met as seen above, owner 2026-11-25 "approved all continue the merge"). Seen in Studio before the fix:
  Track 1, 4 and 8 were close to black (Ambient under 30 of 255, Track 8's OutdoorAmbient 15), and Track 2's
  OutdoorAmbient was taken from the draft's below-horizon stop (32, 23, 35) instead of its orange skyline.
- Rule: a track's lighting keeps the hue of its approved draft sky, but the road and the runner must read on every
  track. `Kit.fromDraft` builds each profile from the draft's sky stops and sun with floors (`Kit` `LIGHT_FLOOR`, all
  **proposed**): night tracks (draft sun energy under 2: Tracks 4, 6, 8) get a moon of Brightness at least 2, Ambient
  at least 0.5, OutdoorAmbient at least 0.62 (largest colour channel, 0-1; a lifted colour is also mixed 35% toward grey), ExposureCompensation 1.1, fog Density at
  most 0.22 and no Haze; the others Brightness at least 1.4, Ambient at least 0.36, OutdoorAmbient at least 0.6. Fog
  colours are lifted to 0.3 so the distance never fades to black. The horizon colour is the first sky stop at or over 0.
- A theme's own `Atmosphere` overrides still win (Track 4's moon size).
- Track skies: **open question for the owner** (docs/BUGS.md w2-hell-sky, found 2026-11-25 by reading code). The approved
  drafts' skies (`<Key>Draft.Sky.Stops`) are rendered in Blender only. In game no World 2 profile sets
  `Sky.Skybox` (BIOME_ENVIRONMENT_SPEC 5.2) and no theme has a Skybox row, so the place's default Roblox sky shows on every
  track: blue by day. Only the fog colour (`Atmosphere.Color`, the horizon stop) carries the draft hue. The look was never
  defined, so nothing is coded. By reading, the profile is applied in zone 10 (`BiomeEnvironment.Profile` gives
  HellGate's `Atmosphere`; no override found).
  The pale ground is the draft's (`Ground` B8AA8C, Sand: "a pale plain under a red sky"), not a fault.
  **Proposed**: one in-house gradient skybox per World 2 day track whose draft sky is not a plain daylight blue, drawn
  as the plaza's (`tools/blender/plaza/plaza_sky.py`, Lane A, no prompt): a vertical gradient by true elevation from the
  draft's stops (stop value x 90 degrees; below 0 the first stop), one Side image on Bk/Ft/Lf/Rt plus Up and Dn, row key
  `W2_<Key>_Sky` in the theme's Assets, set as the theme's `Atmosphere.Sky.Skybox`; `CelestialBodiesShown` stays on.
  Tracks it would cover: 10 HellGate (FF8A4A at the horizon to 3A0208 overhead) first, then 3 DemonCastle, 9 GoldenCity
  and 7 AntIsland (warm skies). The blue-sky day tracks (ElvenPlains, KaijuBase, RuinedCityZ) and the night tracks
  (DevilTokyo, HauntedTunnel, MonsterDen: ClockTime 0, Roblox's night sky) would keep the default. Needs: the owner's word
  on the look (and which tracks), an upload and a rules review of each image; Track 10's layout and meshes stay frozen
  (a skybox touches neither).

## Save
- `Shared/WorldConfig.Id` comes from `ReplicatedStorage.WorldId` (the World 2 place only); a client waits for `game.Loaded`
  before reading it, since ReplicatedFirst may require the module first (docs/BUGS.md w2-worldid-race).
- One save per player (`PlayerStats_v2`, VERSION unchanged at 19 so live World 1 servers never go read-only).
- `Shared/WorldSave.View` swaps `BestTrack`, `Checkpoint`, `RaceBestTimes`, `Team` and `Equipped` (`WorldConfig.PROGRESS_KEYS`)
  for the world's own on load. First entry (owner 2026-11-24, design doc 4.47): while `Worlds.W2` holds no team, or only
  the placeholder starter, `View` gives World 1's `Team` and `Equipped`, so the team carries over; the first World 2 save
  writes it to `Worlds.W2`. `GachaService.CheckStarter` does nothing in World 2 (no starter choice, auto-roll not turned
  off for the roll tutorial) and `Client/ArrivalState.IsNew` is false there;
  `WorldSave.Fold` writes them to `Worlds.W2` and never touches World 1's top-level keys. An arrival not (yet) allowed to
  stay (Travel and gate: arrival check refused it, or its admin check is unknown and waits for a recheck) keeps
  `Worlds.W2.Team` and `Worlds.W2.Equipped` as stored (even if the player put another character first: an Equipped
  alone would give a later first entry a one-member team), so a later real first entry still takes World 1's whole team
  of that day (docs/BUGS.md w2-sendback-stale-team). Every other key, per world and
  shared, is written together as before (`Fold` `keep`, while the player's runtime attribute `SendingBack` is on; not
  saved). Once it may stay the attribute is cleared and it saves as before.
- `Worlds.W2.Welcomed` (true once World 2's welcome was given; absent = not yet): a one-way flag
  (`WorldSave.FLAG_KEYS`), never cleared by a save without it. VERSION unchanged: an older save has none and is
  welcomed once; World 1 servers (old and new) keep `Worlds` whole as they keep every unknown key. `Fold` keeps the
  keys of `Worlds.W2` it does not know. An older World 2 build would drop the flag (welcome shown again, nothing else lost).

## Travel and gate
### Travel
- `Server/WorldTravel.Go(player, id)`: saves with the lock released, then `TeleportService:TeleportAsync`. Refused in
  Studio (teleports do not run there) and while the target place id is missing. One trip at a time; the player is
  frozen (`DataLoaded` off, `Travelling` on) from the release save until departure; a failure restores and retakes the
  lock (only while the player is still in the server).
- Admin: `/world2 [player]`, `/world1 [player]`.
- Who may enter (design doc 4.47): `WorldTravel.CanEnter(player, id)`, used by the gate, `Go` and the arrival check.
  World 1 and admins always; anyone else needs `WorldConfig.GATE_OPEN` (false until the owner opens it) AND World 1
  Track `GATE_TRACK` (10) beaten AND rebirth >= `GATE_REBIRTH` (5). No Money cost, nothing resets. In World 2 the
  World 1 best track is `PlayerData`'s read-only `World1BestTrack` attribute (the save's top-level `BestTrack`).
- Arrival check (World 2, not in Studio): waits until the save loaded or failed (up to `ARRIVAL_WAIT`, past
  `PlayerData.LOCK_WAIT`; still undecided: kicked). A player `CanEnter` refuses is sent back to World 1, frozen, up to
  `ARRIVAL_TRIES` trips with `CanEnter` asked again before each (a player who now qualifies stays); then one bounded
  release save and a kick. If every release save failed, the kick leaves the session lock until `LOCK_TIMEOUT`
  (120 s): the next join waits for it. An admin check that fails ("unknown") is asked again up to `ADMIN_RECHECKS`
  times, then the player counts as no admin.
- Group rank lookups (`AdminService`, docs/BUGS.md admin-ranklookup-yield): a lookup that failed every try holds for
  `RANK_RETRY_AFTER` (placeholder 5 s, kept below `ADMIN_RECHECK` so each recheck asks again); checks in that time
  answer "unknown" at once. Checks at the same time share one lookup and wait for it at most `RANK_LOOK_TIMEOUT`
  (placeholder 10 s), then answer "unknown". Unknown is never an admin.
### Gate
- `SpawnArea.WorldGate`, hub-local (194, -176) on the plaza's south-east corner, facing the spawn: draft B, the
  shrine gatehouse (owner 2026-11-25; `docs/WORLD_REDESIGN_SPEC.md` 4.2 has its look, label and touch box). In World 1 it is locked:
  its locked mesh (barred doors, chain, padlock), an invisible barrier, "WORLD 2 / COMING SOON"; touching the barrier shows "COMING
  SOON". Open but not qualified: "Beat Track 10" / "Reach Rebirth 5" (TeamToast, `RunEvent { Kind = "WorldGate" }`).
  In World 2 it is open ("WORLD 1 / ENTER") and its Portal (tag `WorldGate`, attribute `TargetWorld`) sends a touching
  player back.

## World HUD and welcome (proposed, design doc 4.47)
### World HUD
- HUD look (owner 2026-11-24, design doc 4.46 "HUD look" and 4.47): World 2's HUD is World 1's, and both keep the
  always-on HUD's look from before the Scroll Dojo redesign (4.40, main at `6a36029^1`); every panel, popup and the
  boss event UI keep the 4.46 look. No switch (`Client/HudPlaque` is removed, main PR #29). Positions
  and behaviour are unchanged. World 2 differs only by the fourth team slot.
- World label: `Client/WorldHud` shows "World N" (`WorldConfig.Id`) under the top-right pills, as wide as and
  right-aligned with HudChrome's right column, in the gap above it (phones: the HUD's UIScales): the old top-right
  pills' dark round pill with white outlined text, in both worlds. Display only; shown in both worlds.
- Travel: while the server holds a trip (player attribute `Travelling`, `WorldTravel.Go`, gate or admin command alike),
  TeamToast shows "Travelling to World N..."; a failed trip shows TeamToast's "TRAVEL FAILED, TRY AGAIN". The locked
  gate looks unchanged.
### Welcome
- `Server/WorldWelcome` sets `World2Welcomed` (saved, above) and `World2WelcomeShow` (session) the first time a
  loaded player stays in World 2 (`CanEnter`; not an arrival that is sent back; Studio playtests always). `Client/World2Welcome`
  (World 2 only) shows one small handscroll popup (4.46): "WORLD 2", "Welcome to the Rift Shrine", "Team of 4 unlocked",
  "New summon pool", "The World 1 gate in the plaza takes you back"; Close, OK or a click outside closes it; reduced
  effects fade. Words **proposed**.
- Tests: ServerTest `world2_welcome`; UiTest `ui_world_label`, `ui_world2_welcome`, `ui_hud_look_by_world`
  (`Client/UiTest/UiWorld2`).

## Tracks
Routes follow "World 2 track layout" below (owner 2026-11-26: a square spiral of long straights, target lengths unchanged); `Shared/Tracks/World2/W2*.luau`, briefs in `ServerTest/TrackTests/World2`.

| Track | Id | Biome key | Series | Biome (working name) | Enemy (based on) |
|---|---|---|---|---|---|
| 1 | W2ElvenPlains | ElvenPlains | Frieren | Elven Ruin Plains | Ora (Aura the Guillotine) |
| 2 | W2DemonCastle | DemonCastle | Solo Levelup | Demon King's Castle | Barran (Baran) |
| 3 | W2RuinedCityZ | RuinedCityZ | One Punch | Ruined City Zed | Garoo (Garou) |
| 4 | W2HauntedTunnel | HauntedTunnel | Dandadan | Haunted Tunnel Road | Turbo Grammy (Turbo Granny) |
| 5 | W2KaijuBase | KaijuBase | Kaiju No. 8 | Wrecked Kaiju Base | Kaijo No. 9 (Kaiju No. 9) |
| 6 | W2DevilTokyo | DevilTokyo | Saw Man | Devil Hunter City | Katanah Man (Katana Man) |
| 7 | W2AntIsland | AntIsland | Solo Levelup | Ant Island | Berru (Beru) |
| 8 | W2MonsterDen | MonsterDen | One Punch | Monster Den | Orochy (Orochi) |
| 9 | W2GoldenCity | GoldenCity | Frieren | Golden City | Makto (Macht) |
| 10 | W2HellGate | HellGate | Saw Man | Hell's Gate | Makina (Makima) |

The "Based on" names stay in docs and never ship (design doc 5).

Track swap (owner 2026-11-25; layouts approved, round 7, owner 2026-11-25; nothing uploaded): Tracks 1 and 6 exchanged biomes. Moves with the biome: track id, name, palette, scenery,
lighting, card blurb, enemy name and model. Stays with the number: road segments and length, pay, Gems, `BestTrack` /
`Checkpoint` / `RaceBestTimes`, enemy speed (Track 6: 190). Approvals and hero moves below that name Track 1 or 6 were
written before the swap.

### Rewards (design doc 4.47, owner 2026-11-24; written 2026-11-24)
- Money: every Money amount a track pays (the finish, the exhaustion share by distance, the checkpoint bonus) is a
  multiple of its winnings pad's `Cash`, as in World 1. In World 2 the pad's `Cash` is
  `World 1 Track 10's Cash x WORLD2_STEP^N` = `31,640,625,000 x 2^N` for Track N (`PayoutCurve.TrackCash(n, 2)`,
  `TrackBuilder.CashFor`). `WORLD2_STEP = 2` is a **placeholder**. World 1's `Cash` is unchanged (`PayoutCurve.Cash`).
  The Money multi, checkpoint bonus and exhaustion share apply on top exactly as in World 1.
- Reading chosen (**proposed**, 2026-11-24, coordinator's choice pending the owner): Track 1 is x2 (so it already pays more than World 1 Track 10), each step x2 more. The other reading,
  continuing World 1's own curve (x10 / x7.5 per track, Track N = World 1 "Track 10 + N"), is not the owner's x2 and
  is not used.

| Track | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Cash | 63,281,250,000 | 126,562,500,000 | 253,125,000,000 | 506,250,000,000 | 1,012,500,000,000 |
| Track | 6 | 7 | 8 | 9 | 10 |
| Cash | 2,025,000,000,000 | 4,050,000,000,000 | 8,100,000,000,000 | 16,200,000,000,000 | 32,400,000,000,000 |

- Limits: all are whole numbers below 2^53 (exact in a double) and far under the Money cap (1e30, `MoneyService`,
  `PlayerData`); the HUD shows them as "$63.3b" to "$32.4t" (`HudFormat`).
- First-clear Gems: `GemConfig.FirstClear(n)` is paid when a win raises `BestTrack`, and `BestTrack` is per world
  (`WorldSave`), so each World 2 track pays it once again. A World 2 first clear never changes World 1's `BestTrack`
  or Gems rule, and the reverse. Track-win Gems (`GemConfig.TrackWin(n)`) are unchanged.
- Nothing is paid while `Travelling` (`MoneyService`).
- Tests: ServerTest `world2_rewards` (both worlds).

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
- Approved by the owner 2026-11-24: Track 9 GoldenCity, frozen at round 4 (4d994ed; owner: "earlier version is
  fine"). The unfinished corrected round is kept in git stash, not applied. All 10 tracks are approved.
- Approved by the owner 2026-11-24 as-is after stalling at 6/10: Track 2 DemonCastle (round 8, 2455c6f). Frozen.
- In game (owner 2026-11-23): props placed from an approved draft keep the draft's clearance (24+ studs from the road
  centre line, overhead 14+, checked by tools/blender/world2/clearance.py). World 1's 8-stud road-edge clearance
  (BiomeDressing.CLEARANCE) does not prune them.
- In game (owner pre-approved 2026-11-24; replaces "still pruned against other tracks" for draft props): a draft
  prop is tested offline, at export, against EVERY track's road with its real triangles (24+ studs lateral, 14+
  overhead, final game transform, mirroring and size limit included); a placement that intrudes is dropped from the
  export. The game then does not box-prune `Placed_*` props against other tracks' roads (one box per mesh removed whole
  heroes). The plaza, checkpoint and WinPad pruning stay. This is the World 2 exception to BIOME_ENVIRONMENT_SPEC
  "props are pruned against every built road".
- A mesh larger than 2048 studs on an axis at its placed scale is exported as several pieces under that size (same
  shape, same look), each its own asset.
- Approved by the owner 2026-11-23 after rework: Track 5 KaijuBase (round 16, c96b876). Frozen.
- Reopened by the owner 2026-11-25: (a) the scenery layouts of DevilTokyo and ElvenPlains, for the track swap only (hero
  meshes unchanged; re-export of these two lifted from the hold, `--no-glb`; new renders need the owner's approval);
  (b) Track 5's dead kaiju (`GiantCorpse`) and its site (ground, crushed buildings, rubble and crew around it), sized to
  fit a legal spot, earlier form rulings dropped; reference renders need the owner's approval before export, upload or
  placement. The rest of Track 5 stays frozen. Every other track stays on the re-export hold.
- Owner 2026-11-25 on the dead kaiju's first draft: shape, size (about 311 x 150 studs, 116 tall) and colour are good and
  stay; fix the lead's four faults (crushed walls look like flat cutouts, visible ground edge around the body, soft feet
  and claws and an eye that barely reads, bare road-side bank) in review rounds against the references. This is not the
  approval of the reference renders.
- Approved by the owner 2026-11-25: Track 5's dead kaiju, round 5 (1bc5e9f7), frozen; its added surroundings are cut to
  the props that overlap no other track's scenery ("approve round 5, cut to the clear props"). Export, ledger, upload
  and placement in game still need the Track 5 re-export hold lifted and the owner's upload word.
- Owner 2026-11-25, on the Track 5 fill over the merged swap: "A with 12". Draft A (round 5 fill props the swap freed come
  back) without Apartments (-471.8, 875.3) and (-613.6, 876.6): 12 props. The option was described as needing no van to move;
  no van is moved. **Open**: the vans' own spots, and the kaiju's overlaps with other tracks' props (shown, not ruled on).
- Owner 2026-11-25, question 32 (the kaiju's game export): "drop two vans, keep the rubble under the fill, ok". The two game
  SweeperVans that touch the kaiju at site 1 (Draft rows 226 and 228) are dropped; the frozen Rubble under the 12 fill props
  stays; the 4 Rubble rows standing inside the bodies go (read as covered by "ok"). The other five vans stay where they are.
- Owner 2026-11-25: "Kaiju ready to upload". The reworked GiantCorpse (round 5 mesh) is uploaded (Model 130671695538312, MeshId
  rbxassetid://120871855895739, geometry hash 7f2f942a...1c651137, 19,889 tris) and reviewed by the rules audit (BIOME_ENVIRONMENT_SPEC
  4.1 step 3). Its ledger row, `uploaded_assets.tsv` and KaijuBaseDraft (size, parts fallback in the hide colour, the 2 placements, the
  12 fill rows of "A with 12", the drops of question 32) change together in one commit, so the old mesh never stands in the new box.
  With its placements it leaves the "No spot at the approved scale" list below. Not covered by these words: the kaiju's overlaps with
  other tracks' props (still **Open**), the vans' own spots, Studio checks, place saves and publishing.
- Spawn pieces (owner 2026-11-25, WORLD_REDESIGN_SPEC 4.2): gate, boss gate, stalls and merchants are World 1's; the Summon altar is draft A here and draft B in World 1.
- Ground ownership (owner 2026-11-25, the overlap question): where two tracks' scenery meets, a spot belongs to the track
  whose road (nearest centre line) is nearest; other tracks' props there are moved or removed. Before any frozen track
  changes, a full count (props and heroes per track) goes to the owner; the freezes and the re-export hold stand until
  then. By base centre (owner 2026-11-25, "yes to all"). The Devil Hunter HQ has no
  legal spot and is left out for now (owner, same words). **Open question**: the plaza's ground; the other heroes with no spot.
- Track 6 lit landmark (owner 2026-11-25, "lit landmarj approved"; renders went to the owner, who approved the merge (choice E, 2026-11-26)): at the bend
  (0.06 run camera) and the finish (0.9), from meshes the track already places, unchanged, on its own ground by base
  centre, touching no other track's prop: a Mansion with its lit balcony face to the bend's axis in place of one Apaato,
  and one more Office tower (scale 0.55, the approved top) with its lit face to the finish axis. The spots are
  **proposed** (`tools/blender/world2/cross_track.py` LANDMARK); the HQ stays out.
- World 2 track layout (owner 2026-11-26, verbatim: "biomes/tracks on world 2 are much too close to each other where racing on one track is not immersive. Spacing per track in terms of wdith should be much larger , can have the track be straight even, not just circular. There should little to no overlaps in other tracks"; asked directly, the owner picked a spacing of "About 600
  studs" road edge to road edge between any two World 2 tracks): the chain is a square spiral of long straights
  (docs/proposals/W2_WIDE_LAYOUT.md option C, picked by the lead under the owner's nightly pre-approval 2026-11-26).
  The hard floor, a smallest road-edge gap of at least 600 between any two World 2 tracks, is the lead's reading of
  the owner's "About 600" under that pre-approval; the 1,200-stud skip of pairs through a shared joint is **proposed**.
  **Proposed**: pitch 760, corner radius 420, first side 1,000 (so every cut between tracks falls in a straight and
  every finish straight runs on the 90-degree grid). Track lengths, the chain rule, the first/last straights and the
  NPC table are unchanged. (Replaces the 2026-11-24 coordinator's choice "World 2 keeps World 1's track spacing".)
- Re-fit of Tracks 6 and 7 to the wide layout (2026-11-26, lead's decisions under the owner's nightly pre-approval,
  **proposed**): Track 6's back row of buildings keeps one in 7 free slots (`BACK_EVERY`; nothing blocks it on the wide
  layout, which would double the approved building count), and Track 6's HQ stays out per the owner's 2026-11-25 ruling
  although it now has a legal spot on its own ground (0.9 axis, world -2714, 2418), for the owner to bring back.
  Track 7's island runs along the road (coast 260 studs out on both sides, the 48 ships at 312, inside its Ground
  rect) instead of an oval round the whole track; its nest is turned to face its road so its ants stand on its own
  ground, a change from the approved random turn, for the owner. IslandVolcano keeps its approved scale 1.25 and has
  no spot (it needs 975+ studs from every road).
- Track 7's sea (2026-11-26, the owner's "fix rendering on all tracks", lead's decision, **proposed**): terrain Water from
  280 studs off Track 7's road out to its own ground's edge (the coast and the ships' band), level -3, so the 48 blockade
  ships float as in the approved draft instead of standing on grass. World 2 AntIsland only; road corridor, walls,
  checkpoints and the grass-strip rule unchanged (BIOME_ENVIRONMENT_SPEC 2.2 "Coast"). Its water colour is the approved
  draft's sea, 1C4260 (transparency 0.3, reflectance 0.25, waves 0.15 / 8; proposed), set per zone on the client.
- Hero moves (2026-11-24; positions are re-fitted to the new layout (agent-3 round)): a hero landmark with no placement that passes every game rule moves whole (all its pieces, its
  approved scale and turn) to the nearest spot on its own track's ground that clears its own and every other track's
  corridor, the spawn area and every checkpoint and win pad; the biome drafts stay as approved and the move lives in
  tools/blender/world2/hero_moves.json (track-local studs, base centre x, z). Moves: Track 4 Hospital (1377, 609) to (1589, 821), 300; Track 5 Railgun (1865, -307) to
  (-362, -1230), 2410; Track 7 Nest (-486, 1809) to (-486, 2059), 250; Track 8 Coliseum (2707, 132) to (3167, 132),
  460; Track 8 LairTower (-680, 1795) to (3294, -2179), 5620; Track 10 DarkGate (3485, 3478) to (3402, 3512), 90.
  No spot at the approved scale (not built): Track 1 Town and RuinedCastle, Track 2 ChainTower, Track 3 HeroHQ and Crater, Track 4
  School and OldWoodHouse, Track 5 DefenseHQ, Track 6 HQ, Track 7 IslandVolcano.

## Cast in game (owner 2026-11-24; names, ids and the rules of design doc 4.47 approved; Chance values other than the Eternal cap **proposed**)
- Character files carry `World = 2` (absent = 1). `CharacterCatalog.All(world)` and `Rollable(world)` default to the place's
  world; `Everything()` is every world's. `GachaConfig.Roll`, `Odds` and `OddsPercents` take an optional `world`.
- `RaceConfig.Cruise(spec, multi, world)`: `CARRY_CRUISE` 0.1 for a spec with `World = 1` in World 2. No `World` (starter, starter
  picks): no carry. Kami's `AdminCruise` is never reduced.
- `NpcConfig.World2[n].Model` is the villain's own id. Until its model is uploaded the enemy is the plain rig and its
  portrait the live rig; a character with no upload is the same.
- Saves: nothing new. `Cars`, `Copies`, `Sidekicks` and `CharacterGear` are shared and keep every id; `Worlds.W2` as before.
- Sidekicks: `docs/SIDEKICK_SPEC.md` "World 2 set". Tests: `world2_cast`.
- Daily Day 7: `DailyLoginConfig.MAX_GUARANTEED_RARITY[2]` = Legendary; World 1 has no cap.

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
| `fr_gold` | Makto | Frierin | Mythic | Balanced | 2e13 |
| `saw_hero` | Denjy | Saw Man | Mythic | Balanced | 5e13 |
| `punch_monster` | Garoo | One Punch | Mythic | Sprinter | 2e14 |
| `solo_goliath` | Golioth | Solo Levelup | Mythic | Marathoner | 7e14 |
| `solo_monarch` | Jinwu | Solo Levelup | Eternal | Balanced | 6e18 |
| `saw_control` | Makina | Saw Man | Eternal | Marathoner | 7e18 |
| `fr_great` | Serye | Frierin | Eternal | Balanced | 8e18 |
| `punch_void` | Void Saitamo | One Punch | Eternal | Balanced | 9e18 |

### Release checklist (cast)
- Publish World 1 from this build before or with World 2, then shut down old servers: an older World 1 server trims StatAlloc earned from World 2 ids and drops World 2 characters from the team.
- Ids are final (owner 2026-11-24).
- Random:NextNumber resolution measured in Studio against the rarest odds (OWNER_QUESTIONS item 9).
- Studio run of the cast scenarios.

### Awakening
Design doc 4.47 (owner 2026-11-24): World 2 only; duplicate Copies buy up to 5 stars per character; each star gives
+3% cruise and +3% stamina (+15% of each at 5 stars); star costs 1, 2, 4, 8, 16 Copies are **placeholders**
(`Shared/AwakeningConfig`). The points below are **proposed** (2026-11-24, coordinator's choice pending the owner):
- World 1 has no Awakening: no stars are applied, shown or bought there. A World 1 server keeps `Worlds.W2` whole, so
  stars bought in World 2 are never lost.
- Any owned character with Copies can awaken in World 2, World 1 characters carried there too (its stars scale its
  World 2 cruise, after which the x0.1 carry still applies). The starter, Kami and the exclusive runner have no Copies
  and so cannot awaken.
- A star spends that character's own Copies (the duplicates; the owned copy always stays). Spent Copies are gone, free
  their bag spaces and are never refunded; stars never go down.
- Effect: the stars' multi `1 + 0.03 x stars` joins the character's speed multi (with its Sidekick and Relic) before
  the `MAX_CRUISE` cap, and multiplies its stamina seconds (with its Sidekick and Relic). Boss events in World 2 use the
  same numbers.
- Server: `Remotes.Awaken(id)` (RemoteFunction, `GachaService.Awaken`): refused before the save loaded, while
  `Travelling`, in World 1, for a character not owned, at 5 stars and without enough Copies; otherwise Copies minus the
  cost and stars plus 1 in one step. Rate limited like `SellSpares`. `Remotes.AwakenPreview(id)` (read-only, display only, rate limited) answers
  whether the next star still raises the character's capped cruise and whether its stars give any cruise now (its own
  team slot's aura and trail count). The stars are the `Stars` attribute of the
  character's `GachaData` entry (display only on the client).
- Save: `Worlds.W2.Awakening = { [characterId] = stars }` (`WorldSave` per-world key; VERSION unchanged at 19). A save
  without it loads as 0 stars.
- Client: the Backpack's Characters tab (World 2 only) shows an Awaken bar for the chosen character above the footer:
  its stars, the next star's cost, the Copies owned and the +% it gives (cruise only when the server says it
  counts, "cruise at max" when the cap takes it, stamina only while there is no answer; answers are asked again each
  time the Backpack opens, a refused one at the next refresh); it is greyed with the reason (5 stars, not
  enough Copies) when it cannot be bought; a tap asks to confirm. Hidden in World 1.
- Tests: ServerTest `awakening` (both worlds).

### Release notes
- Awakening (2026-11-24): shut down every older World 2 server when Awakening ships. An older World 2 build rebuilds
  `Worlds.W2` without `Awakening`, so the stars would be lost while the Copies spent on them stay spent (Copies are
  shared). From 2895923 on, `WorldSave.Fold` keeps every `Worlds.W2` key it does not know, in World 2 as in World 1
  (test `awakening`, `unknown_keys`).
- Team of 4 (2026-11-24): an older World 2 build caps the Team at 3 and rebuilds `Worlds.W2`, so it would drop slot 4
  and the `Welcomed` flag. Shut down every older World 2 server when this ships, and publish World 1 first or together
  with World 2 (test `world2_team`).
