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

- Owner 2026-10-30: track ids stay the IVS ids (Oval ... Space) so saves stay valid; players see only the biome
  display names. Track tests drive every track at normal and max stat speed in the full harness (~21 min).

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
| 5 | Burning Cursed City | Jujitsu Kaisan | night city on fire (owner 2026-10-31): smoke-black sky lit orange, embers, craters, a smouldering meteor, lava-scorched streets, burning high-rises |
| 6 | Hero Academy City | My Hero Akademia | bright modern city, a tall glass academy tower, training grounds, giant robot props |
| 7 | Shibuyo Underground | Jujitsu Kaisan | the whole route in an enclosed subway tunnel (owner 2026-10-31): tiled walls, ceiling light strips, rails, opening into a few station platforms and concourses |
| 8 | Skypeia | One Peace | sky island on a white cloud sea (owner 2026-10-31): a cloud town, a cloud river, a giant jungle, a giant beanstalk, sunken golden ruins, a giant golden bell |
| 9 | Spirit Realm Desert | Bleach-like | white sand, dead white trees, a giant dome palace on the horizon, crescent moon in a black sky |
| 10 | Green Alien Planet | Dragon Bawl Z | green sky, blue-green grass, round domed houses, tall thin trees with ball tops |

- IP safeguards (design doc section 5): match closely, never copy exactly. No logos, crests, village symbols, jolly rogers, school
  emblems, kanji from the shows or real place names on props. All meshes and textures are made in-house. Signs use
  made-up text.
- Each biome keeps the IVS budgets (prop budget, scale rules, EditableMesh near the camera, part fallback elsewhere).
- Night biomes (4, 5, 9) and the underground Track 7 tint only their own props and ground; they never change global
  `Lighting` (IVS rule).
- Owner 2026-10-30: Track 7 is named "Blossom Shrine Path" ("Sakura" is a blocked real name). Replaced 2026-10-31:
  owner redesign of Tracks 5, 7 and 8 (design doc change log); every track is based on an anime, none original.
  Track 8's NPC rival is Enelu [Enel] (`NPC_RIVAL_SPEC.md`).
- Owner 2026-10-30: Track 1 builds no biome start gate; the plaza torii StartGate is its gate (its first straight
  runs beside the plaza floor).
- Owner 2026-10-30 (replaces the fixed 1200-part budget for these tracks): the dressing part budget grows with track
  length, 1200 parts per ~3,000 studs of track (placeholder), so every layer (landmarks, horizon, rhythm, scatter,
  patches, city blocks) gets built.
- Owner 2026-10-30: horizon pieces sit about 100 studs from the road (placeholder) so they fit between spiral laps;
  they act as large props.
  Built 2026-10-30 as Horizon Offset 55 with 20-22-stud-deep pieces, so their far edge is about 100 studs out
  (placeholder; laps are only ~110 studs apart edge to edge).

## Build order and tests

1. Track tests first (one `TrackTests/<Track>.luau` per track: target length +-5%, validator rules, chain no-overlap,
   0 flips / 0 off-track at normal and max stat speed, pad paid once).
2. Track layouts 2-10 at the new lengths, then the chain test.
3. Biome themes 1-10 (data in `BiomeThemes`, props from the CC0 packs or new Blender drafts).
4. Full harness green.

## References

One entry per track: the researched sources and what each one informed. Filled in as each biome is built.

Research pass 2026-10-30. Every URL was checked to exist on that date (fandom pages via the wiki API, because the
site blocks scripted fetches). Real show names appear here only. Build notes follow design doc 5: no logos, crests,
village symbols, flags, school emblems, show kanji or real place names; signs use made-up text.

### Track 1: Leafwind Village (Naruto Shippuden, Hidden Leaf Village)
- https://naruto.fandom.com/wiki/Konohagakure (layout: walled village in a forest, big main gate, mountain behind)
- https://naruto.fandom.com/wiki/Hokage_Rock (the carved cliff; reference for scale only)
- https://naruto.fandom.com/wiki/Valley_of_the_End (waterfall cliffs, for a late-route gorge)
- https://en.wikipedia.org/wiki/Naruto (series context)
- Route: start in the forest, through a tall wooden village gate, down a main street of shops, along the cliff base,
  over 2-3 red arched bridges on a river, then back into forest and a waterfall gorge for long tracks.
