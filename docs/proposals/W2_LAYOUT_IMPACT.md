# World 2 layout change: what it breaks and what it forces us to redo

A read-only analysis (2026-11-26), not a rule and not a layout. It was asked for because the owner finds the World 2 tracks
much too close together and wants wide spacing, possibly straight tracks, and little to no overlap. Layout options are
agent-1's (orch/world2/w2-wide-layout). Read from feature/alex/world2-place at c726534f. Branch tips read:
orch/world2/w2-skies, orch/world2/w2-t1-neighbours 54bf89f3, feature/alex/w2-reexport e881c688.

Two cases are measured below:
- **(1) Rigid:** each track keeps its shape and is moved and turned whole. New connectors join a finish to the next start.
- **(2) Reshape:** the tracks' segments change, for example straight tracks.

Effort: S is under half a day, M is one to two days, L is three days or more, or a full review loop with the owner.

## Summary

- **(1) cannot be done under the fixed rules.** "Each track starts on the previous finish" and "target length ±5%" together
  leave too little road for any connector that separates the tracks. The lead-in roads would have to be several times
  longer than the 5% slack, so the chain must be reshaped anyway. That is case (2). Details are in the next section.
- **Doing (1) needs a rule change from the owner.** A connector road would sit outside every track and would not count
  toward any track's length. The owner would have to rule on whether it is raced, paid, timed or run by the NPC. The
  connectors would also need new shared engine code: Main, PathDriver, NpcRacer, Tunnel and RaceService all assume each
  track starts on the previous finish.
- **Under (2), the code side is mostly automatic.**
  - Things that follow the layout with no change: checkpoints, win pads, the NPC lanes, the runner rail, terrain
    corridors, sky zones, the baseplate and the progress map.
  - Things that must be redone: World 2's own track files and tests, plus regenerated harness data.
  - The code cost that is not automatic is terrain and memory. Their cost grows with the area of the layout's bounding
    box, not with road length.
- **The real cost of (2) is the art.**
  - All ten approved render sets are tied to the current road. So are every Draft placement, the hero moves, the
    "no spot" list, the cross-track fixes, the Track 5 kaiju site and the Track 6 landmark. All of these must be laid out
    again, rendered, scored and approved by the owner again.
  - Uploaded meshes do not need re-uploading. Only their placements change, apart from a few meshes fitted to one
    stretch of road (listed below).
- **The current spiral is close to the best that turning alone can do.** I turned each track about its joint in 10° steps
  and searched greedily. With no added road, the nearest other road stays 70-280 studs away, about what it is today.
  Wide spacing needs new road, and new road has to fit inside the ±5%.

## Is (1) possible under "each track starts on the previous finish"?

Rules involved:
- design doc section 3, about line 37: "Numbered, point-to-point track chain; each track starts on the previous finish";
- TRACKS_AND_BIOMES_SPEC "Lengths": target `984 x 3 x 1.25^(n-1)`, ±5%, measured along the centre line by
  `TrackValidator` TARGET_LENGTH. Fixed (owner 2026-10-30).

Code that hard-wires the rule (all shared with World 1):
- `Main.server.luau:77-83`;
- `NpcRacer.ChainEntries`;
- `Tunnel.luau:87`;
- `PathDriver.Chain`, which drops each later track's first point because it equals the previous finish;
- `tools/blender/world2/chain.py`.

The ways a connector could fit:
- **Connector outside any track: breaks the rule.** The next start would no longer sit on the previous finish. It also
  breaks `PathDriver.Chain`, so the runner rail would jump across the gap.
- **Connector as the first segments of track N+1, with the rest of N+1 moved whole: keeps the rule.** It is technically
  case (2), confined to the start of each track. The validator also needs the first segment to be a Straight of at
  least 40 studs, and every turn to keep the minimum radius.
- **The length budget for such a lead-in is only the +5% slack.** The rest would have to be cut from the track's own
  segments, which is a shape change.

Current lengths come from the `chain.py` maths, run read-only:

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Length now | 2,952 | 3,697 | 4,613 | 5,766 | 7,207 | 8,720 | 11,261 | 14,076 | 17,595 | 21,994 |
| Room to +5% (studs) | 148 | 178 | 231 | 288 | 360 | 739 | 563 | 704 | 880 | 1,100 |
| Width of its box now (x × z) | 628 × 592 | 928 × 1,010 | 1,228 × 1,336 | 1,592 × 1,638 | 1,854 × 1,910 | 2,184 × 2,274 | 2,773 × 2,606 | 3,254 × 3,834 | 4,621 × 6,447 | 8,321 × 8,296 |

