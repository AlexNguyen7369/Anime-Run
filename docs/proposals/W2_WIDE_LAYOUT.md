# World 2 wide layout: three options (proposal, 2026-11-26)

This is a proposal only. No game file is changed. World 1 is untouched.

The owner said on 2026-11-26: "biomes/tracks on world 2 are much too close to each other where racing on one track is
not immersive. Spacing per track in terms of width should be much larger, can have the track be straight even, not just
circular. There should be little to no overlaps in other tracks." The target spacing (owner, 2026-11-26) is a
smallest gap of about **600 studs from any World 2 road to any other track's road**.

Tool: `tools/blender/world2/layout_options.py` (needs numpy, scipy and matplotlib). It chains every layout the same way as
`chain.py` and `TrackBuilder.Layout`: from `CHAIN_ORIGIN` (-118, 1, 80) at heading 0, with each track starting on the
previous finish. Output goes to `assets/world2_draft/layout_options/`: one plan per layout (`current.png`,
`option_a_wide_spiral.png`, `option_b_zigzag.png`, `option_c_square_spiral.png`) and `layout_options.json`, which holds
every option's measured rows and its full segment lists, ready to paste into the track files.

## How each number is measured

- **Gap**: the smallest distance from the edge of this track's road to the edge of another track's road. That is the
  centre-line distance minus 40, because every World 2 road is 40 studs wide. Add 20 to get the distance from this
  track's centre line to the other road. For the next and previous tracks, point pairs less than 1,200 studs apart
  along the chain through their shared joint are skipped, so the joint itself does not count as a near miss.
- **Band on other ground**: the prop band runs from 24 to 100 studs beyond the road edge, on both sides. This is the
  share of that band that is nearer to another track's centre line, which the 2026-11-25 ground-ownership rule gives
  to that other track, or that lies in the plaza zone (spawn radius + 64). Sampled on a 4-stud grid.
- **Extent**: the min and max of x and z over all the centre lines. "Max |xz|" adds the 120-stud band.
- **Spirals outward**: the WORLD_REDESIGN_SPEC 3 placeholder. Each track's mean centre-line distance from the plaza is
  greater than the previous track's.
- The options are plan views made of level Straights and Turns only. The current tracks' hills (Slope) can sit inside
  any straight later without changing the plan.

## Results

| Layout | Smallest gap per track, T1..T10 (studs) | Worst gap | Band on other ground | Extent x / z | Max \|xz\| | Longest straight | Spirals outward |
|---|---|---|---|---|---|---|---|
| Current | 89, 83, 78, 78, 78, 41, 41, 148, 514, 1131 | **41** (T6/T7) | 47, 50, 53, 53, 53, 49, 23, 4, 0, 0 % | -4148..4173 / -4148..4148 | 4,293 | 920 | yes |
| A: wide spiral, pitch 740 | 694, 691, 694, 691, 678, 658, 638, 623, 620, 620 | **620** | T1 7.5 %, others ≤ 0.1 % | -3849..4876 / -4162..4878 | 4,998 | 40 (all arcs) | yes |
| B: wide zigzag rows, pitch 780 | 740, 701, 701, 701, 701, 663, 663, 687, 687, 740 | **663** | T1 5.2 %, others ≤ 0.1 % | -118..6941 / -10117..12285 | 12,405 | 2,432 | **no** (T2 mean 1,177 < T1 1,259) |
| C: square spiral, pitch 760 | 701, 643, 701, 643, 696, 720, 720, 720, 720, 720 | **643** | T1 4.5 %, others ≤ 0.1 % | -3937..3803 / -4629..3871 | 4,749 | 7,660 | yes |

- The current chain misses the 600 target by 86 (T9) to 559 (T6, T7) studs on 9 of the 10 tracks. Only T10 passes.
  About half of each prop band on Tracks 1 to 6 lies on another track's ground.
- **All three options meet the 600 target on every track; none falls short.** A's narrowest margin is +20 (T9, T10),
  B's is +63 and C's is +43.
- The T1 band share in each option is the plaza zone around the start and not another track. The ≤ 0.1 % elsewhere is
  the corner of each track's joint with its neighbour.
- Lengths match the targets exactly in every option (0.00 %): 2,952 / 3,690 / 4,612 / 5,766 / 7,207 / 9,009 / 11,261 /
  14,076 / 17,595 / 21,994. Track 6 goes from 8,720 (-3.2 %) to its table length of 9,009. The NPC speed and time table
  is unchanged.