- Architecture: wood plank walls, cream plaster, red/green tiled roofs, round water tanks on rooftops, stone walls.
- Palette: #3E7D3A forest green, #C9A36B wood, #E8DCC0 plaster, #B23A2E bridge red, #9C8F7E cliff stone (owner 2026-10-31, was #7C8C99), #87CEEB sky.
- Props: training posts (3 wooden logs), ramen-style food stall with made-up sign, paper lanterns, round rooftop tanks,
  tall pine trees, wooden fences, red bridge rails, cliff with 4 generic stone faces.
- IP flag: the cliff must not copy the real carved faces; use 4 generic, unnamed faces (owner-approved 2026-10-28).
  No leaf-spiral symbol on the gate, flags or headbands; gate text is made-up.
- Sky/ground: clear daytime blue, warm green grass, dirt road #A07B52.

### Track 2: Tournament Wasteland (Dragon Ball Z, World Martial Arts Tournament and wastelands)
- https://dragonball.fandom.com/wiki/World_Martial_Arts_Tournament (stone tiled ring, temple-like arena)
- https://dragonball.fandom.com/wiki/Papaya_Island (tropical island venue)
- https://dragonball.fandom.com/wiki/Wasteland (rocky plateau fighting grounds)
- https://en.wikipedia.org/wiki/Dragon_Ball_Z (series context)
- Route: weave between tall mesa pillars, dip through craters, pass the open stone ring at mid-track, then cliffs.
- Architecture: square stone ring of pale tiles, low arena walls, tan rock mesas with layered strata.
- Palette: #D9B98A sand, #B8834F rock, #8A5A3B dark strata, #E6E1D3 ring tile, #F2A23A sunset accent, #7FB8E0 sky.
- Props: square tile ring, craters with cracked edges, floating boulders, broken rock spires, scorched marks,
  small domed capsule-style huts (plain, no brand), dead shrubs.
- IP flag: the ring stays a generic tiled square; no arena banner text or real tournament name.
- Sky/ground: hot pale-blue sky, tan ground.

### Track 3: Pirate Harbor Isle (One Piece, island harbor)
- https://onepiece.fandom.com/wiki/Foosha_Village (small harbor village, windmill, docks)
- https://onepiece.fandom.com/wiki/Syrup_Village (seaside cliffs and slopes)
- https://onepiece.fandom.com/wiki/Water_7 (canals and harbor architecture)
- https://onepiece.fandom.com/wiki/Going_Merry (iconic ship; reference only, do not copy)
- https://en.wikipedia.org/wiki/Caravel (generic historic ship shape to build from)
- Route: beach start, along wooden docks, through a small harbor town, up a cliff road with sea views, around palms.
- Architecture: white plaster houses with blue/red roofs, plank docks, rope rails, a windmill.
- Palette: #F3E2B3 sand, #2E8BC0 sea, #FFFFFF plaster, #C0392B roof red, #8B5A2B dock wood, #4CAF50 palm.
- Props: moored caravel with a plain sail, barrels and crates, rope coils, palm trees, windmill, buoys, fishing nets.
- IP flag: no skull flag of any kind and no animal-head figurehead (too close to the iconic ship). Plain sail only.
- Sky/ground: bright tropical blue, open sea horizon, sand ground.

### Track 4: Wisteria Night Mountain (Demon Slayer, wisteria mountain and Taisho town)
- https://kimetsu-no-yaiba.fandom.com/wiki/Wisteria (wisteria groves as a ward)
- https://kimetsu-no-yaiba.fandom.com/wiki/Mount_Fujikasane (mountain covered in wisteria)
- https://kimetsu-no-yaiba.fandom.com/wiki/Mount_Natagumo (dark forest mountain)
- https://kimetsu-no-yaiba.fandom.com/wiki/Asakusa (Taisho-era city night street)
- https://en.wikipedia.org/wiki/Taish%C5%8D_era (period architecture)
- Route: through a wooden Taisho-style town street, then a stone stair path up into wisteria groves and dark forest.
- Architecture: dark wood two-storey shops, tile roofs, sliding paper doors, stone lanterns.
- Palette: #1B1A33 night ground, #8E6BBF wisteria, #C9A9E8 light blossom, #3B2A1E dark wood, #F5E6A8 lantern glow,
  #E8E8F0 moon.
- Props: wisteria trees and arches, stone lanterns (lit), full moon disk, paper lanterns, wooden fences, a shrine gate
  in plain wood, falling purple petals.
