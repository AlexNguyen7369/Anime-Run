# Plaza build plan (WORLD_REDESIGN_SPEC 4.2, design doc change log 2026-11-25)

A plan, not a rule: the spec and the design doc win. Built so far (offline only, no Studio): the Index, Team altar and
statue moves with their headers, the boss gate's Parts stand-in, state and prompt, the merchant markers, and the guide. Gate and
guide are off (`BossGateConfig.LIVE`, `BossGuideConfig.LIVE` = false). No mesh is uploaded, no place saved. Numbers are measured from the
draft scripts at 03148343 (headless Blender); "proposed" where no owner word exists. Guards: `plaza_build`; no waiting checks since the merchants are on (owner 2026-11-25: "merchants can be added already to merge"; `PlazaBuildTests.PENDING` empty, `plaza_build_pending` left out of TestConfig),
`spawn_area` RING rows and EXCLUSIVE_XZ, `ui_billboards` headers.

## 1. Pieces (studs, y up; tris as exported, with the reversed copies of faces whose back shows)
| Piece | Keys | Tris | Box, top | Palette colours, glow names |
|---|---|---|---|---|
| World gate B | WorldGateLocked, WorldGateOpen | 10,306 / 8,403 | 35.5 x 29.6, 36.5 | 27, 6 |
| Boss gate A | BossGateClosed, BossGateOpen | 11,030 / 10,189 | 35.3 x 29.6, 34.7 / 37.0 | 25, 5 (open) |
| Altar B (World 1) | AltarGreatLotusLocked, Unlocked | 8,450 / 10,380 | 66.2 wide, 56.1 / 60.3 | 41, 4 |
| Altar A (World 2) | AltarTwinRoofLocked, Unlocked | 9,572 / 8,012 | 67.1 wide, 74.5 | 22, 4 |
| Markets B | SHOPStall, POTIONSStall, MarketStall, IndexBoard, SenseiDais | 2,198 / 3,865 / 3,980 / 2,700 / 504 | tops 13.0, 14.0, 15.5, 13.7, 6.2 | 33, 7 |
| Sky loop | SkyLoop | 1,996 | posts at 19, 75, 200, 250, 322 | its own set |

- Parts: Body (Body2 over 20,000 corners) and one per glow colour. A palette of at most 64 colours per set; glow is part colour.
- The closed boss gate is the approved draft as it was (owner 2026-11-25).
- World 2 shows WorldGateOpen with its glow in cyan (`PlazaLook.Glow`), no second mesh.
- Clear of the loop's new posts and ribbon (least 12.3 studs, the roof altar) and inside the floor (least 1.7, the boss gate), but the world
  gate: its box reaches 2.4 past the floor edge (eaves and dais; today's dais passes it too).

## 2. Build scripts
`piece_export.py` (palettes, splitting, reversed copies, `--check` renders), `build_gate_world.py`, `build_gate_boss.py`,
`build_altar_pieces.py`, `build_market_pieces.py`, `build_loop.py`: they reuse the approved drafts' geometry. `upload_pieces.py` has its own
ledger (`plaza_pieces.json`) and writes `Shared/PlazaPieceAssets`; it checks everything before the first upload, takes key names, `--dry`
and `--registry`. `upload_plaza.py` and its ledger do not know the pieces, so a plain run never sends an old stall over a new one.

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
| locked altar B statue near-black | done: `PlazaPieces.LockedLook`, per altar; colours owner-approved, no contrast limit (owner 2026-11-25, docs/OWNER_QUESTIONS.md 31); seen in Studio pictures | no |
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