- The smallest gap to the spawn area (from T2 onwards) is 747 for A, 496 for B and 742 for C. The current chain's is 194.

## The options

**A: the same spiral, wide lap pitch.** This is today's form: one Archimedean spiral of right-hand arcs around the
plaza, with laps 740 studs apart. It has no straights; the curve radius grows from 456 (T1) to 4,243 (T10). There are
long sweeping curves, but nothing is straight. The innermost tracks make about 0.6 to 0.9 of a lap and the outer tracks
less, so no track keeps the "about 1.5 laps" band. That form is worded as "may be", so it is allowed, not required.

**B: wide zigzag (serpentine) rows.** Each track is one long row, straight apart from gentle S-bends (radius 2,000,
±8°, 39-stud sway). The row ends in a 180° turn (radius 390) into the next row. Rows run 780 apart and alternate
direction, stacking away from the plaza. This is the "straight" reading of the owner's words. It breaks the spiral
rules: the form is not a spiral and not a ring band, and the mean-distance placeholder fails at T2. It also spreads
the world furthest: about 7,000 × 22,400 studs, ±12.4k, still inside ±20k.

**C: a square spiral of long straights (recommended).** Laps 760 apart with right-hand 90° corners of radius 420. The
sides grow 760 every two sides, so straights run from 820 studs on Track 1 to 7,660 on Track 10. It keeps both spiral
rules: it spirals outward with T1 nearest and T10 outermost, and each track is a band of the spiral. It also gives the
long straights the owner asked for. It is the most compact option, with a max |xz| of 4,749, about the same size as
today's world. Its smallest gap is 643 studs, with 720 from Track 6 outward.

## Rules each option keeps or breaks

| Rule | A | B | C |
|---|---|---|---|
| Design doc 3: numbered point-to-point chain, each track starts on the previous finish (FIXED) | keeps | keeps | keeps |
| TRACKS_AND_BIOMES_SPEC: first and last segments are level straights ≥ 40 | keeps | keeps | keeps |
| Min radius 60 (World 1 track tests) | keeps (456) | keeps (390) | keeps (420) |
| Right-hand lane, drivable at stat speed: the runner is on a rail with no corner slowing; all turns are ≥ 390 and level | keeps (to verify with TrackValidator) | keeps (to verify) | keeps (to verify) |
| No overlap with any track or the spawn area | keeps (747 to the spawn) | keeps (496) | keeps (742) |
| Target length within 5 %; length and NPC table (FIXED) | keeps (0 %) | keeps (0 %) | keeps (0 %) |
| WORLD_REDESIGN_SPEC 3 "spirals outward" (placeholder, mean distance) | keeps | **breaks** at T2 (needs the owner's rule change) | keeps |
| WORLD_REDESIGN_SPEC 3 spiral form / "ring band about 1.5 laps" (owner ruling for spirals) | keeps the spiral; laps < 1.5 ("may be") | **breaks** (not a spiral; needs the owner's rule change) | keeps the spiral; laps < 1.5 ("may be") |
| WORLD2_SPEC "World 2 keeps World 1's track spacing" (coordinator's choice, now overruled by the owner) | replaced | replaced | replaced |
| World 1 unchanged | keeps | keeps | keeps |
| Baseplate covers everything + 20 | needs a bigger World 2 plate (±5.0k) | much bigger (7k × 22k) | ±4.8k, about today's |

## What any option changes (not done here)

- All ten World 2 track files (`src/shared/Tracks/World2/*.luau`) get new Segments. The lengths are the same, so the
  track ids, payouts and NPC times stay as they are.
- Every World 2 placement that sits in a track's local frame or on its ground has to be refit to the new road:
  scenery, `hero_moves.json`, the kaiju rows, cross-track landmarks and the biome draft exports. agent-3 is mapping that
  list. Most of the hero "no spot" cases and the ground-ownership moves exist only because the tracks are crowded, so
  they should go away.
- `chain_check.json` (CHAIN PARITY), the track tests and TrackValidator have to be rerun. The terrain and baseplate
  size for World 2 need checking.

## Recommendation

**C, the square spiral of long straights.** It meets the 600-stud target with margin (643 smallest, 720 on the outer
tracks). No prop band touches another track. It has the long straights the owner asked for. It is the only option that
does all of that without a rule change: it keeps "spirals outward" and the spiral form. It also stays the size of
today's world (±4.7k), so the baseplate, streaming and physics precision stay where they are now. B is the purest
"straight" reading, but it needs two rule changes and a world almost three times as long. A keeps the rules, but all of
it is curves, which the owner said need not be the case.