- IP flag: no checkered haori patterns or show kanji on signs.
- Night biome: tint only this biome's props, ground and a local moon prop. Never change global Lighting.

### Track 5: Burning Cursed City (Jujutsu Kaisen, Shibuya Incident, the Jogo vs Sukuna fire fight)
Owner redesign 2026-10-31. Research pass 2026-10-31 (fandom pages checked via the wiki API; sportskeeda found by
search but blocks scripted fetches).
- https://jujutsu-kaisen.fandom.com/wiki/Sukuna_vs._Jogo (the fight starts inside the station and spreads across the
  city at night: a building's upper floors burst into flames as one fighter crashes out of them; lava thrown at street
  level; a slam through several storeys of a building, moonlight through the hole; every opening of that building
  explodes with fire; a giant flaming meteor flattens the area and lies smouldering; a closing exchange of fire)
- https://jujutsu-kaisen.fandom.com/wiki/Shibuya_Incident_Arc (Halloween night, the city under a dark barrier,
  ruined streets around the station)
- https://jujutsu-kaisen.fandom.com/wiki/Jogo (the fire curse: flames from any surface, small volcanoes, lava;
  reference for effects only, never his likeness)
- https://myanimethoughts.com/sukuna-vs-jogo-the-firepower-battle ("a hellscape of molten rock": flames, small
  volcanoes, a meteor that can flatten city blocks)
- https://www.sportskeeda.com/anime/jujutsu-kaisen-season-2-episode-16-megumi-witnesses-toji-s-end-sukuna-destroys-jogo
  (anime season 2 episode 16, where the fight is animated)
- https://en.wikipedia.org/wiki/Jujutsu_Kaisen (series context)
- Route (7,207 studs): start on a dark avenue of high-rises with fire in the windows; past a tower whose top floors are
  blown open and burning; down a lava-scorched boulevard with glowing cracks and burning cars; into a cratered
  crossroads where the meteor lies smouldering (mid-track); under a collapsed rail viaduct; past a tower sliced open
  and fallen; finish across a flattened rubble field ringed by fire.
- Architecture: tall concrete office and retail blocks with shattered glass fronts, exposed steel frames, burnt blank
  signboards, an elevated rail viaduct, bent street lamps, cracked asphalt.
- Palette: #0E0B12 char ground, #2A1E1E smoke, #FF6A1A fire orange, #FFC23D flame yellow, #C2261B ember red,
  #4A4448 burnt concrete, #DCE2F0 moon (placeholders).
- Props: burning cars (generic), fire columns, lava cracks and pools, the smouldering meteor (a plain boulder),
  craters with scorched rims, rubble piles, steel girders, toppled traffic lights, bent lamps, blank burnt billboards,
  smoke columns, rising embers.
- IP flag: no Sukuna or Jogo likeness (no volcano-headed figure, no four-armed or face-marked figure, no tattoo
  patterns on props); no copy of the domain shrine (no shrine of skulls, no fanged-mouth gate); no cursed-technique
  symbol, hand sign or bow-shaped flame prop. No real store or station names or signs (no Tokyo Metro, no
  Fukutoshin line, no Shibuya 109 cylinder tower, no dog statue, no scramble-crossing copy, no real logos). Signs are
  blank, burnt or made-up text.
- Night biome: tint only this biome's props and ground; fire light from local parts and particles. Never change
  global Lighting.
- Sky/ground: night; smoke-black sky lit orange from below, the moon showing through a gap; asphalt with glowing
  cracks.

### Track 6: Hero Academy City (My Hero Academia, U.A. High and city)
- https://myheroacademia.fandom.com/wiki/U.A._High_School (tall glass building, campus layout)
- https://myheroacademia.fandom.com/wiki/Ground_Beta (mock-city training ground)
- https://en.wikipedia.org/wiki/My_Hero_Academia (series context, giant robot test)
- Route: city boulevard, past the academy campus gates, through a mock-city training ground, past toppled robots.
- Architecture: clean modern towers, glass curtain walls, wide plazas, concrete training-ground blocks.
- Palette: #4A90D9 glass blue, #E6E9EE concrete, #D63A3A accent red, #F2C12E accent yellow, #2F3542 asphalt,
  #8FD18F park green.
- Props: tall glass academy tower, campus gate walls, giant robot props, billboards with made-up text,
  street lamps, crash barriers, park trees.
