# World redesign: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3, 4.1, 4.9, 4.10 and 5, and on
`docs/TRACKS_AND_BIOMES_SPEC.md`. Owner decisions 2026-10-28: redesign the overall map (spawn hub, player plots,
tracks and biomes, world layout) and scrap every car model, the car body included. Runs after f2 lands, before any
other work. Numbers and names are placeholders unless stated.

## 1. Scrap list (fixed)

Nothing car-shaped stays in the game:
- The car body under the runner (`CarFactory`), car physics (`CarPhysics` raycast suspension, wheels, `VehicleSeat`),
  car handling config (`CarConfig`) and the car-only parts of `PhysicsTargets`.
- Car-themed world assets: `assets/studio/RacingGarage.rbxmx` (workshop garage kit), `RaceStartPavilion.rbxmx`, the
  empty `CarModels` folder, and car-themed parts of `SpawnMarketplace.rbxmx` / `MarketplaceBuilder` (the aura / trail
  item meshes stay if they are not car-shaped).
- Car icons and car art keys in the UI (e.g. the `rusty_hatchback` atlas keys in `RacerComponents` /
  `UpgradeTreeView`) and any remaining player-facing "car" wording.
- The `Cars` collision group becomes `Runners` (players still pass through each other; NPC parts never collide).

## 2. Placeholder anime runner (replaces the car body)

- Every player's active character and every NPC rival is a blocky humanoid rig: Head, Torso, 2 arms, 2 legs
  (R15-style proportions, placeholder; final art follows design doc 5), coloured from the character's series palette with a rarity
  trim. A `BillboardGui` shows the character's name (finite `MaxDistance`).
- The runner is anchored and moved by `RaceService` along the race path (the IVS rail already holds an exact speed
  everywhere): position on the right-hand lane, facing along the path, upright (up-vector Y = 1). No physics forces.
- Smooth motion (owner 2026-10-28, replaces the IVS 2026-10-15 "rail steers with velocity, never snaps" rule): the
  server's anchored rig is the exact authoritative pose; each client renders the visible runner smoothly by
  interpolating along the path from the server's distance and speed, so players see no stutter. The IVS
  `rail_never_snaps` check is replaced by a client-side smoothness check.
- Run animation is procedural and client-side (limb swing and bob from speed); it never changes the server pose.
  A character's optional `RunStyle` replaces the default swing and may add a client-side particle effect (design doc 4.23).
- The player's avatar is hidden while racing, as before; the Humanoid stays for camera and respawn.
- Auras and trails attach to the runner's Torso instead of the car.
- Kept from IVS: exact cruise speed at once on every start / checkpoint / restart, stays within
  `MaxPathDeviation` of the path, pad paid once per pass, NPC race and banked money unchanged.
- Retired with the car: flip recovery (a rail runner cannot flip), car physics scenarios (`static_settle`, `accel`,
  `brake`, `skidpad`, `car_size`, `flip_recovery`, car lap bots). Replaced by `runner` scenarios (below).
  The non-flip checks inside `flip_recovery` (live aura re-target, fastest character at max stat) move to `runner`.
- Owner 2026-10-29:
  - Instant start: a run starts at once, with no cancellable "Teleporting" phase (there is no seat to wait for).
  - The seat-failure checks (`event_seat_fail_*`) are retired with the `VehicleSeat`.
  - Index tiles and leaderboard pedestals show the character's placeholder runner rig.
  - While racing, the camera follows the visible runner.
  - The hidden avatar is welded inside the runner's Torso; the Humanoid stays.
  - A mid-race character switch works as the IVS mid-race car switch.
  - The rarest-character leaderboard is titled "RAREST CHARACTER".
- Owner 2026-10-30:
  - Rail-fall recovery is retired with the car: the anchored runner cannot leave the rail. Its checks
    (`fall_below`, `launched_above`, `rail_fall_api_exists`, `back_on_path_fast`, `snap_counted`) and the
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
- **Start gate**: a large torii-style gate replaces the Race Start pavilion; walking through it starts the run (the
  IVS `StartPad` rules and cooldown, tag `StartPad`).
