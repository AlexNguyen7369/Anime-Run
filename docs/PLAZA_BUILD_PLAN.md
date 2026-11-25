# Plaza build plan (WORLD_REDESIGN_SPEC 4.2, design doc change log 2026-11-25)

A plan, not a rule: the spec and the design doc win. Built so far (offline only, no Studio): the Index, Team altar and
statue moves with their headers, the boss gate's Parts stand-in, state and prompt, the merchant markers, and the guide. Gate and
guide are off (`BossGateConfig.LIVE`, `BossGuideConfig.LIVE` = false). No mesh is uploaded, no place saved. Numbers are measured from the
draft scripts at 03148343 (headless Blender); "proposed" where no owner word exists. Guards: `plaza_build`; 23 waiting checks: `plaza_build_pending` (on demand, `PlazaBuildTests.PENDING`),
`spawn_area` RING rows and EXCLUSIVE_XZ, `ui_billboards` headers.

## 1. Pieces (studs, y up; tris)
| Piece | Keys (proposed) | Tris | Size, top | Body colours, glow names |
|---|---|---|---|---|
| World gate B | WorldGateLocked, WorldGateOpen | 10,060 / 8,148 | 35.5 x 29.6, 36.5 | 31, 2 |
| Boss gate A | BossGateClosed, BossGateOpen | 10,662 / 9,970 | 35.3 x 29.6, 34.7 / 37.0 | count at export, 0 / 5 |
| Altar B (World 1) | AltarGreatLotusLocked, Unlocked | 7,928 / 9,652 | 66 wide (lily pads), 56.1 / 60.3 | 41, 4 |
| Altar A (World 2) | AltarTwinRoofLocked, Unlocked | 8,884 / 7,468 | 67 wide, 74.5 | 22, 4 |
| Markets B | SHOPStall, POTIONSStall, MarketStall, IndexBoard, SenseiDais | 1,856 / 3,145 / 3,462 / 2,592 / 432 | tops 13.0, 14.0, 15.4, 13.7, 6.2 | 45, 7 (with the draft figures, which do not ship) |
| SkyLoop, LegendPedestal | same keys | as today | posts at 19, 75, 200, 250, 322 | as today |

- Mesh parts are one Body plus one per glow colour (`export_asset`). A lone locked/open pair costs two assets, one shown at a time.
- The altar's two worlds need four assets; a server loads two (its own world's). Both states are loaded: locked is per player.
- Palette: `build_plaza.palette()` holds 64 colours (8 x 8) and asserts. Today's PAL plus the four drafts' is past 64, and a
  changed palette changes no geometry hash, so `upload_plaza.py` would not notice. Proposed: one 64-colour palette per set
  (plaza as today, gates, altar A, altar B, markets); each fits by the counts above. Draft names collide between sets
  (`k1`, `c1`, `gd1`), so sets stay separate namespaces. Glow colours are part colours, not palette cells.
- Two worlds: gate B's glow is violet in World 1 (to World 2), cyan in World 2 (to World 1): `PlazaLook.Glow`, no second mesh.
  Both states are only needed in World 1: World 2's gate is always open.

## 2. Build scripts
1. `build_plaza.py`: INDEX, Team altar, PEDESTAL and the posts to the fuller layout; `LoopPosts` in layout.json; drop the old
   stalls and index from SHIP. `upload_plaza.py` writes `LoopPosts`.
2. New `build_spawn_pieces.py`: the shipped functions lifted out of the draft_* files (gate concept_b, boss gate, altar
   concept_a and _b, b_shop to b_sensei), each set with its own PAL; no figures, context, cameras or renders. Draft files stay.
3. Its export joins `export_all`'s SHIP with a palette per set and states as separate keys; only some keys are Placed.
4. The sensei's dais and the merchant step behind a counter (draft_merchants.py stall()) are part of the stall meshes.