- IP flag: the real academy is a distinctive H-shaped tower; use a single plain glass tower instead.
  No school emblem on the gate. Robots stay generic boxy designs.
- Sky/ground: bright day, asphalt road, grass verges.

### Track 7: Shibuyo Underground (Jujutsu Kaisen, Shibuya Incident subway)
Owner redesign 2026-10-31; replaces the original Blossom Shrine Path. Research pass 2026-10-31.
- https://jujutsu-kaisen.fandom.com/wiki/Shibuya/Tokyo_Metro (stations have five basement floors, B1F to B5F; the
  subway platforms sit on B5F; four neighbouring stations link to the main station by the B5F line; one sorcerer walks
  the tracks between two stations; teams come down from street level floor by floor; a shopping atrium sits four
  floors above the B5F platform)
- https://jujutsu-kaisen.fandom.com/wiki/Shibuya_Incident_Arc (Halloween night crowds trapped underground, the B5F
  platform fight, the station as the arc's main setting)
- https://www.sportskeeda.com/anime/jujutsu-kaisen-season-2-episode-8-yuji-enters-shibuya-gojo-s-first-battle-begins
  (anime: a sorcerer drops down to the B5F platform, packed with people)
- https://en.wikipedia.org/wiki/Shibuya_Station (real structure: deep B5F through-line platforms; reference for depth
  and scale only)
- https://www.pakutaso.com/en/20240528143b5f.html (photos of the real B5F platform: grey columns, a row of fluorescent
  ceiling lights, dim even light, yellow tactile strip at the edge; look reference only)
- https://en.wikipedia.org/wiki/Platform_screen_doors (generic platform door shape)
- Route (11,261 studs): the whole route runs inside a tunnel. Start at a stair entrance from the street, down into a
  twin-track tunnel; a first side platform; a large multi-level concourse with ticket gates, escalators and an open
  atrium void; long tunnel stretches with service lights, crossovers and a stalled train; a second platform; the deep
  main platform hall (the B5F-style island platform with rows of columns); finish at a last platform with stairs up.
- Architecture: box-section cut-and-cover tunnels and a few round bored stretches; cream wall tiles with one colour
  stripe band; concrete ceilings with fluorescent light strips; rows of steel columns on platforms; half-height
  platform screen doors; yellow tactile strips; rails on sleepers with overhead wire gantries.
- Palette: #E9E4D6 tile cream, #8C8A84 concrete, #2B2E33 track bed, #F2D23A tactile yellow, #3FA7A0 stripe teal,
  #CFE8FF fluorescent white, #B5281F emergency red (placeholders).
- Props: platform screen doors, columns, benches, blank vending machines, ticket gates, escalators and stairs, wall
  maps with abstract shapes, made-up signs, stalled generic train cars, overhead wire gantries, emergency lights,
  fallen ceiling panels, broken tiles, scattered rubble.
- IP flag: no real station, line or company names, letters, numbers or logos (no Tokyo Metro roundel, no Fukutoshin
  line name, letter or brown line colour, no station numbering, no real department store names); no copy of the real
  oval station atrium; no sealing-cube artifact; no character likenesses (no figures on the platforms). Signs use
  made-up text.
- Underground biome: no sky, lit by its own ceiling lights (BIOME_ENVIRONMENT_SPEC 3.5, proposed framework task).
  Never change global Lighting.
- Sky/ground: none; enclosed. Ceiling overhead, tiled walls, a concrete floor beside the track bed.

### Track 8: Skypeia (One Piece, Skypiea)
Owner redesign 2026-10-31; NPC rival Enelu [Enel]. Research pass 2026-10-31 (fandom pages checked via the wiki API).
- https://onepiece.fandom.com/wiki/Skypiea (a sky nation on a huge dense cloud mass; Angel Island, the residential
  district made of island clouds, cut by a market street of shops; a beach; a gate into the sky nation)
- https://onepiece.fandom.com/wiki/Upper_Yard (the only solid-land island: giant forest, giant trees and animals; a
  gate of four ordeals under an idol head; the beanstalk at its centre)
- https://onepiece.fandom.com/wiki/Giant_Jack (a giant beanstalk towering over the whole nation, through the ruins and
  up to island clouds near its top; later cut down to form a bridge)
