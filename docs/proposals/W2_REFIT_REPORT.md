# World 2 re-fit to the wide layout: round 1 report (Tracks 1-5 and 8-10)

A report, not a rule. Branch orch/world2/w2-refit. Layout: agent-1's square spiral, Segments 66856b89 (pitch 760, corner
420, first side 1,000, smallest road gap 656). Tracks 6 and 7 are agent-1's (orch/world2/w2-refit-b, merged here at
dc86cf89). Under the owner's nightly pre-approval (design doc change log, 2026-11-26) the lead approves re-placed scenery on
the owner's behalf for the owner's review on return. Nothing was uploaded and Studio was not used.

## What changed in the tools

- **Road-relative hand-set spots** (`roadframe.py`, `kit.spot`, `kit.heading`). Hand-set spots that were world x, z are now
  stored as distance along the road and offset from it:
  - Track 1: ranks, mounds, the horizon town, castle and massif, the behind-finish props;
  - Track 5: the two left-out Apartments;
  - Track 6: the landmark, the tower turn and the Konbini.

  On the approved chain they gave the same placements: Tracks 1, 5 and 6 matched instance for instance, with a maximum
  difference of 0.
- **The owner's ground rule (2026-11-25), applied at export.** A row whose base centre is nearer another track's centre
  line is left out, and a hero spot must be on its own ground (`export_props.owner_at`). The drafts' area scatters retry
  until each draw lands on own ground (`kit.owns`, `roadframe.Owners`), so the approved counts sit on the track's own band.
