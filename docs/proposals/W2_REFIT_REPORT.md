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

# Round 2 (Tracks 4, 5, 8, 9, 10: agent-3; Tracks 1, 2, 3, 6, 7: agent-1 on orch/world2/w2-refit-b, merged here)

Target from the lead: at least 7 in the game view on every track, from fresh blind reviewers.

## What changed

- **Hero spots.** `export_props.find_spot(prefer=)` prefers a legal spot that a run camera has in frame within 1,600
  studs (`seen_near`). On the wide layout, every hero spot must also lie on its track's Ground rectangle: the game builds a
  Placed prop only with its base centre there (`kit.in_ground`). Moves now: T5 DefenseHQ 60, T9 Church 310,
  T10 DarkGate 90.
- **Shrink to fit** (owner 2026-11-26, design log fe810a44, "Approve 1-4", item 2):
  - T8 LairTower stands at scale 3.45 (approved 4.2) ahead of the 0.62 camera, turn 0.
  - T10 Abyss has radius 500 (its rule's old floor was 800) ahead of the 0.9 camera. This is the first time it is in a
    Draft.
  - agent-1: T1 Town 1.015, T3 HeroHQ 0.562, T7 IslandVolcano 0.389, T6 HQ back at its legal spot.
  - Every hero is now placed: biome harness W2 ROAD 57/0.
- **Own-band backdrop** (`kit.band`). Each biome's approved backdrop props, at their approved scales, fill out to the
  ground midline (about 380), on own ground and on the Ground rectangle:
  - T4: cedars;
  - T5: far city blocks;
  - T8: cavern pillars, ruins and flesh walls;
  - T9: golden forest past the wall;
  - T10: hills and hands.
- **Export rule.** Non-hero rows off the Ground rectangle are left out. The game never builds them, and the game renders
  never drew them.
- **Ledger.** The `ElvenPlains Mountain_p3` row is out of the live rows, with its uploaded id kept in a note (lead).

## Counts (final Drafts, all ten)

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Rows | 1,019 | 980 | 1,021 | 1,191 | 963 | 938 | 1,123 | 1,734 | 1,395 | 2,620 |
| Approved | 355 | 474 | 475 | 949 | 596 | 765 | 1,718* | 1,435 | 2,012 | 3,888 |

\* T7's approved Draft count as committed before the re-fit.

Why some tracks are above or below their approved counts:
- **Above** (T1, T5, T8): each track now owns a band about 380 studs each side of its road. Before, it owned about 60 to
  75 in the spiral's gaps, so the approved rows were mostly near the road and many were cut by the cross-track rules.
  The new rows are the same props over about five times the ground.
- **Below** (T9, T10):
  - On the approved layout, T9's city grid and T10's sky-door rows covered the whole box of the spiral. In the old game
    most of those rows stood on other tracks' ground or off the Ground rectangle, so they were never built.
  - On the wide layout they are left out of the Draft instead: T9 city blocks and forest outside its band; T10 inner-side
    sky doors over Tracks 8 and 9, and rows past its Ground rectangle.
  - Near the road, the density matches the approved sets (reviewers, below).

## Checks

- **Independent check over all ten Drafts** (12,984 rows): 0 on another track's ground, 0 meeting a checkpoint or the
  plaza, 0 off the Ground rectangle.
- **Biome harness (WORLD=2, pins rewritten):**
  - W2 13,511/0, PLAZA 15/0, ROAD 57/0, GROUP 7/0, SEAM 1,884/0, GRASS 98,718/0, PIN 11/0 (36 warn).
  - TRANSFORM 12,983/1: GoldenCity RowB at y 31 prints identical numbers; it is unchanged from round 1.

## Blind scores, round 2 (fresh reviewers; pictures only; approved sets and the old in-game sets as references)

| Track | Game | Context |
|---|---|---|
| 4 Haunted Tunnel | 7 | 6 |
| 5 Kaiju Base | 7 | 6 |
| 8 Monster Den | 8 | 7 |
| 9 Golden City | 7 | 5 |
| 10 Hell's Gate | 7 | 6 |

agent-1's tracks (their reviewers): T1 7/7/6, T2 7/7/7, T6 7/8/7; T3 and T7 re-worked (see their report).

Open faults on my tracks:
- **T4:** the approved mountain ridges cannot fit a 380 band at their scale; there are flat boxes behind the tunnel portal
  (as approved).
- **T5:** the Defence HQ is hard to pick out in the run views. The highway is no longer raised: the square spiral has no
  slopes, so there are no piers.
- **T9:** the band reads thin from above. Its city wall is at 290 with forest beyond.
- **T10:** the sky doors form straight rows (as in the old game) and are thinned over the other tracks' ground.

**Context.** Every track scores 5 to 7. Neighbours' tall pieces show in the run views: T10's doors and arms, its Abyss
dome (now placed), T8's pillars, and clouds. These renders have no fog or draw distance. The proposed sky-prop rule
(WORLD2_SPEC) checked by geometry (`sky_check.py`) finds 700 rows over 300 studs within 1,500 of another road:
- T10 sky doors 545;
- T8 rock pillars 116;
- T2 smoke, wyverns and tower 20;
- T3 high-rises 10;
- T7 mounds 5;
- T8 LairTower, T9 Church, T10 Abyss and one T10 arm, 1 each.

Enforcing the rule as written would strip most of T10's approved sky doors. The thresholds, and the game's fog, need the
owner and a Studio check.

## Uploads (unchanged from round 1, plus)

- **Abyss** (T10): uploaded Id kept; its GLB hash does not match the upload record. It joins the Studio-check list.
- **LairTower** (T8): its GLB is the same mesh at a new scale, so no upload.
- **ChainTower_p1-p4** (T2): new pieces, still to upload later (lead).

Renders: `assets/world2_draft/relayout_2026-11-26/track{04,05,08,09,10}_*/{game,context}` (round 2).