- https://onepiece.fandom.com/wiki/Shandora (the ancient golden city, ruins under ground level at the beanstalk's
  base; buildings once covered in gold, shaped like Maya architecture)
- https://onepiece.fandom.com/wiki/Golden_Bell (an enormous golden bell in a belfry on a small island cloud near the
  beanstalk's top; overgrown with vines)
- https://onepiece.fandom.com/wiki/Sea_Clouds (the white cloud seas, two layers, no sea floor) and
  https://onepiece.fandom.com/wiki/Island_Clouds (solid clouds you can walk on)
- https://onepiece.fandom.com/wiki/Milky_Road (artificial cloud rivers, one links the cloud town to the forest island)
- https://en.wikipedia.org/wiki/Maya_architecture (generic stepped-temple shapes for the ruins)
- https://en.wikipedia.org/wiki/One_Piece (series context)
- Route (14,076 studs): start on a white cloud beach by the cloud sea; through a cloud town of round white houses and a
  market street; along a cloud river; through a stone gate into the giant jungle (huge trees, roots, vines, a swamp);
  down to the beanstalk's root among sunken golden ruins; climb past the beanstalk; finish on high island clouds with
  the giant golden bell in its belfry.
- Architecture: round, soft white cloud houses with domes and pastel trims; giant jungle trees with buttress roots;
  stepped Maya-like stone temples stripped of most gold, a few gold-clad walls left, vine-covered; a broken stone
  belfry.
- Palette: #FFFFFF cloud, #E6EEF8 cloud shade, #6EC6FF sky, #2F7D3B jungle green, #6B4A2E giant bark, #9DBF5A
  beanstalk green, #E3B341 gold, #B9A88A ruin stone (placeholders).
- Props: round cloud houses, cloud puffs, cloud-river ribbons, sky palms, giant jungle trees, hanging vines, giant ferns,
  beanstalk stems, stepped ruins, broken gold pillars, the giant golden bell.
- IP flag: no Straw Hat or Jolly Roger symbol; no God's Shrine nameplate or gate sign text ("Heaven's Gate"); no Enel
  likeness in scenery (no drum ring); no copy of the golden ark ship; no ancient-script stone blocks; no copy of the
  ordeal gate's idol head; the bell is a plain bell without inscription.
- Sky/ground: bright high noon, deep blue above, the cloud sea below and to the horizon; white cloud ground in the town,
  jungle ground on the forest island.

### Track 9: Spirit Realm Desert (Bleach, Hueco Mundo and Las Noches)
- https://bleach.fandom.com/wiki/Hueco_Mundo (white sand desert, dead trees, black sky, crescent moon)
- https://bleach.fandom.com/wiki/Las_Noches (giant white dome fortress)
- https://en.wikipedia.org/wiki/Bleach_(manga) (series context)
- Route: across white dunes, through a grove of dead white crystal trees, toward a dome palace on the horizon.
- Architecture: smooth white walls, giant domes, square towers far away.
- Palette: #F2F2EE white sand, #DADAD2 tree white, #0A0A12 black sky, #E9EEF5 moon, #8892A6 shadow, #2E2E3A rock.
- Props: dead white trees, white rock outcrops, distant dome palace, crescent moon, broken pillars, bone-like arches.
- IP flag: the palace is a plain dome with a few towers, not the real layout. No mask designs.
- Night biome: tint only this biome's props, ground and a local sky backdrop. Never change global Lighting.

### Track 10: Green Alien Planet (Dragon Ball Z, Planet Namek)
- https://dragonball.fandom.com/wiki/Planet_Namek (green sky, blue-green grass, islands, ball-top trees)
- https://dragonball.fandom.com/wiki/Ajisa (the ball-top trees)
- https://dragonball.fandom.com/wiki/Namekian (dome houses and villages)
- https://en.wikipedia.org/wiki/Dragon_Ball_Z (series context)
- Route: across small grassy islands linked by land bridges over blue-green water, through dome villages.
- Architecture: round white domed houses with round windows, tall rock pillars.
- Palette: #8FD18A sky green, #3FB59A grass, #2E8B8B water, #F0F0E6 dome white, #6E7F5A rock, #B9E4A6 haze.
- Props: ball-top tall trees, dome houses, small islands, rock pillars, crater pools, distant suns.
- IP flag: no orb items with stars; no copy of a specific house design; houses are plain domes.
- Sky/ground: green sky tint applies to a local backdrop only, not global Lighting.
