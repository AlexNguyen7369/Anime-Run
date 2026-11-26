# World 2 render audit (2026-11-26, Studio, diagnosis only)

Branch orch/world2/w2-render-audit off feature/alex/world2-place (c726534f). One Play run of World 2's Studio with every track
built and the terrain ready (26 s). The test keys were set for the run and cleared afterwards; nothing was saved, published or
uploaded. Pictures: `assets/world2_draft/audit/render_2026-11-26/`. Each is one run-camera view at 45% of the track (12 up,
30 back), plus T7's climb.

Owner priorities (2026-11-26): 1 ground, grass and z-fighting; 2 other tracks crowding the view (agent-1's wider layout);
3 dark props (colour export). Pop-in and missing scenery come last.

## What holds (measured in Studio)
- **Grass fix holds on all 10 tracks.** I sampled 272,701 points on and beside the roads. No Grass lies under any road, slab,
  checkpoint or WinPad. Grass starts 0 to 4 studs past the road edge (under the wall and the planned brown strip) and
  sits 2 studs below the road top. `Terrain.GrassLength` is 0.7. T2 and T8 have 15 and 3 such edge columns. The plaza
  floor has Grass only outside its own edge.
- **No terrain pokes through, or lies flush with, any road, slab or checkpoint.** The count is 0 on all 10 tracks.
- **No road-on-road z-fight.** Overlapping road segments always share colour and material.
- **White-mesh fix holds.** All 10,524 placed World 2 MeshParts are white (none grey) and untextured.
- **No missing meshes and no fallback parts.** All 114 placed mesh keys loaded (from BakedModels in Studio). No
  `[BiomeAssets] failed / took over` warnings.
- **No stand-in colour showing.** No fallback parts are built, so the kaiju's STANDIN faces cannot appear.

## Faults
"Layout" says whether the fault and its fix survive the tracks being laid out again wider.

| Track | Fault | Cause | Proposed fix | Upload | Risk | Layout |
|---|---|---|---|---|---|---|
| 2, 3, 4, 5, 7 | **Dark boxes cut through the road on every climb** (priority 1). They show as dark stripes or steps across the asphalt. Measured: T2 Fill 20 parts, up to 0.65 studs above the road surface; T3 Fill 12, 0.36; T4 Fill 20, 0.39; T5 Pier 34, 0.90; T7 Bank 121, 1.60. Seen in T2, T5 and T7 pictures | The draft's road supports (`_fill` in DemonCastle, RuinedCityZ and HauntedTunnel .py, `_bank` in AntIsland, `_pier` in KaijuBase) are flat-topped boxes. Each top is at the road's height at the box's centre, but the road slopes (up to 13 degrees), so the downhill half of each box sticks out of the road. TrackBuilder's own `Supports` already do this job correctly: they are kept `SUPPORT_CLEARANCE` (0.05) under the lowest road underside | In the game (code only): after a track builds, cut every draft road-support prop down to `SUPPORT_CLEARANCE` under the lowest road underside over its footprint. Use TrackBuilder's rule, read from the built road, so it holds for any layout. Then add a Studio check: no visible part (props and supports) may cross a road's top surface. Alternative: fix the 5 generators and regenerate the 5 Drafts | n | Low: the boxes stay as the ground under raised road. Where a box would end up thinner than 0.2 studs it is removed, and TrackBuilder's supports still fill under the road | survives (computed from the built road) |
| all 10 | Finish apron (`CheckpointArea`) lies 0.05 studs over the road | TrackBuilder lifts the apron 0.05 over the road. That is fine up close; at a distance, depth precision may flicker | Not now: no flicker was seen. Recheck once in a far view | n | Low | survives |
| 1, 2, 3, 4, 5, 6, 7, 8 | **Other tracks' scenery fills the view** (priority 2): T1 T3's towers and T2's magenta crystals; T2 T3 and T6 high-rises; T3 T5's kaiju and T2's red spires; T4 T3's towers; T5 T6's city and T4's water towers; T6 a neighbour's green strip and wall; T7 T9's orange city and T6's flats; T8 T9's orange city. Also a T7 Ant stands about 59 studs over T8's road. T9 and T10 were clear in their pictures | Tracks lie about 150 studs apart, and every track's tall props are seen from the next | agent-1's wider layout. Nothing to do here | n | - | layout-dependent: gone or changed after the re-lay |
| all 10 | **Dark and over-saturated props** (priority 3). For example, near-black pines (T1), cedars (T4), ramparts (T2), doors (T10) and brush (T7), and orange-on-orange GoldenCity (T9, also seen from T7 and T8) | Every uploaded World 2 mesh still ships linear COLOR_0 (W2_VISUAL_BUGS w2-dark-props). The white fix is in; the re-export is not. The list per track is below | Re-export batches 1 to 10 (W2_REEXPORT_PLAN). On hold: no upload | **y** (100 meshes) | As the plan: moderation, and the 6 hash mismatches | survives (colours live in the mesh) |
| all 10 | **Sky is the stock skybox on every track** (`rbxassetid://6444884337`). T10 (red sky by design) shows blue with an orange band; T2 (purple-black by design) shows blue | orch/world2/w2-skies (12 skies, haze 0.22 / 0.5) is not merged into world2-place | Merge w2-skies once the owner has seen the toned-down pictures | n (already uploaded) | Low | survives |
| all 10 | No fog. `FogEnd` is 100000; distance fade comes from Atmosphere only (day: Density 0.30, Haze 1.0; night T4, T6, T8: 0.22 / 0) | By design: `LIGHT_FLOOR`, and the skies branch sets haze | None, unless the owner wants far tracks faded. Fog would also hide crowding, but the re-lay is the fix for that | n | - | survives |
| 4, 6, 8 | Night tracks read dim. Dark props merge into the night (T4's black cedars). Shadows are on (Brightness 2, Exposure 1.1) | Dark COLOR_0 plus approved dark palettes (W2_VISUAL_BUGS: judge after the re-upload) | Judge again after re-export batch 1. Lighting floors were set with the dark meshes in view | n | - | survives |
| 6 | Flat solid-orange discs at the lamp-pole bases read as paint, not light | Draft glow pads (opaque parts, not light) | Owner's look call: leave, make them Neon at lower transparency, or remove | n | Low | survives |
| all 10 | Shadow casters: T3 417 of 418 meshes, T5-T8 every mesh, T10 1,627 | `Kit` CastShadow restore and defs (owner's performance call in the handoff, not a look fault) | None for the look. Phone frame time is still unmeasured | n | perf | survives |
| all 10 | (last) Pop-in: placed meshes stream Nonatomic; heroes are Atomic + SLIM; `StreamingTargetRadius` is 1024; all 10,524 MeshParts are RenderFidelity Automatic | By design (BIOME_ENVIRONMENT_SPEC 8, design doc 4.18) | None found. A parked camera saw an empty T8 only because my ReplicationFocus was elsewhere (an audit artefact). No real run was watched | n | - | survives |

## Dark COLOR_0 per track (priority 3)
Every mesh below is uploaded with the old exporter: placed, white in game, colour from linear COLOR_0. All 100 change when
re-exported (W2_REEXPORT_PLAN batches 1 to 10).
- T1 ElvenPlains (14): Flowers, Pine, Forest, FarWood, Cottage, HeroStatue, Rank, RuinWall, RuinedCastle, Town,
  Mountain_p1/p2/p3, Mound. Mountain_p1 and p2 are 2 of the plan's 6 hash mismatches.
- T2 DemonCastle (10): Gate, Hound, Wyvern, RuinA, RuinB, Chunk, Smoke, Rampart, Crag, Edge. ChainTower_p1-4 have no id and
  are not in the game. Hound and Wyvern are mismatches.
- T3 RuinedCityZ (12): BrickFlat, HeroHQ, Overpass, MidRise, OfficeBroken, HighRise, Collapsed, Barricade, Kerb, Rubble,
  Blocks, Crater.
- T4 HauntedTunnel (11): Cedar, Mountain, Guardrail, Mirror, TunnelSeg, Portal, School, Hospital, OldWoodHouse, House, House2.
- T5 KaijuBase (10 + 1): Apartment, Office, Rubble, SweeperVan, DefenseHQ, Hangar, BaseWall, Railgun, CityBlock, Smoke.
  GiantCorpse is outside every batch. Its round 5 mesh was exported by `bake_glb` without the sRGB change (no `linear`
  switch on kaiju-export or kaiju-land), so it ships the old curve too. Its look was approved as seen. **Open question:**
  keep it, or re-export it with the rest of T5.
- T6 DevilTokyo (11): HQ, Mansion, Apaato, ShopHouse, Konbini, Office, StreetKit, LowBlock, Retro, RoofTile, CrossWire.
- T7 AntIsland (11): IslandVolcano, Nest, Ant, Chamber, ThatchHouse, Ruin, Camp, Ship, Mound, Cliff, Brush. Nest and Ant are
  mismatches.
- T8 MonsterDen (12): Ceiling, FleshWall, LairTower, Coliseum, Shrine, MineRail, Graveyard, Colonnade, CityChunk, RockPillar,
  LavaChasm, BoneArch.
- T9 GoldenCity (11): RowA, RowB, CityBlock, Square, CityWall, Palace, Church, People, Wagon, Tree, Forest. Barrier has no
  id.
- T10 HellGate (10): DoorClosed, DoorOpen, SkyDoor, Hand, ArmA, ArmB, Astronaut, DarkGate, Grass, Hill. Abyss is black and
  unchanged.

## Not track faults (seen in the console)
- Boss models: "Failed to upload TexturePack (Referenced Asset 5 / 17 / 7)" (CharacterModelService's SurfaceAppearances).
- `rbxassetid://203785492` "Asset type does not match": it is not in `src`, so it comes from the saved place.

## Order proposed
1. Road supports cut under the road (code only, all tracks, layout-proof). Fix first.
2. Merge w2-skies (owner sees the toned-down pictures first).
3. Re-export batches (uploads, on hold) and GiantCorpse's question.
4. After the re-lay and batch 1: judge crowding, the night tracks and the lighting floors again.
