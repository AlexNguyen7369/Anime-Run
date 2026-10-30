# Tracks and anime biomes: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3 (track chain rules), 4.4 (losing), 4.8 (series), 5 (IP
safeguards) and 4.9 (this map redesign). Owner decisions 2026-10-28: tracks start long and get longer; every track
gets an anime-inspired biome. Owner 2026-10-30: tracks very long (base factor F), biomes researched and matched closely. Numbers are placeholders unless stated.

## Lengths

- Owner 2026-10-30: tracks are very long. Track n target length = `984 x F x 1.25^(n-1)` studs, F = 3 (owner confirmed 2026-10-30),
  within +-5%. Track 1 gets a new layout (the IVS `Oval` is too short). Measured along the centre line by
  `TrackValidator` (new check `TARGET_LENGTH`).
- Table at F = 3; NPC speeds unchanged (`16 x 1.51^(n-1)`):

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Length (studs) | 2,952 | 3,690 | 4,612 | 5,766 | 7,207 | 9,009 | 11,261 | 14,076 | 17,595 | 21,994 |
| NPC speed (studs/s) | 16 | 24.2 | 36.5 | 55.1 | 83.2 | 125.6 | 189.7 | 286.4 | 432.4 | 653 |
| NPC time (s) | 184.5 | 152.7 | 126.4 | 104.7 | 86.6 | 71.7 | 59.4 | 49.2 | 40.7 | 33.7 |

- Cruise speed is fixed for a runner during a run, so a team that wins Track 10 runs the whole chain in at most about
  101 s. A Legendary trio clears it in about 90 s using about all its stamina (owner 2026-10-30,
  `TEAM_AND_STAMINA_SPEC.md` balance check).
- All IVS track rules still hold: numbered chain, point-to-point, first and last segments level straights >= 40,
  wide checkpoint area, WinPad on the left apron, right-hand racing lane, min radius, no overlap with any track or the
  spawn area, drivable at stat speed with 0 flips and 0 off-track (IVS `TrackValidator` and track tests).
- Longer tracks wind (switchbacks, spirals, S-bends) to fit; the chain may spread past the IVS baseplate, so the safety
  baseplate grows to cover every track plus a margin.

## Biomes

Research first (owner 2026-10-30): before building a track or its biome, research public information on the anime
(wiki pages, official art books, screenshots) for the matching location: layout, architecture, palette, landmarks,
props. Match it closely in the track's route, assets and world building; record the sources under "References" in
this spec. Section 5 safeguards still hold (see the IP bullet below).

One biome per track, built with the IVS `BiomeThemes` (data) + `BiomeDressing` (builder) pattern: rhythm props along
the road, corner / crest landmarks, horizon pieces, a start `Gate`, themed ground and sky tint. Props are visual only,
never closer than `CLEARANCE` to any road, wall, checkpoint, pad or the spawn area.

| Track | Biome (working name) | Inspired by | Look |
|---|---|---|---|
| 1 | Leafwind Village | Narito Shippudon | forest village, wooden rooftops, a carved cliff face with 4 generic stone faces (owner-approved 2026-10-28), red bridges, training posts |
| 2 | Tournament Wasteland | Dragon Bawl Z | rocky plateaus, craters, a stone tournament ring, floating boulders |
| 3 | Pirate Harbor Isle | One Peace | sandy island, docks, a moored caravel with a plain sail, palm trees, open sea horizon |
| 4 | Wisteria Night Mountain | Demon Slicer | night forest, purple wisteria trees, stone lanterns, a Taisho-style wooden town, full moon |
| 5 | Neon Cursed City | Jujitsu Kaisan | night city crossing, neon signs with made-up text, a temple school on a hill, dark purple fog |
| 6 | Hero Academy City | My Hero Akademia | bright modern city, a tall glass academy tower, training grounds, giant robot props |
| 7 | Sakura Shrine Path | classic anime | cherry blossom avenue, torii gates, stone stairs, falling petals |
| 8 | Sky Islands | classic anime | floating grassy islands, waterfalls into clouds, vine bridges, old stone ruins |
| 9 | Spirit Realm Desert | Bleach-like | white sand, dead white trees, a giant dome palace on the horizon, crescent moon in a black sky |
| 10 | Green Alien Planet | Dragon Bawl Z | green sky, blue-green grass, round domed houses, tall thin trees with ball tops |

- IP safeguards (design doc section 5): match closely, never copy exactly. No logos, crests, village symbols, jolly rogers, school
  emblems, kanji from the shows or real place names on props. All meshes and textures are made in-house. Signs use
  made-up text.
- Each biome keeps the IVS budgets (prop budget, scale rules, EditableMesh near the camera, part fallback elsewhere).
- Night biomes (4, 5, 9) tint only their own props and ground; they never change global `Lighting` (IVS rule).

## Build order and tests

1. Track tests first (one `TrackTests/<Track>.luau` per track: target length +-5%, validator rules, chain no-overlap,
   0 flips / 0 off-track at normal and max stat speed, pad paid once).
2. Track layouts 2-10 at the new lengths, then the chain test.
3. Biome themes 1-10 (data in `BiomeThemes`, props from the CC0 packs or new Blender drafts).
4. Full harness green.

## References

One entry per track: the researched sources and what each one informed. Filled in as each biome is built.