What this means for case (1):
- **The tracks are nested rings.** Each track's box contains the one before it.
- **Un-nesting a ring costs about its own width in new road.** To stop ring N+1 from enclosing or crossing ring N, it must
  move roughly that far: about 900 studs for Track 2 and 8,000 for Track 10.
- **The slack is 148 to 1,100 studs.** That is 3 to 8 times too short for every track.
- **So (1) under the fixed rules collapses into case (2).** The cut road has to come out of each track's own shape.

Other rules touched:
- **Spiral rule.** Design doc 4.10 ("the track chain spiralling out from the hub's start gate", fixed) and
  WORLD_REDESIGN_SPEC section 3. The owner's tunable reading (2026-10-30) is that each track's mean distance from the
  plaza grows. `TrackChainTests` checks exactly that. Straight or wide layouts pass this reading if each track sits
  farther out than the one before. "Spiralling" itself is fixed wording, so the owner should confirm that a non-spiral
  chain still meets it.
- **WORLD2_SPEC "Tracks".** It says "Routes are World 1's (same segments, so lengths and the spiral hold)". Under (2) the
  owner changes this line, with its date.
- **Track 1's start.** It must stay within one road width (40 studs) of the start gate (WORLD_REDESIGN_SPEC 3, a
  placeholder). The plaza, gate and boss gate are placed from Track 1's start (`SpawnArea.Build(track1Start)`), so
  Track 1's start pose should stay at `CHAIN_ORIGIN`.

## Impact by item

"Auto" means the code reads the layout and follows it with no edit, but its tests must still be re-run.

