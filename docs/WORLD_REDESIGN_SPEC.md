# World redesign: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3, 4.1, 4.9, 4.10 and 5, and on
`docs/TRACKS_AND_BIOMES_SPEC.md`. Owner decisions 2026-10-28: redesign the overall map (spawn hub, player plots,
tracks and biomes, world layout) and scrap every car model, the car body included. Numbers and names are placeholders
unless stated.

## 1. Scrap list (fixed)

Nothing car-shaped stays in the game:
- The car body under the runner (`CarFactory`), car physics (`CarPhysics` raycast suspension, wheels, `VehicleSeat`),
  car handling config (`CarConfig`) and the car-only parts of `PhysicsTargets`.
- Car-themed world assets: `assets/studio/RacingGarage.rbxmx` (workshop garage kit), `RaceStartPavilion.rbxmx`, the
  empty `CarModels` folder, and the fork's whole Market (`SpawnMarketplace.rbxmx`, `MarketplaceBuilder`; owner 2026-11-04,
  section 7).
- Car icons and car art keys in the UI (e.g. the `rusty_hatchback` atlas keys in `RacerComponents` /
  `UpgradeTreeView`) and any remaining player-facing "car" wording.
- The `Cars` collision group becomes `Runners` (players still pass through each other; NPC parts never collide).

## 2. Placeholder anime runner (replaces the car body)

- Every player's active character and every NPC rival is a blocky humanoid rig: Head, Torso, 2 arms, 2 legs
  (R15-style proportions, placeholder; final art follows design doc 5), coloured from the character's series palette with a rarity
  trim. A `BillboardGui` shows the character's name (finite `MaxDistance`). A track enemy has none: its indicator is the client's `NpcIndicator` ScreenGui (design doc 4.26).
- The runner is anchored and moved by `RaceService` along the race path (the IVS rail already holds an exact speed
  everywhere): position on the right-hand lane, facing along the path, upright (up-vector Y = 1). No physics forces.
- Smooth motion (owner 2026-10-28): the
  server's anchored rig is the exact authoritative pose; each client renders the visible runner smoothly by
  interpolating along the path from the server's distance and speed, so players see no stutter. The IVS
  `rail_never_snaps` check is replaced by a client-side smoothness check.
- Run animation is procedural and client-side (limb swing and bob from speed); it never changes the server pose.
  A character's optional `RunStyle` replaces the universal run (design doc 4.34). Both add the same client-side particle
  effect on each player's drawn runner (design doc 4.23): 3 emitters, 36 particles/s per runner (**proposed**), existing textures only.
  Dust is locked to the runner and blown back from behind the feet: at 700 studs/s world-space puffs land 70 studs apart.