## 3. Game code
| File | Change |
|---|---|
| `SpawnArea` | world gate: box touch part in the doorway, barrier, plain stand-in, label up; BossGate stand-in with `OpenBosses` and `TalkBossGuide`; INDEX_POS, TEAM_ALTAR_POS; altar stand-in per world with `Look` and ModelSpot; MerchantSpot attachments; the sensei dummy goes |
| `PlazaDressing` | REPLACES for the gates, altar and sensei dais; stand only the assets this world and state need |
| `PlazaAssets` | generated only, never by hand |
| `PlazaAccents` | STALLS eaves and wall screens are from the old meshes: new local numbers, or drop them (owner: accents on set B are undecided) ; the islands and rift stay, see faults |
| `PlazaWayfinding` | Index and Team headers move; SIDEKICKS header over the new altar; roof heights checked against `ROW` heights |
| `PlazaPrompts` | `OpenBosses` runs what the Bosses button runs; that code is local to `BossEventUi` and not in `PanelSwitch`, so it is exposed first (no behaviour change) |
| `BossEventUi` / new `BossGateView` (client) | closed or open look from the event phase and `SidekickConfig.HudFromRebirth`, per player |
| `SidekickAltarView` | MODEL_SIZE (7; drafts show 17.5 and 25), locked and unlocked mesh per player, lock label spot |
| `PlazaSkyLoop` | statue follows `PlazaAssets.Exclusive`; check runners against the moved posts |
| `LeaderboardConfig` | no change: Best Roll stays |
| New `Shared/PlazaMerchants` | stall -> id, pose, scale; new client view clones `CharacterModels`, anchored, no collide, touch or query |
| `CharacterModelService` | Frierin (`fr_mage`, World 2) must load in World 1: the 4.47 "every world shows" list is an open rule |
| `LoadingScreen` | preload list, if it names plaza keys |

Collision: meshes never collide (PlazaDressing). Stand-ins carry it: gate jambs, dais (walkable step), the boss gate's SILL of
4.4 needs steps a runner can climb, altar tiers to the new radius (18.4 for B), stall counters and back walls. Altar B's lily
pads reach 33 studs: check them against the sky-loop post and the boss gate (14.7 clear in the draft report).

## 4. Faults to fix while building (blind reviews)
| Fault | Proposed fix | Needs owner |
|---|---|---|
| S4 base 0.2 from the south edge | move inward 1 to 2 studs along the spawn axis; the test allows 2.5 and wants 1 clear | no if moved only; shrinking breaks "full size" |
| left pillar cut on the join view | 88% of the gate is in view on join (report.json); turning or moving it more than the tolerance is a layout change | yes |
| statue over RACE START, shadow on the spawn pad | spot is approved: lower pedestal, smaller rig, or a shadow-free statue | yes for spot or size |
| World 2 rock behind the horns | move that island in `PlazaLook.Islands` (placeholder values) | no |
| locked altar B statue near-black | `SidekickAltarView` LOCKED_COLOR and a light (placeholder values) | no |
| Index keeper's arm through staff | pose values in PlazaMerchants | no |
| locked label readability | altar lock label size and spot | no |

## 5. Tests
- Red now: see the header. Guards in `plaza_build` stay green: stall positions, facings and prompts, gate place and lock rule.
- Written: boss gate on and off, closed or open by phase and rebirth, closed prompt does nothing, the look (`plaza_build`); guide text
  grants nothing (`boss_guide`); the client wiring (`ui_boss_gate`, `ui_boss_guide`, neither run in Studio yet).
- To write with the code, before each step: header heights over roofs; altar locked look per player (UI); Frierin loaded in World 1 once
  the 4.47 list is ruled; `world_layout` unchanged (the plaza still clears the roads); UiTeam's `TeamAltar` check only finds the
  model by name and stays green. Best Roll, the gate pad, the sensei's spot and `boss_arena` are not touched.

## 6. Order
1. Spec text first (lead): WORLD_REDESIGN_SPEC 4 ring slots and the terrace statue spot, 4.2 "Positions stay", design doc 4.43
   and 4.45 still give the old spots.
2. Layout and stand-ins (no upload): positions, headers, boss gate stand-in, box touch part, spots. Green: RING, EXCLUSIVE_XZ,
   stall_, gate_ (not mesh), boss_gate_ (not mesh), merchant_.
3. Boss gate client behaviour and the guide's dialogue (text needs the owner).
4. Merchants. 5. Build scripts, export, rules audit. 6. Owner: upload, then PlazaAssets, then the mesh tests. 7. Studio and captures.
   The statue's Pos moved ahead of the mesh (2468a9a6, PlazaAssets from a fresh export, no upload); LoopPosts and the moved
   posts did not, they come with step 6. A gate mesh may only stand while `BossGateConfig.LIVE` is true.

## 7. Owner items
Uploads: about 8 to 16 new assets (the table), re-upload of SkyLoop and the stalls. Copies in both places' `ServerStorage.BakedModels`
and place saves. Rulings: 4.47 "every world shows"; Kakashe's size and header; guide text; accents on set B; the two layout
faults above; altar model size 17.5 or 25 against 7.