| # | Item (files) | (1) rigid moves + connectors (rule change) | (2) new shapes | Effort (1) / (2) | Owner approvals needed again |
|---|---|---|---|---|---|
| 1 | **Track files** `src/shared/Tracks/World2/W2*.luau`, chain maths in `Main.server`, `NpcRacer`, `Tunnel`, `PathDriver.Chain`, `chain.py` | The track files stay. A connector concept is new shared code in five places, plus `chain.py`. It must not change World 1 (gate it on `WorldConfig.Id`). | New Segments in the 10 track files. The shared code stays. `chain.py` and `chain_check.json` are regenerated. | L / M | The layout itself. Rule changes: connectors in (1); "Routes are World 1's" and the spiral wording in (2). |
| 2 | **Biome drafts and approved renders** `tools/blender/world2/biomes/*.py`, `build_track.py`, `kit.py`, `chain.json`, `assets/world2_draft/track*/` | Props placed by distance along the road (`k.beside`, `k.along`) move with the track. But the biome scripts also hard-code **world** x, z: 74 such lines (ElvenPlains 11, HauntedTunnel 11, KaijuBase 21 and others), plus `k.field` scatter over the track's box. Re-running a build after a move puts those in the wrong place unless they are turned into track-local values first. Own-track game shots barely change. Every context shot changes. | Every road-relative placement lands somewhere new. Every hard-coded spot, sight line and "off every road" choice is void. All 10 render sets are rebuilt. | M / L | (1): the owner decides whether the 10 frozen approvals carry over, because the context changed. (2): all 10 render sets again, at the 7/10 reviewer bar first. Tracks 2, 4, 8 and 10 were approved as frozen rounds. Track 2 was approved at 6/10 as-is. |
| 3 | **Exported Drafts** `src/shared/BiomeThemes/World2/*Draft.luau` (track-local `Placed` rows) | Rows stay valid, because they are track-local. The cross-track drops and moves baked into them were made against the current neighbours, so a re-export could restore some dropped rows. That re-export is under the re-export hold. | All rows are regenerated by `export_props.py` from the new drafts. | S-M / L | The re-export hold lifted for each track (owner). |
| 4 | **hero_moves.json** and the "no spot at the approved scale" list (WORLD2_SPEC "Ground ownership") | Moves are stored in track-local studs, so they still apply. But each move was found to clear **other** tracks' corridors. With wide spacing, most heroes could go back to their approved spots. The 10 "no spot" heroes (Track 1 Town and RuinedCastle, Track 2 ChainTower, Track 3 HeroHQ and Crater, Track 4 School and OldWoodHouse, Track 5 DefenseHQ, Track 6 HQ, Track 7 IslandVolcano) may now have a spot: a benefit. | Every From/To and the list are void. Each hero gets a new spot on its own track's ground under the same rules. | M / M | Each changed hero spot. The 2026-11-24 move rule is still only "coordinator's choice pending the owner". The HQ was left out by the owner's word and needs a new word to come back. |
| 5 | **cross_track.py and cross_track.json** (Track 6 LANDMARK, FILL, TURN, ground fixes for the swapped Tracks 1 and 6) | LANDMARK, TURN and `at()` spots are **world** coordinates (for example the Mansion at (-943.8, 960.0) and the Office at (-226.5, 1169.4)). They must be turned into track-local values or recomputed. The fix and fill passes exist because of neighbours, so they mostly become moot. | All void. Landmark spots are picked again at the 0.06 bend and the 0.9 finish of the new road. | M / M | Track 6 lit landmark spots (only **proposed** now; the concept was approved 2026-11-25 and the merge 2026-11-26). The rows dropped or moved by the fix and fill passes. |
| 6 | **The kaiju** (Track 5 GiantCorpse, `kaiju_export.py`, `KaijuBaseDraft` rows; uploaded Model 130671695538312) | The mesh and its 2 placements are track-local and stay. The open "kaiju overlaps other tracks' props" question is likely resolved by the spacing. The 12 fill props ("A with 12") and the dropped vans were chosen against neighbours and could be reopened. | The site was "sized to fit a legal spot" on the current road, so a new site is needed. The mesh (311 × 150 × 116, owner-locked) stays, so there is no re-upload. The crushed buildings, rubble, crew and fill go around it again. | S / M-L | (2): the new site's reference renders (owner); the fill and van rulings again. The mesh, shape, size and colour stay locked. |
| 7 | **Ground-ownership ruling** (owner 2026-11-25, nearest centre line owns a spot) | The rule stays. Contested ground mostly disappears. The "full count to the owner before any frozen track changes" still applies. | The rule stays. Every result is recomputed. The plaza ground question stays open. | S / S | None for the rule. The full count goes to the owner before frozen tracks change. |
| 8 | **BiomeThemes data** `src/shared/BiomeThemes/World2/<Key>.luau` (Terrain, Ground, Lights, Assets ledger) | No coordinates here; only the Draft files hold them. World 2 themes have no terrain `Sections`, so the "Inner side faces the plaza" winding rule in `TerrainShape` does not apply. | Same, except the Lights rows, which come from the Draft and are regenerated. | S / S | None. |
| 9 | **Terrain** `src/shared/TerrainShape.luau`, `src/server/TerrainBuilder.luau` (corridors, grass strip, zones) | Corridors, the grass strip (`BARE` 24, `SLAB_BARE` 2) and zones are stamped from every centre line, so they follow automatically. But the grid is **dense over the whole bounding box** (10 bytes per 8-stud cell). Terrain writes one 256-stud chunk per frame over the box plus a 900-stud skirt. Today that is about 11.5 MB and about 1,600 chunks (the "about 25 s" in the code). A 25,000 × 25,000 layout would be about 100 MB and 11,000 chunks, about 7× the write time. The gap shape assumes laps about 150 studs apart (`MIDLINE` 77, "about the gap midline"; the `Far` shape only past the last track). Wide gaps become flat ridge plateaus. Spawn order is by zone, then distance from the origin. | Same, plus any per-track terrain choice tied to a stretch. | M-L / M-L | The look of the land between tracks is new art direction (owner). Memory and time limits need checking in Studio. |
| 10 | **Checkpoints, win pads, start lines** (`TrackBuilder.Build`, `CheckpointBox`, `CheckpointService`) | Auto. They are built from each layout's end pose. A connector outside the tracks would need its own rule (is it raced? does the checkpoint stay at the track's finish?). | Auto. Each last segment must still be a Straight of at least the checkpoint length plus margin. | S / S | Connector pay and checkpoint rules in (1) only. |
| 11 | **Boss gate and plaza** (`SpawnArea`, `BossGateConfig`, `BossGuide`) | Unchanged if Track 1's start stays at `CHAIN_ORIGIN`. | Same. Track 1's first straight must still clear the plaza (chain test against the live SpawnArea). | S / S | None, if Track 1's start stays. |
| 12 | **Camera** (CAMERA_SPEC; the run camera follows the rig) | No geometry dependence found. The progress map (`RaceProgressMap`) draws from the layouts automatically. Its view span should be checked on long straights. | Same. | S / S | None. |
| 13 | **Sky zones** (orch/world2/w2-skies: `TrackSkyConfig`, `BiomeEnvironment.ZoneAt`, `World2SkyTests`) | Auto. The zone is the nearest track, or `RunTrack` while racing, and the tests pin no positions. Wide gaps mean zones switch at the gap midline in open land. | Same. | S / S | None for the code. The Studio sky check (owner choice F) is done on the final layout. |
| 14 | **Safety baseplate** (`Main.server.luau:188-229`, 2048-stud tiles over the box plus a 64 margin) | Auto. More tiles with wide spacing, still fine. Very large coordinates are a float-precision risk to check in Studio. The Blender exporter already notes speckled shadows at 400k-stud offsets. A straight-line chain of all 98k studs would reach about ±49k. | Same. | S / S | None. |
| 15 | **NPC paths** (`NpcRacer.LanePath`, `NpcConfig.World2`) | Auto inside tracks. A connector outside the tracks needs a rule: does the NPC run it, and does it count in the NPC's known time? NPC time is length ÷ speed. | Auto. NPC time changes only as far as length moves inside ±5%. NPC speeds stay (Tracks 2-8 are placeholders). | M / S | (1): the connector's NPC rule. |
| 16 | **Track tests and TrackValidator** (`TrackValidator`, `TrackChainTests`, `TrackLoadTests`, `ServerTest/TrackTests/*`, `World2ProofTests`, `Scenarios.chain`) | The validator is unchanged. Chain tests assume contiguity (60-stud `JOINT` skipped) and need connector cases. | `TrackTests/` holds only World 1's ten track files. World 2 passes today because its routes **are** World 1's. New shapes need ten World 2 track tests written red first: length, validator, chain no-overlap, driven at Epic and Secret cruise. That is about 21 min of the full harness per world. If the owner wants a minimum spacing, it is a new rule: write it into the spec first, then add a test. Never loosen an existing limit. | M / M-L | A minimum-spacing number, if wanted (new rule). |
| 17 | **Harness data** `tools/blender/world2/chain_check.json` (CHAIN PARITY), `tools/lune/w2_road_warn_pins.json` (hits pinned by **world** position, Dropped counts per track), `tools/lune/biome_harness.luau` | Both files are regenerated. The pins change with every move. | Same. | S / S | None (data). |
| 18 | **Uploaded meshes** (`uploaded_assets.tsv`, 115 rows; `needs_upload.tsv` empty) | No re-upload. Meshes are stored about their own base centre. Only placements change. | No re-upload for nearly all of them; they are generic props placed again. Meshes that may be fitted to one stretch of road need a check: DemonCastle Gate (spans the road, 30 studs each side), RuinedCityZ Overpass, DevilTokyo CrossWire and StreetKit, MonsterDen Ceiling, FleshWall and MineRail, HauntedTunnel TunnelSeg and Portal, Track 1 Mountain_p1-p3 (cut by the 2048 limit at its **placed** scale: a new scale means a new cut and a new upload). | S / S-M | Uploads, if any, under the asset ledger rules (owner's upload word). |
| 19 | **orch/world2/w2-t1-neighbours** (5 ahead, 10 behind; `t1_neighbours.py`, `cross_track` and `roads` changes, pins) | Moot: it fixes contested ground with today's neighbours. Do not merge; keep the branch for reference. | Moot. | — / — | None (it was never approved; scoring is on hold). |
| 20 | **feature/alex/w2-reexport** (85 ahead, 5 behind; colour re-bake of 119 meshes, `upload_reexport.py`) | Not affected. The bake is about vertex colours, and the mesh shapes do not depend on placement. It should still land before new placements are exported, so the meshes go in once. | Mostly not affected. The six meshes with unexplained hash changes are still open. The Track 1 Mountain pieces follow the placed scale (item 18). | — / S | Unchanged: the colour re-upload batches (owner). |

## What the owner would be asked again

1. **The layout.** Choose (2), or change the rule to allow (1)'s connectors and say how they are raced, paid, timed and
   run by the NPC.
2. **Rule wording.** "Routes are World 1's" (WORLD2_SPEC) and "spiralling out" (design doc 4.10) under the new layout.
   Also a minimum spacing number, if the owner wants one tested.
3. **Render sets.** All ten again under (2), first through the 7/10 reviewer bar. Under (1), whether the frozen approvals
   carry over.
4. **Placements.** Hero spots (hero_moves and the "no spot" list, including whether the HQ returns), the Track 5 kaiju
   site, its fill and its vans, and the Track 6 landmark spots.
5. **The re-export hold** for each track, and any re-upload (Mountain pieces at a new scale).
6. **The look of the land** between widely spaced tracks (terrain gaps).

## Suggested order (if (2) is chosen)

1. Lay out the new chain in the track files, and check it with `chain.py` and the validator rules.
2. Write World 2 track tests, red first.
3. Check terrain memory and write time on the new box in Studio. Make the grid sparse if needed: shared code, so check
   World 1 does not change.
4. Turn the biome scripts' hard-coded world spots into road-relative or track-local values.
5. Rebuild and render each track, review it at the bar, and send it to the owner.
6. Re-export after the colour re-export has landed. Regenerate `chain_check.json` and the pins.