- Universal run pose, all **proposed** placeholders. Sources give no reliable angles for this style, so these are tuned by eye:
  - Torso 30 deg forward about the hips (supported: a faster run leans more; the angle is the owner's look choice).
  - Arms pump +-50 deg opposite the legs, 10 deg back bias, 6 deg outward (supported: arm opposite leg; the angles are inferred).
  - Head 24 deg back from the torso, keeps the bob (inferred: eyes ahead, the ninja run's ratio).
  - Legs swing 65 deg (inferred: larger swing at speed). Cadence unchanged. A torso-only lean is the rig's limit: guides prefer leaning the whole body.
- The player's avatar is hidden while racing, as before; the Humanoid stays for camera and respawn.
- Auras and trails attach to the runner's Torso instead of the car.
- Kept from IVS: exact cruise speed at once on every start / checkpoint / restart, stays within
  `MaxPathDeviation` of the path, pad paid once per pass, NPC race and banked money unchanged.
- Retired with the car: flip recovery (a rail runner cannot flip), car physics scenarios (`static_settle`, `accel`,
  `brake`, `skidpad`, `car_size`, `flip_recovery`, car lap bots). Replaced by `runner` scenarios (below).
  The non-flip checks inside `flip_recovery` (live aura re-target, fastest character at max stat) move to `runner`.
- Owner 2026-10-29:
  - Instant start: a run starts at once, with no cancellable "Teleporting" phase (there is no seat to wait for).
  - Index tiles and leaderboard pedestals show the character's placeholder runner rig.
  - While racing, the camera follows the visible runner.
  - The hidden avatar is welded inside the runner's Torso; the Humanoid stays.
  - A mid-race character switch works as the IVS mid-race car switch.
  - The rarest-character leaderboard is titled "RAREST CHARACTER".
- Owner 2026-10-30:
  - Rail-fall recovery is retired with the car: the anchored runner cannot leave the rail. Its checks and the
    `RailFallRecoverySeconds` target (owner 2026-10-20) go.
  - Instant start covers solo runs only. A duel keeps its "Teleporting" hold while both runners wait for the
    countdown.

## 3. World layout

- The spawn hub sits at the world centre. The 7 player plots form a ring around it. The track chain starts at the
  hub's start gate and spirals outward, one biome sector per track (Track 1 nearest the hub, Track 10 outermost).
- Every track, plot and the hub keep the IVS no-overlap rules; the safety baseplate covers everything plus a margin.
- Exact coordinates are chosen by the world build, inside these rules.
- Owner 2026-10-30 (placeholders, tunable): world centre = origin (0, 0); plot ring has nearest / farthest plot
  distance >= 0.75 and no gap between neighbouring plots wider than 135 degrees; baseplate margin 20 studs; the torii
  start gate is at least 16 studs tall; Track 1 starts within one road width (40 studs) of the start gate.
- Owner 2026-10-30 (placeholder, tunable): each Dojo plot's front points within 45 degrees of the plaza centre.
- Owner 2026-10-30 (placeholder, tunable): "spirals outward" means each track's mean centre-line distance from
  the plaza centre (XZ) is greater than the previous track's; Track 1 has the smallest.
- Owner 2026-10-30: a track's "biome sector" may be a ring band of the spiral (about 1.5 laps around the plaza),
  not an angular wedge.

## 4. Spawn hub: anime town plaza

- One `SpawnLocation` at the plaza centre (the only one in the place).
- **Start gate**: a large torii-style gate; walking through it starts the run (the
  IVS `StartPad` rules and cooldown, tag `StartPad`).
- **Service row** (owner 2026-11-04): Shop, Potions, Market and Index in one straight row (section 7; same panels and remotes as now).
- **Index board** (scroll wall) and the checkpoint NPC as a **sensei**
  (same `CheckpointService` rules).
- Look: a few lanterns, one cherry tree, stone paving, wooden roofs; no logos or real names (design doc section 5).

## 5. Player plots: the Dojo (name proposed)

- The 7 workshop plots become **Dojos** (48 x 48, same assignment rules: lowest free plot on join, freed on leave).
- The **Dojo squad** is the IVS Showcase: the player picks 3 owned characters who are **not in the racing Team**;
  they stand and train in the Dojo.
  Owner 2026-11-03 (design doc 4.19): the squad's combined rarity sets the workshop stat boost; the Showcase formula,
  copies and idle gain are retired.
- New rule: a character is either in the Team or in the Dojo squad, never both. `SetTeam` and `SetShowcase` reject a
  character already in the other group.
- Workshop stat boost (owner 2026-11-03, design doc 4.19). Numbers placeholders, in `Shared/WorkshopConfig`:
  - `RARITY_POINTS` Common 1 .. Secret 7; `POINT_BONUS = 0.05`; `LEVEL_SCALE = 0.1`.
  - `Workshop.Boost(squadSpecs, level)` = sum(points) x POINT_BONUS x (1 + LEVEL_SCALE x (level - 1)).
  - Saved `WorkshopStat` (one of `Money`, `Luck`, `Speed`, `Stamina`; anything else -> `Money`); player attributes
    `WorkshopStat` and `WorkshopBoost` (the added fraction, e.g. 0.35).
  - Remote `SetWorkshopStat(stat)`: rejects any other value; rate limit 1 per 0.5 s; allowed at any time (a run in
    progress keeps its fixed Speed / Stamina).
  - The boost is added inside the chosen stat's additive part (Money, Luck: `GachaConfig.Multis` bonuses; Speed:
    `RaceConfig.SpeedMulti` tree-bonus part; Stamina: `StaminaConfig.Multi` tree-bonus part).
  - Workshop panel: 4 stat buttons (the chosen one highlighted), the boost "+35% Luck", the squad's rarity points and
    the level scale; the level upgrade button stays.
  - Retired: idle Money gain, offline workshop credit (and its Robux double), workshop in-zone luck, the `Workshop`
    stat point (refunded: `Workshop` leaves `GachaConfig.STATS`), Showcase copy bonus.
- Owner 2026-10-30: an old save whose equipped character is also in the Showcase drops that character from the Dojo
  squad on load (the slot is left empty, stored as an empty entry or removed; owner 2026-10-30); the Team is unchanged.

## 6. Tracks and biomes

As in `docs/TRACKS_AND_BIOMES_SPEC.md` (lengths x1.25 per track, 10 anime biomes), placed along the spiral.

## 7. First impression pass (owner 2026-11-03, design doc 4.24)

Draft: `tools/blender/plaza/build_plaza.py` (1 Blender unit = 1 stud, positions are world studs), reviewed by the owner
before any Studio work. All values below are **proposed**. Mesh and tri counts: printed by the build. Ledger: `tools/blender/plaza/plaza_assets.json`.
- **Sight line**: the spawn faces the gate across the 130-degree opening in the Dojo ring. The main path runs straight
  from the spawn to the StartPad. The SpawnLocation stays at the plaza centre and the StartPad stays where it is.
- **Start gate**: torii about 2x taller and turned to face the spawn along the path. Footprint stays clear of the road.
- **Path** (owner 2026-11-04): 12 wide and plain, with 2 stone lanterns on each side at its gate end. No small torii, lantern strings or banners.
- **Service row** (owner 2026-11-04), world positions with the spawn at the origin: fronts on one straight line at x = -72, facing +x, in the west opening of the Dojo ring so no Dojo stands behind it. South to north, evenly spaced between z -70 and z 45: Shop, Potions, Market, Index, sensei (proposed). Nothing stands between the spawn and a Dojo.
- **Market** (owner 2026-11-04): one in-house stall built from the plaza kit in `build_plaza.py`, with auras and trails on display; it opens the same Market panel. No fork art (`SpawnMarketplace`, `MarketplaceBuilder` retired), no vendor stalls, no courtyard.
- **Rebirth** (owner 2026-11-04): the shrine is removed; Rebirth opens from its HUD tile.
- **Best Roll** (owner 2026-11-04): pedestal at (-8.5, -75), between Plots 1 and 2, radius 9.
- **Spawn**: a circular stone mosaic with an abstract pattern, no symbol.
- **Sky loop legs**: the leg in front of the MARKET sign moves to about 200 degrees (owner 2026-11-04).
- **Legends** (owner 2026-11-04): at most 2 pedestals, one each side of the Race Start gate, clear of its posts, the path and Plot 7; about 9 studs tall. Client-only, like the sky-loop runners. `db_hero` and `mha_symbol` (their orange and blue match the logo; owner approved 2026-11-04).
- **Sky loop**: a raised ribbon above the plaza at radius about 62, height about 30, carrying the client-only runners.
- **Wayfinding**: RACE START banner on the torii under its tie beam; large flat MARKET sign on the Market, facing +x (owner 2026-11-04; no arch). Client/PlazaWayfinding draws the two floating labels from `PlazaAssets.Landmarks`
  as client-only attachments, so streaming never hides them.
- **Service headers** (owner 2026-11-04): `Shared/PlazaHeader` builds every floating header, plain GUI Instances with no image asset. Emblems and colours (proposed): RACE START green star, MARKET purple gem, SHOP blue gem, POTIONS magenta gem, INDEX gold star, SENSEI orange star, YOUR DOJO orange-red gem. Client/PlazaWayfinding draws Race Start, Market, Shop, Potions and Index; Shop, Potions and Index show out to about 150 studs and hide within about 10. SpawnArea builds Sensei on the server; Client/DojoExtras builds YOUR DOJO.
- **Reveal** (Client/ArrivalFlow): first join, after the loading screen, a skippable camera sweep of about 5 s that ends, skipped or not, behind the player looking at the gate; Reduced Motion: a still of the plaza, then a cut.
- **Starter pick**: popup with a lighter dim, opens after the reveal, with a watchdog so it always opens. A pick plays a petal burst and the character's hero pose beside the spawn for about 4 s; the first auto-roll waits about 5 s so its result card does not cover it.
- **Trail**: 12 flat neon discs along the path pulsing in a wave toward the gate, with petals drifting the same way, until the first run. Reduced Motion: steady discs, no petals.
- **Daily hold**: the Daily panel's auto-open waits until a new player's first run ends; its HUD button still works. "New" survives a rejoin: no money earned, no track beaten, no Daily claimed.
- **Gate burst**: petals and gold at the pad when a new player's first run starts within 40 studs of the gate.
- **Dojo extras** (Client/DojoExtras): a petal burst on a level rise; squad rigs play an idle jab within 80 studs; `Glow_lamp` parts take the colour of the owner's `WorkshopStat`; a bold YOUR DOJO label for a new player until they walk within 30 studs or race. All client display; Reduced Motion stops the burst and the training.
- **Fresh-save checks**: in Studio only, ReplicatedStorage attribute `TestSaveKey` = "<name>" (set in Edit before Play) plays on a separate save `Test_<name>_<userId>`; a new name is a new save. Read once at server start; leaderboards skip these sessions. Clear it afterwards: the `data` scenario expects real keys. Do not send gifts in a test session: `GiftRoutes_v1` still uses the real buyer id.
- **Load**: the loading screen waits for `TerrainNearReady` (plaza and Track 1 terrain, their stand-in ground cleared), `CharacterModels` Ready and `PlazaReady`, then preloads what is on screen in 4 streams. Other characters and Dojo tiers (`ReplicatedStorage.PlazaTierMeshes`) preload behind the game.
- **Sensei**: ends the service row, beside the path (`CheckpointConfig.NPC_POS`).
- **Trees** (owner 2026-11-04): one Great Sakura, outside the Dojo ring behind the gap between Plots 5 and 6, clear of the road and the plots, with a solid invisible trunk. No smaller trees, planters or benches.
- **Atmosphere**: zone 0 has a petal emitter (Rate 10, Reduced Effects rules as other zones) and `AmbForest` + `SfxWindChime` at volume 0.2.
- **Index icon**: a fan of three cards, in-house (`tools/blender/plaza/index_icon.py`), replaces the car (section 1).
- **Dojos**: built from one kit inside the 48 x 48 plot. Zone, Showcase pedestal and UpgradePad positions stay. A free
  plot holds a closed shell that is not named `Workshop`, and its sign text comes from `WorkshopConfig.EMPTY_TEXT`, "FREE DOJO".

## 8. Tests (written first)

- `runner`: body is a humanoid rig with no wheels / VehicleSeat / suspension; anchored; upright (up Y >= 0.999) on
  every track at normal and max stat speed; on path (deviation <= `MaxPathDeviation`); exact cruise speed; pad paid
  once; NPC rival uses the same rig.
- `scrap`: no `CarFactory`, `CarPhysics`, `CarConfig`, `VehicleSeat`, wheel parts or car assets in the place or in
  `src/`; no `Cars` collision group.
- `world_layout`: hub at the centre, 7 plots around it, Track 1 start at the start gate, no overlaps, baseplate
  covers everything, one SpawnLocation.
- `dojo`: squad of 3 not in the Team, cross-rejection.
- Track tests per `TRACKS_AND_BIOMES_SPEC.md`.
