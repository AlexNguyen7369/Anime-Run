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
  (R15-style proportions, chibi head 1:3, placeholder), coloured from the character's series palette with a rarity
  trim. A `BillboardGui` shows the character's name (finite `MaxDistance`).
- The runner is anchored and moved by `RaceService` along the race path (the IVS rail already holds an exact speed
  everywhere): position on the right-hand lane, facing along the path, upright (up-vector Y = 1). No physics forces.
- Run animation is procedural and client-side (limb swing and bob from speed); it never changes the server pose.
- The player's avatar is hidden while racing, as before; the Humanoid stays for camera and respawn.
- Auras and trails attach to the runner's Torso instead of the car.
- Kept from IVS: exact cruise speed at once on every start / checkpoint / restart, stays within
  `MaxPathDeviation` of the path, pad paid once per pass, NPC race and banked money unchanged.
- Retired with the car: flip recovery (a rail runner cannot flip), car physics scenarios (`static_settle`, `accel`,
  `brake`, `skidpad`, `car_size`, `flip_recovery`, car lap bots). Replaced by `runner` scenarios (below).

## 3. World layout

- The spawn hub sits at the world centre. The 7 player plots form a ring around it. The track chain starts at the
  hub's start gate and spirals outward, one biome sector per track (Track 1 nearest the hub, Track 10 outermost).
- Every track, plot and the hub keep the IVS no-overlap rules; the safety baseplate covers everything plus a margin.
- Exact coordinates are chosen by the world build, inside these rules.

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
- New rule: a character is either in the Team or in the Dojo squad, never both. `SetTeam` and `SetShowcase` reject a
  character already in the other group.
- Standing in the Dojo's training zone earns idle Speed, as the IVS workshop zone does (same rate rules).
- Until stamina ships, the racing Team is the single equipped character, so the rule applies to that one character.

## 6. Tracks and biomes

As in `docs/TRACKS_AND_BIOMES_SPEC.md` (lengths x1.25 per track, 10 anime biomes), placed along the spiral.

## 7. Tests (written first)

- `runner`: body is a humanoid rig with no wheels / VehicleSeat / suspension; anchored; upright (up Y >= 0.999) on
  every track at normal and max stat speed; on path (deviation <= `MaxPathDeviation`); exact cruise speed; pad paid
  once; NPC rival uses the same rig.
- `scrap`: no `CarFactory`, `CarPhysics`, `CarConfig`, `VehicleSeat`, wheel parts or car assets in the place or in
  `src/`; no `Cars` collision group.
- `world_layout`: hub at the centre, 7 plots around it, Track 1 start at the start gate, no overlaps, baseplate
  covers everything, one SpawnLocation.
- `dojo`: squad of 3 not in the Team, cross-rejection, multiplier unchanged.
- Track tests per `TRACKS_AND_BIOMES_SPEC.md`.