- **Shop street**: stalls for Shop, Market and Potions around the plaza (same panels and remotes as now).
- **Rebirth shrine**, **Index board** (scroll wall), **leaderboard banners**, and the checkpoint NPC as a **sensei**
  (same `CheckpointService` rules).
- Look: lanterns, cherry trees, stone paving, wooden roofs; no logos or real names (design doc section 5).

## 5. Player plots: the Dojo (name proposed)

- The 7 workshop plots become **Dojos** (48 x 48, same assignment rules: lowest free plot on join, freed on leave).
- The **Dojo squad** is the IVS Showcase: the player picks 3 owned characters who are **not in the racing Team**;
  they stand and train in the Dojo and multiply idle Speed gain with the IVS Showcase formula (unchanged numbers).
  Owner 2026-11-03 (design doc 4.19, replaces the idle gain): the squad's combined rarity sets the workshop stat
  boost instead; the Showcase formula, copies and idle gain are retired.
- New rule: a character is either in the Team or in the Dojo squad, never both. `SetTeam` and `SetShowcase` reject a
  character already in the other group.
- Standing in the Dojo's training zone earns idle Speed, as the IVS workshop zone does (same rate rules). RETIRED
  2026-11-03: no passive gain (design doc 4.19).
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
- Until stamina ships, the racing Team is the single equipped character, so the rule applies to that one character.
- Owner 2026-10-30: an old save whose equipped character is also in the Showcase drops that character from the Dojo
  squad on load (the slot is left empty, stored as an empty entry or removed; owner 2026-10-30); the Team is unchanged.

## 6. Tracks and biomes

As in `docs/TRACKS_AND_BIOMES_SPEC.md` (lengths x1.25 per track, 10 anime biomes), placed along the spiral.

## 7. First impression pass (owner 2026-11-03, design doc 4.24)

Draft: `tools/blender/plaza/build_plaza.py` (1 Blender unit = 1 stud, positions are world studs), reviewed by the owner
before any Studio work. All values below are **proposed**. 34 unique meshes, about 27k tris; about 30k tris placed in the plaza at once, plus the 9 character rigs. Ledger: `tools/blender/plaza/plaza_assets.json`.
- **Sight line**: the spawn faces the gate across the 130-degree opening in the Dojo ring. The main path runs straight
  from the spawn to the StartPad. The SpawnLocation stays at the plaza centre and the StartPad stays where it is.
- **Start gate**: torii about 2x taller and turned to face the spawn along the path. Footprint stays clear of the road.
- **Path**: 12 wide, with a row of small torii, stone lanterns and lantern strings. Series banners stand by the Legends.
- **Spawn**: a circular stone mosaic with an abstract pattern, no symbol.
- **Legends**: 6 pedestals, 3 on each side of the path, each with the top character of one Series, about 9 studs tall. Client-only, like the sky-loop runners. Sea uses Lufy (`sea_captain`; owner 2026-11-03).
- **Sky loop**: a raised ribbon above the plaza at radius about 62, height about 30, carrying the client-only runners.
- **Wayfinding**: RACE START banner on the torii under its tie beam; MARKET entrance arch on the Market's plaza side (posts
  clear of the mosaic, about 24 tall). Client/PlazaWayfinding draws the two floating labels from `PlazaAssets.Landmarks`
  as client-only attachments, so streaming never hides them.
- **Sensei**: moves further along the path (`CheckpointConfig.NPC_POS`) to clear the Legends.
- **Trees**: one Great Sakura plus smaller sakura, all clear of the road and the plots.
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
- `dojo`: squad of 3 not in the Team, cross-rejection, multiplier unchanged.
- Track tests per `TRACKS_AND_BIOMES_SPEC.md`.
