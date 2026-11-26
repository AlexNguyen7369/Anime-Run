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
- Track skies. Owner 2026-11-25 (owner question 33, design doc change log): "Four tracks": Hell's Gate first, then Demon
  Castle, Golden City and Ant Island get in-house gradient skies made from their approved drafts' sky colours; the other
  tracks keep the default sky; renders to the owner before upload. (Found as docs/BUGS.md w2-hell-sky: no World 2
  profile had a `Sky.Skybox`, so the place's default blue sky showed on every track; the pale Track 10 ground is the
  draft's `Ground` B8AA8C, Sand, not a fault.) Tracks: 10 HellGate, 2 DemonCastle (agent-1's proposal said 3), 9
  GoldenCity, 7 AntIsland. ElvenPlains, KaijuBase, RuinedCityZ, DevilTokyo, HauntedTunnel and MonsterDen keep the default.
  Everything below is **proposed**:
  - Drawing (`tools/blender/world2/track_sky.py`, offline, no network, deterministic, `--self-test`): a plain vertical
    gradient by true elevation, read from the draft's `<Key>Draft.Sky` (stops and Strength) and drawn exactly as the
    draft's Blender world: a stop at p sits at elevation asin(p) (the draft ramp runs on the view direction's height; the
    first proposal's p x 90 degrees was not the draft's look), linear-light mixing, times Strength, sRGB (Standard),
    clipped at 1; below the first stop that stop's colour. No text, symbols, logos or shapes; the sun disc is the
    engine's (`CelestialBodiesShown` stays on). 512 px, one Side image on Bk, Ft, Lf and Rt plus Up and Dn (three
    uploads per track), as the plaza's SkyGolden. Files: `assets/world2_draft/skies/trackNN_<Key>/W2_<Key>_Sky*.png`,
    `manifest.json` (stops, sha256). Checked against a Cycles panorama of each draft's own world
    (`track_sky_preview.py`): mean difference under 1 level of 255 (Demon Castle's horizon row up to 120 where its
    stops jump within one pixel row).
  - Previews for the owner (`track_sky_preview.py`, Blender, offline): `preview.png` per track, the Studio picture of
    2026-11-25 (`assets/world2_draft/audit/lighting_2026-11-25/T<N>_road.jpg`) beside the same picture with its blue sky
    pixels replaced by the new sky (approximate: no haze or fog redone), the draft's run render and the panorama. Track 2
    has no Studio picture: a level view over flat draft-coloured ground instead.
  - Game: `Kit.fromDraft` takes the theme's `Skybox = "W2_<Key>_Sky"` as the profile's `Sky.Skybox`; the row is
    `Kit.draftSky` (Kind Skybox, Lane A as the plaza's, Faces form, `TrackSky = true`): Id and Bk, Ft, Lf, Rt = the
    Side image, plus Up and Dn. `BiomeEnvironment.Row` never uses a row with any id 0 (the whole set or nothing), an
    unreviewed row, nor a `TrackSky` row while `Shared/TrackSkyConfig.LIVE` is false; then every track shows the
    place's default sky. With the switch on, a track's six faces apply in its zone only (`BiomeEnvironment.SkyboxFace`;
    the client writes the place's own faces back on leaving), swapped under the blend's haze (BIOME_ENVIRONMENT_SPEC
    5.3), and its profile takes the WithSky rule below (fog Color and Decay from the drawn sky on all four tracks; Ant
    Island's light too); without its sky a track's fog and lighting are `Kit.fromDraft`'s, floors included.
    Tests: `world2_skies` (both worlds). Track 10's layout and meshes stay frozen (a skybox touches neither).
  - Upload and switch-on (owner 2026-11-26, choice F, design doc change log: "the four track skies (Hell's Gate,
    Golden City, Ant Island, Demon Castle) are uploaded, then each is reviewed and checked in Studio before it is switched
    on"): (1) the twelve images (three per track) are uploaded under the owner's account (done 2026-11-26); (2) the rules
    auditor reviews each image and signs its row's `Reviewed` (done 2026-11-26, all twelve faces); (3) the ids go into
    the four `draftSky` rows; (4) each sky is checked in Studio (its six faces in its zone only, the default sky back on
    leaving, the fog meeting the sky, Ant Island's light) before `TrackSkyConfig.LIVE` is switched on in the World 2
    branch; the switch-on is its own commit so it can be checked in Studio before it is merged. (4) was done 2026-11-26 (`world2_skies` 81/81). Merge gate (owner 2026-11-26, design doc change log: "pictures again before the merge"): new Studio pictures of the four tracks at the toned-down haze go to the owner before this switch-on merges into the World 2 branch.
  - Review round 2026-11-26 (agent-3, images only: Golden City 8, Hell's Gate 7, Demon Castle 7, Ant Island 6):
    - Horizon seam: while a track's own sky shows, its profile takes `WithSky` (`Kit.fromDraft`, applied by
      `BiomeEnvironment.Profile` only then): fog `Atmosphere.Color` = the drawn sky at the horizon and `Decay` = the
      drawn sky 2 degrees up (`SKY_DECAY_HEIGHT` 0.035), so the haze meets the sky in its own colours. Owner 2026-11-26,
      after the Studio pictures: "reccommended option, just tone down the haze across all a bit, colors are fine just too
      much": while the sky shows, Density 0.22 (was 0.3) and Haze 0.5 (was 1) on all four (`Kit` `SKY_FOG`, values
      proposed); Glare and the colours unchanged. Off, or with an id 0, the theme's own profile is returned as today. The pale blue-grey line in the first
      previews was the default sky's pale band left in the Studio picture by the picture edit; the redone previews
      replace it and recolour Track 10's fog band by the fog change.
    - Demon Castle: its dark stop under the horizon moves from -0.012 to -0.035 in the drawing only
      (`track_sky.py SOFTEN`), so the orange horizon meets the dark below in about 10 px of a 512 px face instead of a
      1-2 px line; nothing at or over the horizon changes. No Studio picture of Track 2 exists in the repo (searched
      `assets/`: only World 1's Forest T2 and Track 2 model close-ups), so its board keeps the level game view.
    - Ant Island: `assets/world2_draft/audit/lighting_2026-11-25/T7_road.jpg` is filed as Track 7, but its scenery is
      not Ant Island's: the orange blocks match Golden City's CityBlock and the timber houses and pines are not in Ant
      Island's draft (its props near the road are Brush, Bank, ThatchHouse, Ruin). By the draft placements, 79 Golden
      City CityBlocks and 153 Haunted Tunnel cedars stand within 150 studs of Track 7's centre line, so the picture is
      most likely Track 7's road with neighbouring tracks' scenery (the ground-ownership question); not confirmed in
      Studio. Under its sky Ant Island takes `SkyLook`: ClockTime 17.6 (was 17.2), Brightness 1.4 (the day floor, was
      1.44), ExposureCompensation -0.3 (was 0), OutdoorAmbient A37D6D (halfway from the draft's horizon D8946A to its
      sky 6E6670, was 997966), Grade Saturation -0.1 (was 0.18) and TintColor 30% toward the sun FFB070 (was 15%). The
      road-and-runner floors still hold (tested). `studio_sky_dusk.png` previews it as a picture regrade (no new
      shadows).

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
- Team of 3 migration (owner 2026-11-26, design doc 4.47 "Team of 3 in World 2"): the World 2 Team has 3 slots
  (`StaminaConfig.TEAM_SIZE` = 3 in both places). A stored `Worlds.W2.Team` of 4 (written by the team-of-4 build,
  2026-11-24 to 2026-11-26) is not rewritten by any migration step and nothing is renamed or reused:
  - On load `GachaService.Apply` keeps the first 3 ids of the stored Team, in order, that are still owned and distinct
    (the rule every save past the size already had); the others are only off the Team. A 4th member stays owned: its
    `Cars` entry, Copies, Awakening stars, worn Sidekick and Relics belong to the character, not the slot, so it is in the
    Bag and the Team roster and can be put back on the Team. `EquippedCharacter` is the kept Team's slot 1, which the
    trim never changes.
  - The next World 2 save writes those 3 to `Worlds.W2.Team` and `Equipped` = `Team[1]` (`Fold`), so Team and Equipped
    stay consistent. A `keep` save (being sent back) leaves `Worlds.W2.Team` and `Equipped` as stored, as above; the next
    load trims again. World 1's top-level Team is never touched.
  - The shared `LastBossTeam` (the boss event's last team) of 4 ids loads as its first 3 that can still fight
    (`BossEventService`), as before for any longer list.
  - VERSION unchanged (19). Tests: `world2_team` (both worlds).
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
  and behaviour are unchanged. Nothing differs in look between the worlds (owner 2026-11-26: the fourth team slot is
  removed; *replaced 2026-11-26: "World 2 differs only by the fourth team slot" (2026-11-24)*).
- World label: `Client/WorldHud` shows "World N" (`WorldConfig.Id`) under the top-right pills, as wide as and
  right-aligned with HudChrome's right column, in the gap above it (phones: the HUD's UIScales): the old top-right
  pills' dark round pill with white outlined text, in both worlds. Display only; shown in both worlds.
- Travel: while the server holds a trip (player attribute `Travelling`, `WorldTravel.Go`, gate or admin command alike),
  TeamToast shows "Travelling to World N..."; a failed trip shows TeamToast's "TRAVEL FAILED, TRY AGAIN". The locked
  gate looks unchanged.
### Welcome
- `Server/WorldWelcome` sets `World2Welcomed` (saved, above) and `World2WelcomeShow` (session) the first time a
  loaded player stays in World 2 (`CanEnter`; not an arrival that is sent back; Studio playtests always). `Client/World2Welcome`
  (World 2 only) shows one small handscroll popup (4.46): "WORLD 2", "Welcome to the Rift Shrine",
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
- Recorded exception to the freeze, road supports' tops, and the bases of the 6 sunk rows, only (owner 2026-11-26 "fix rendering on all tracks", rendering
  priority "Ground/grass/z-fighting"; the lead's approval under the owner's same-day pre-approval; after pictures for the
  owner's review on return: `assets/world2_draft/audit/render_2026-11-26/T2_fill_after.jpg`, `T5_pier_after.jpg`,
  `T7_bank_after.jpg`; docs/W2_RENDER_AUDIT.md). The draft road supports under raised road (Fill on Tracks 2, 3 and 4,
  Pier on Track 5, Bank on Track 7) keep their footprint, and their base except where sunk (below); their top sits `SUPPORT_CLEARANCE` (0.05, TrackBuilder's
  own value) under the lowest road underside over the support's length, with `SUPPORT_SLACK` (**placeholder** 0.15, the
  centre line's shortfall at a support's far corners on a curve) more. A support that would be thinner than `SUPPORT_MIN`
  (**placeholder** 0.2) is that thick and sunk into the ground (its base moves down), never dropped: 6 rows on the
  2026-11-26 layout. Generators: `kit.support_top` and
  `kit.support` (tools/blender/world2/kit.py); Studio check `road_surface_clear` (on demand). The exception covered the old
  layout: on the wide layout (square spiral, 2026-11-26) the roads have no slopes, so there are 0 Fill, Pier and Bank rows.
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
  placement. The rest of Track 5 stays frozen. Every other track stays on the re-export hold (lifted for the colours, next line).
- Re-export hold lifted by the owner 2026-11-25 ("yes to all", item 5: after one test model is compared beside an old one; done the same day, three
  matched the approved colours): the meshes may be exported and uploaded again with their approved colours (docs/W2_REEXPORT_PLAN.md).
  Shapes, layouts, Drafts and the freezes do not change by it; Track 5's `GiantCorpse` waits for its own export.
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
- Sky props on the wide layout (**proposed**, agent-3, 2026-11-26, re-fit round 2; lead's ask, not yet owner-approved): a
  prop that stands high off the ground (sky doors and arms, clouds, floating rocks and smoke, a tower's chains) stays inside
  its own track's band: its base centre on its own ground (as every prop) and its whole box within the ground its road owns,
  so nothing of one track hangs over another's land. Its top stays under SKY_TOP (**proposed** 300 studs over the ground)
  unless it is at least SKY_FAR (**proposed** 1,500 studs) from every other track's road, so its silhouette is not seen above
  another track's horizon through that track's fog. Checked by geometry on the Drafts (`tools/blender/world2/sky_check.py`;
  a Blender fog render was tried and does not model the game's Atmosphere): 677 rows over SKY_TOP within SKY_FAR of
  another road on the landed Drafts, 523 of them Track 10's sky doors (116 Track 8's rock pillars), so the numbers need the owner before they are enforced; the Studio
  check decides what the game's fog hides.
- Track 6 lit landmark (owner 2026-11-25, "lit landmarj approved"; renders went to the owner, who approved the merge (choice E, 2026-11-26)): at the bend
  (0.06 run camera) and the finish (0.9), from meshes the track already places, unchanged, on its own ground by base
  centre, touching no other track's prop: a Mansion with its lit balcony face to the bend's axis in place of one Apaato,
  and one more Office tower (scale 0.55, the approved top) with its lit face to the finish axis. The spots are
  **proposed** (`tools/blender/world2/cross_track.py` LANDMARK). The HQ is back since 2026-11-26 (below); whether the
  finish Office, the stand-in "where the HQ would stand", stays is open for the owner.
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
  layout, which would double the approved building count). Track 6's HQ: owner 2026-11-26 ("Approve 1-4", design log
  fe810a44) brings it back on its legal spot on its own ground (0.9 axis, world -2714, 2418) with its 2 floodlights
  (46 lamps, 48 lights), lifting the "for now" of 2026-11-25.
  Track 7's island runs along the road (coast 260 studs out on both sides, the 48 ships at 312, inside its Ground
  rect) instead of an oval round the whole track; its nest is turned to face its road so its ants stand on its own
  ground, a change from the approved random turn, for the owner.
- Track 7's sea (2026-11-26, the owner's "fix rendering on all tracks", lead's decision, **proposed**): terrain Water from
  280 studs off Track 7's road out to its own ground's edge (the coast and the ships' band), level -3, so the 48 blockade
  ships float as in the approved draft instead of standing on grass. World 2 AntIsland only; road corridor, walls,
  checkpoints and the grass-strip rule unchanged (BIOME_ENVIRONMENT_SPEC 2.2 "Coast"). Its water colour is the approved
  draft's sea, 1C4260 (transparency 0.3, reflectance 0.25, waves 0.15 / 8; proposed), set per zone on the client. The sea's
  bed is Sand (the profile's Materials.Bed, was Ground; proposed, 46ffbe4b), the approved draft's beach under the water.
- Hero moves (2026-11-24; re-fitted to the wide layout 2026-11-26): a hero landmark with no placement that passes every game rule moves whole (all its pieces, its
  scale and turn) to a spot on its own track's ground that clears its own and every other track's corridor, the spawn area
  and every checkpoint and win pad, and lies on its Ground rectangle (BiomeDressing builds a Placed prop only there); among
  those, a spot a run camera has in frame within 1,600 studs first (export_props.find_spot / seen_near, **proposed**), else
  the nearest. The move lives in tools/blender/world2/hero_moves.json (track-local studs, base centre x, z). Moves on the
  square spiral: Track 5 DefenseHQ 60, Track 9 Church 310, Track 10 DarkGate 90 (none on Tracks 1-4, 6-8).
- Shrink to fit (owner 2026-11-26, "Approve 1-4", design log fe810a44): a hero with no spot at its approved scale stands at
  the largest scale that fits its own ground (its real mesh box and the game's parts fallback clear of every road by
  24.5, pads and the plaza, base centre on its own ground and Ground rect), with its approved turn, where a run camera
  sees it (`tools/blender/world2/herofit.py` and the biome scripts). On the wide layout: Track 1 Town 1.015 (approved
  1.6) in the 0.33 view; Track 3 HeroHQ 0.562 (approved 2.3+) in the 0.33 view; Track 7 IslandVolcano 0.389 (approved
  1.25) seen from the 0.06/0.62/0.9 cameras, the 0.33 view kept for the nest; Track 8 LairTower 3.45 (approved 4.2)
  ahead of the 0.62 camera, turn 0; Track 10 Abyss radius 210 (its rule's old floor 800; in a Draft for the first time)
  about 400 studs ahead of the 0.9 camera, its wide face to it (lead 2026-11-26: radius 500 past the finish stood
  2,760 studs from that camera and did not draw). Track 1 RuinedCastle and Track 2 ChainTower stand at their approved scales on the wide layout
  (re-fit round 2). Track 9's Barrier (a dome over every road) stays out, as before.
- Re-fit round 2 (2026-11-26; the lead's approval under the owner's nightly pre-approval, for the owner's review on
  return; renders assets/world2_draft/relayout_2026-11-26, report docs/proposals/W2_REFIT_REPORT.md). Each **proposed**:
  - Own-band backdrop (`kit.band`): each track's approved backdrop props, at their approved scales and turns, out to its
    ground midline (about 380 studs) on its own ground and Ground rect: T4 Cedar, T5 Office and Apartment, T8 cavern props
    (RockPillar, CityChunk, Graveyard, Colonnade, FleshWall), T9 Forest, T10 Hill and Hand. Rows against the approved Drafts:
    T1 1,019 (355), T2 980 (474), T3 1,021 (475), T4 1,191 (949), T5 1,010 (596), T6 937 (765), T7 1,123 (1,167),
    T8 1,734 (1,435), T9 1,395 (2,012), T10 2,620 (3,888); the own ground grew about five times (bands about 380 a side
    for about 60 to 75), and T9's city grid and T10's sky doors past their own ground or Ground rect are left out.
  - Track 1 (agent-1's round 2): the first and last villages moved just ahead of the 0.06 and 0.9 run cameras; the woods
    in patches with open meadows between (a smooth mask), not one even carpet over the wide band; the 0.9 view, which
    runs down a long straight past the finish, closed with the track's own woods and ruins.
  - Track 2 (agent-1's round 2): a band loop of the approved scatter props out to the midline: Crag 1.5-3.0, RuinB
    1.0-2.2, RuinA 1.0-1.6, at 190 to 305 studs from the centre line.
  - Track 3 (agent-1's round 2): city rows at 235, 300 and 355 studs from the centre line, and 6 HighRises at 1.25 to
    1.45 framing the finish; the crater at a new spot in a run camera's view.
  - Track 1's ranks keep their approved turn relative to the road (they turned toward the town, which the layout moved).
  - Track 7's mound cluster re-placed on its own band (agent-1).
  - Track 9's city wall along both edges of its own band, `WALL_OFF` 290 studs from the centre line, in 520-stud pieces
    (was an ellipse round the whole track box), the golden forest past it.
    For the owner: a wall piece is stretched along X to fit its stretch of road, up to 1.523 (the approved draft's
    stretches reached 1.167).
  - DemonCastle's castle plinth `PLINTH_CLEAR` 300 studs from its road (was 340; the wide layout's own ground ends about
    329 out).

## Track effects (draft, owner approval pending)
Owner 2026-11-26 (design doc change log, verbatim): "Begin drafting vfx for dynamic smoke on tracks and vfx for moving
dragons and dyanmic movement for some track assets to increase immersive experience. You can go ahead and approve the
assets that you draft up for and i iwll approve the vfx and motions after it is fully finished." So the lead approves the
new meshes and textures; the effects and motions stay drafts until the owner approves them. **Every number below is
proposed.**

- Off: `Shared/TrackFxConfig.LIVE = false`. `TrackFxConfig.Enabled(worldId)` is true only when LIVE and in World 2, so
  World 1 never builds anything (its biome keys have no row either). Turning it on needs the owner's approval of the
  previews, then the uploads below and their ids in the ledger.
- Client only (BIOME_ENVIRONMENT_SPEC 5): `Client/TrackFx` (started by `Client/TrackFxRun`), data in
  `Shared/TrackFxConfig`, math in `Shared/TrackFxPlan`. The server never reads them. Every instance is local; a moved
  prop is moved locally and put back at its server CFrame when the effect lets go of it.
- Only the track the camera is in runs (`BiomeEnvironment.ZoneAt` at the camera focus); a zone change tears the old one
  down. REDUCED EFFECTS (`ReduceEffects`, BIOME_ENVIRONMENT_SPEC 8) turns all of it off; lamp brightness is then left to
  `Client/BiomeEnvironment`.
- Anchors: a named placed prop (its draft key, read from the `Placed_<i>` model: the mesh child's name, the fallback parts'
  name or the lane C `Mesh` attribute; `Offset` is a point of its box, -1..1 per axis) or a track-local spot (`At` along
  the centre line, `Side`, `Lateral`, `Height`, from `TrackBuilder.Layout`). Never a world position, so the effects follow
  the re-laid tracks. A track's origin is computed on the client from the chain as Main.server builds it
  (`TrackBuilder.CHAIN_ORIGIN`, `Layout`, `EndCFrame`; `TrackFxPlan.ChainOrigins`), never read from a streamed part: with
  StreamingEnabled a track's `Start` is out of range away from its beginning, and the effects waited on it (Studio
  2026-11-26, docs `assets/world2_draft/track_fx/studio_2026-11-26/README.md`).
- Off the road (2026-11-26, the props rule): every emitter's spread (the circle round its emitter box, `Area` or `Fill`)
  stays at least `ROAD_CLEAR` 24 studs (horizontal) from every World 2 track's centre line. Where it does not, the spread
  is first narrowed, down to `MIN_SPREAD` (**proposed** 0.5) of its width, then the emitter is moved straight away from
  the nearest centre line until it clears; one that still touches another road is not built (`TrackFxPlan.ClearSpread`).
- Dragons over their own ground (2026-11-26): every point of a dragon's loop lies over its own track's ground (its nearest
  centre line, of all World 2 tracks, is its own track's, by `OWN_MARGIN` **proposed** 20 studs), the ownership rule of the
  scenery (TerrainShape.Owner, the gap midline). The loop keeps its shape: it is shrunk as a whole about its foot on its
  own centre line (side offset and radius by one factor) to the largest size that fits (`TrackFxPlan.FitLoop`); a dragon
  whose loop would need a radius under `MIN_LOOP_RADIUS` (**proposed** 120 studs: tighter turns fold the eel) is not
  built. The 150-stud clearance from its own centre line still holds. Measured 2026-11-26: on today's routes only
  Track 1's drake fits (93%); the others are not built (the tracks lie about 150 studs apart). On the C layout
  (orch/world2/w2-wide-layout) every loop fits: Track 1's drake at full size once it flies on the right of its road
  (`Side` 1, was -1, **proposed**: on the left it never fits on that layout), Track 2's two drakes at 70% and 54%,
  Track 4's eel at 62% and Track 7's drake at 50%.
- The eel reads as one body: each segment overlaps the next along the path (segment length at least `EEL_OVERLAP`
  **proposed** 1.6 times the spacing between their centres, with the tail's side-to-side wave counted), so no gap shows.
  Its segments are longer meshes of the same model (scale only: same 14 segments and tris): first segment 40 long (was 27.5,
  **proposed**), and the tail's side-to-side wave 10 studs (was 15, **proposed**).
- Assets: in-house only (design doc 5, BIOME_ENVIRONMENT_SPEC 4.4 Lane B): Blender geometry
  (`tools/blender/world2/track_fx.py`) and numpy textures (`tools/blender/world2/track_fx_textures.py`, the roblox-vfx
  method). The dragon and the eel are generic: no anime's dragon design (no whiskers, antlers, pearl, coiling serpent
  dragon or any show's markings). An effect whose asset has no `Id` is not built.

### Effects per track
| Track | Smoke and particles (prop: preset, most at once) | Dragons | Motion |
|---|---|---|---|
| 1 ElvenPlains | Cottage: Chimney 4; Forest: GroundHaze 3 | 1 drake, green-bronze | Pine sway (2 deg, 4.6 s), 30 |
| 2 DemonCastle | Smoke: SmokeColumn 4 (violet-black, magenta below); RuinB: Embers 3 and RubbleSmoke 3; Rampart: brazier Chimney 4 | 2 drakes, black-violet | Wyvern statues bob (3 studs, 6 s), 6; lamps flicker (fire) |
| 3 RuinedCityZ | Collapsed: RubbleSmoke 4; OfficeBroken: RubbleSmoke 3; Rubble: GroundHaze 3 (dust) | none | none |
| 4 HauntedTunnel | Cedar: GroundHaze 5 (cold mist); Portal: GroundHaze 2 | 1 spirit eel, pale cyan, see-through | Cedar sway (1.5 deg, 5.5 s), 30; lamps stutter and cut out |
| 5 KaijuBase | Smoke: SmokeColumn 4 (grey); GiantCorpse: Steam 2; Rubble: RubbleSmoke 4 | none | none |
| 6 DevilTokyo | Konbini, ShopHouse: roof-vent Steam 4 each | none | CrossWire sway (0.8 deg, 3.8 s), 16; lamps buzz |
| 7 AntIsland | IslandVolcano: SmokeColumn 1 (when it is placed); Camp: RubbleSmoke 3; ThatchHouse: Chimney 4 | 1 drake, rust | Ship bob (0.8 studs, 3 deg roll, 5 s), 10; Brush sway (3 deg), 24 |
| 8 MonsterDen | LavaChasm: Steam 3 and Embers 3 (spread over the river); RockPillar: GroundHaze 4 | none (low ceiling) | lamps flicker |
| 9 GoldenCity | Square: gold Motes 4 | none | none: the city is turned to solid gold (townsfolk, wagons and trees are gold statues caught mid-step, the approved draft's story), so smoke or sway would contradict it |
| 10 HellGate | Hill: red GroundHaze 4, a little less opaque than the preset (below) | none | SkyDoor bob (4 studs, 9 s), 24; ArmA / ArmB sway (1.2 deg), 8 each |

Every World 2 track's approved scenery stays frozen: the effects change no layout, mesh or placement; they only add
local particles and local motion on the approved props.
- Track 10's red haze (owner 2026-11-26, design doc change log: "tone down track 10 red haze tiny bit"): its Hill
  GroundHaze row draws a little less opaque than the GroundHaze preset, its plateau transparency 0.82 (**proposed**;
  the preset's 0.78, so at most 18% opaque instead of 22%). Only Track 10: the other tracks' haze rows keep the preset.
  A smoke row may carry its own `Transparency` keys (TrackFxConfig), which replace its preset's.
- Answered (owner 2026-11-26): the DemonCastle drakes stay as drafted ("demoncastle drakes are fine"), and the
  effects stay out of the game until the owner approves them (`LIVE` false).
- Review note (likeness), answered: the DemonCastle drakes (Track 2, a Solo Levelup biome) are black-violet winged
  drakes, near the look of Kaizel, the source show's black shadow wyvern mount; the mesh is generic (no rider, no armour,
  no show markings). The owner kept them as drafted (above).

### Budget (proposed)
- Per track (only the camera's track runs): at most 14 emitters and 400 steady-state particles (sum of Rate x mean
  Lifetime); Rate at most 10 per emitter; cull at 600 studs by default, per preset 350 to 1200, never past 1400.
  The configured worst cases (every row at its Max): 4 to 14 emitters, 38 to 253 particles (DemonCastle highest).
- Dragons: at most 2 per track, hidden past 3000 studs; each loop keeps 150+ studs (3D) from its own track's centre line.
  Drafted loops: 200 to 260 radius, 300 to 360 up, 360 to 440 to the side, 64 to 85 s a lap; drakes flap every 1.8 s
  (32 deg) and glide a third of the time. As fitted to their own ground (FitLoop) on the C layout, 2026-11-26: radius
  124 to 220, 216 to 420 to the side, clearance 247 to 361; on today's routes Track 1's drake only (radius 205,
  clearance 280).
- Motion: at most 40 moving props per track within 350 studs, 24 flickering lamps within 300; updated 30 times a second.
  Sway at most 5 deg, bob at most 5 studs.

### Assets (approved by the lead 2026-11-26 on the owner's word; uploaded 2026-11-26, all moderation Approved)
| Key | Kind | Size | Tris | Id in game (uploaded as) |
|---|---|---|---|---|
| TrackFx_SmokePuff | Texture, 4 x 4 flipbook | 1024 x 1024 | | image 131238123745137 (Decal 97289512542692) |
| TrackFx_Wisp | Texture, 4 x 4 flipbook | 1024 x 1024 | | image 121171857790986 (Decal 109316241038637) |
| TrackFx_Haze | Texture | 512 x 512 | | image 133212472173493 (Decal 134622627756910) |
| TrackFx_Ember | Texture | 128 x 128 | | image 130564448358590 (Decal 118705205041971) |
| TrackFx_DrakeBody | Mesh (vertex colours, tinted per track) | 11.1 x 13.7 x 71, used at x1.6 | 196 | MeshId 99358143355177 (Model 128203234362835) |
| TrackFx_DrakeWing | Mesh (one wing; the right is the same mesh turned) | 44 x 1.75 x 26, x1.6 | 60 | MeshId 70831317809815 (Model 97155744574570) |
| TrackFx_EelHead | Mesh | 6.3 x 9 x 15, x2.5 | 92 | MeshId 81336925420911 (Model 129183633171315) |
| TrackFx_EelSegment | Mesh (14 per eel, tapering) | 5.9 x 9 x 11, x2.5 | 52 | MeshId 125251547523736 (Model 140101377134796) |

A drake is 196 + 2 x 60 = 316 tris; an eel 92 + 14 x 52 = 820. Files: `assets/world2_draft/track_fx/textures/` and
`meshes/`. Uploaded 2026-11-26 under the owner's account (user 232682736, as the other World 2 uploads) by
`tools/blender/world2/upload_track_fx.py` on the Mac, after the rules audit's IP review ("OK to upload", all 8) and the
lead's approval on the owner's word. Textures went up as Decals and were resolved to their image ids through the asset
delivery API; meshes went up as Models and their MeshIds were read from the downloaded Models
(`tools/lune/trackfx_meshids.luau`), no Studio. Moderation: every Decal, image, Model and MeshId Approved. Ledger:
`assets/world2_draft/track_fx/assets.json`; ids and `Reviewed = "2026-11-26 rules auditor"` in `TrackFxConfig.Assets`.
The effects stay off (`LIVE = false`) until the owner approves them.

### Previews for the owner
`assets/world2_draft/track_fx/previews/`: `overview.jpg` (one frame of each), and per effect a 12-frame GIF and a
`_sheet.jpg`: smoke_demoncastle, smoke_kaijubase, smoke_elvenplains, smoke_ruinedcityz, smoke_antisland,
steam_deviltokyo, haze_hauntedtunnel, haze_hellgate, lava_monsterden, motes_goldencity, dragon_drake, dragon_drake_flap,
dragon_eel, motion_pine_sway, motion_ship_bob, motion_skydoor_bob, motion_flicker; `meshes_*.png` turnarounds;
`textures_review.png`. Rendered headless in Blender 5.2 with the approved props' GLBs and a Python copy of the
presets (the in-game look needs Studio).

### Tests
- ServerTest `track_fx` (lune, both worlds; 2026-11-26: 80 checks in World 1, 106 in World 2 on today's routes, 110 on
  the C layout): LIVE off by default, no real name in any ledger key or prompt, eel segments evenly spaced round the loop, World 1 never on, rows only for World 2 biomes, presets
  and every track's worst case inside the budget, anchors name props of the biome's approved draft, dragons capped and
  clear of the road, the nearest-first pick never past a cap, flicker in 0..1; since 2026-11-26 also every emitter's
  spread 24+ off every road, every dragon loop over its own ground, the eel's segments overlapping, and the chain
  origins equal the live Starts in Studio (offline: biome_harness WORLD=2 "W2 FX ORIGIN CHECKS"); Track 10's haze row a little less opaque than its preset (at most 0.06 more transparent) and every other smoke row on its preset's keys.
- Not run: Studio (needs LIVE on in a test session; the uploads are done), frame time on a phone.

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
- *Replaced 2026-11-26 (owner: the fourth slot is removed): "Team of 4 (2026-11-24): an older World 2 build caps the
  Team at 3 and rebuilds `Worlds.W2`, so it would drop slot 4 and the `Welcomed` flag. Shut down every older World 2
  server when this ships, and publish World 1 first or together with World 2 (test `world2_team`)."*
- Team of 3 (2026-11-26): shut down every World 2 server of the team-of-4 build when this ships. One left running lets
  a player save 4 again; that is harmless (the next load trims it to 3, "Save" above) but the Team would flip between
  4 and 3. The `Welcomed` flag and unknown `Worlds.W2` keys are kept by both builds (test `world2_team`).