- **Checkpoints and plaza.** A mid prop whose box (grown by Prune's 8) meets a checkpoint area or the spawn floor is left
  out at export (`export_props.pads_hit`). This is what the game's Prune would remove anyway.
- **Review shots:** `game_shots.py` and `context_shots.py` take `--out=<folder>`.
- **Track 6 landmark search** (`cross_track.py` LANDMARK). The spots are now found on the road the chain lays out: the
  legal spot nearest the run camera's axis, turned to the camera as approved. On a straight that axis is the road itself.
  - Bend: a Mansion 900 ahead of the 0.06 eye and 102 off the axis.
  - Finish: an Office at 0.55, 430 ahead of the 0.9 eye.
- **Per-track fixes:**
  - Track 1: the ranks keep their approved turn to the road.
  - Track 2: the castle plinth is 300 from its road (was 340; own ground ends about 329 out). It is searched along that
    strip using the placed object's real turn and the export's own checkpoint and corridor tests.
  - Track 3: the hero apartment follows the road in a bend.
  - Track 5: the first kaiju site is 96 off the road (was 92).
  - Track 9: the city wall runs along both edges of the own band.
- **Supports:** agent-2's support generator is in (d2a3c1a5, d7cc8200). The square spiral has no slopes, so the Fill/Pier
  supports are 0.

## Counts (pass 3 Drafts, e3bab5e4)

| Track | 1 | 2 | 3 | 4 | 5 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|
| Rows now | 1,531 | 532 | 530 | 962 | 920 | 1,602 | 1,485 | 3,315 |
| Rows approved | 355 | 474 | 475 | 949 | 596 | 1,435 | 2,012 | 3,888 |

Hero moves (`hero_moves.json`, all re-found on the new roads):
- Track 1 RuinedCastle: 3,692 studs;
- Track 5 DefenseHQ: 1,700;
- Track 9 Church: 310;
- Track 10 DarkGate: 90.

Newly placed heroes: Track 2 ChainTower (cut into 4 pieces), Track 3 BrickFlat (kept), Track 4 School, OldWoodHouse and
Mountain, Track 5 DefenseHQ. Both Track 5 kaiju placements are kept.

No spot at the approved scale: Track 1 Town (1,440 × 992 in a band about 300 wide), Track 3 HeroHQ, Track 8 LairTower.
Track 10's Abyss (the dark dome) is never placed.

## Checks

- **Independent check over all ten Drafts** (12,948 rows): 0 on another track's ground by base centre, and 0 whose turned
  box meets a checkpoint area or the spawn floor.
- **Clearance:** the exporter's exact triangle test (24 lateral, 14 overhead) dropped every intruding row.
- **Biome harness (WORLD=2, pins rewritten with PIN=write):**
  - PIN: pass 11, fail 0, warn 30.
  - PLAZA, GROUP, SEAM and GRASS: pass.
  - ROAD: 5 fails, the heroes with no spot (Town, HeroHQ, LairTower; Track 6 HQ, Track 7 IslandVolcano).
  - TRANSFORM: 1 fail, GoldenCity Placed_573, with identical printed numbers.
  - W2 CHECKS: 1 fail, the `ElvenPlains Mountain_p3` ledger row is unused. The Mountain is off Track 1's ground, so the
    export cuts the unplaced mesh at scale 1, in 2 pieces. Dropping or keeping that uploaded row is the lead's call.

## Blind scores (three fresh reviewers, pictures only; bar 7)

| Track | Game | Context | Approved set |
|---|---|---|---|
| 1 Elven Ruin Plains | 6 | 3 | 8 |
| 2 Demon Castle | 7 | 5 | 8 |
| 3 Ruined City Z | 6 | 5 | 8 |
| 4 Haunted Tunnel | 7 | 3 | 7 |
| 5 Kaiju Base | 6 | 3 | 8 |
| 8 Monster Den | 6 | 4 | 8 |
| 9 Golden City | 6.5 | 3.5 | 7.5 |
| 10 Hell's Gate | 6 | 4 | 7 |

Near the road, the props, scales and mood match the approved sets. Several run views frame the road better than before
(Track 2's hound gate and dragons, Track 4 street fronts, Track 5's corpse and city canyon). No readable text, logos or
brands (design doc section 5).

The faults, worst first:

1. **Heroes out of the run views.** Track 1's ruined castle and Track 5's Defence HQ were moved by the hero rule to spots
   no camera sees. Track 8's tentacle tower (LairTower) has no spot. Track 9's church spire left its 0.62 view. Track 10's
   dark dome (Abyss) is not placed at all. Several heroes and sightline searches were made for the old roads, where the
   view ended in a bend.
2. **Empty ends of the long straights.** The 0.9 views of Tracks 1, 2 and 3 run to a bare horizon, and Track 5's 0.62 view
   is a bare stretch. The wide layout's straights are up to about 7,000 studs long.
3. **Overviews.**
   - Each track is a thin band along an open three-sided road with an empty middle. Other tracks own the middle.
   - GoldenCity's dome and ring are gone.
   - Track 2's overview is framed with huge foreground objects.
4. **Context: neighbours in view.** HellGate's floating doors and arms, the clouds, DemonCastle's tower and MonsterDen's
   trees show in other tracks' run views across the 656+ gaps. The context renders have no fog or streaming limit, so this
   overstates the game somewhat. Tall sky props still need a rule (height cap, or offsets toward the outside only).
5. **Smaller faults:**
   - pale, uneven road patches in Track 2's 01 view;
   - a lava pool at Track 8's road edge in 05;
   - Track 4's tunnel hill reads as flat black slabs;
   - grey pyramid rubble cones repeat along Track 5's barriers.

Proposed for round 2:
- Make each hero's spot search prefer the run cameras' views on its own band (Track 1 castle, Track 5 Defence HQ, Track 9
  church).
- Fit Track 10's Abyss and Track 8's LairTower to the band, or scale them down. A scale change needs the owner.
- Close each long straight's 0.9 view with that track's own props.
- Settle the sky-prop rule for the context views.

## Uploads (nothing uploaded)

- **Keep the uploaded Id (lead 2026-11-26); hash mismatch to check in Studio.** The old code makes the same GLBs, so these
  mismatches predate the re-fit:
  - Track 1 RuinedCastle;
  - Track 2 Hound and Wyvern;
  - Track 3 Crater;
  - Track 4 Mountain, School and OldWoodHouse;
  - Track 5 DefenseHQ and GiantCorpse (upload 7f2f942a…, the export gives f1d6a779… from old and new code alike).
- **New, to upload later (lead to arrange):** Track 2 ChainTower_p1, _p2, _p3 and _p4. These are pieces of a mesh over
  2,048 studs, now placed for the first time.
- **No re-upload needed:** the road-spanning and fitted meshes (DemonCastle Gate, Overpass, MonsterDen Ceiling, FleshWall
  and MineRail, HauntedTunnel TunnelSeg and Portal, DevilTokyo CrossWire and StreetKit) export unchanged. Track 1's
  Mountain pieces are unplaced; see the ledger row above.
- Tracks 6 and 7 (agent-1): no ledger row changed. Track 6 HQ and Track 7 IslandVolcano are not placed.

## Renders

`assets/world2_draft/relayout_2026-11-26/trackNN_<Key>/{game,context}/` (2e166615).
