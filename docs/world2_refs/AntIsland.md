# Track 7 AntIsland: source references

Source: Solo Leveling (webtoon and anime season 2), the Jeju Island raid against the ant colony. The game uses the
tweaked name Solo Levelup. Reference images are look-only. They sit in `build/world2/refs/AntIsland/`, which is
gitignored and never ships. Everything in the biome is modelled in-house from primitives. It has no logos and no text,
and the ants are generic shapes. Real-island features (the volcano, thatched stone houses, stone walls, stone
grandfather statues, basalt columns) are real-world geography and folk architecture, not franchise IP.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| The island and its volcano | An oval, overgrown green island with a broad central mountain and rocky summit; real Hallasan is a shield volcano with a crater lake and many small parasitic cones | https://solo-leveling.fandom.com/wiki/Jeju_Island | `anime_island.ref.jpg`, `webtoon_island.ref.jpg` | Island ground (oval, ragged coast, sand band, scorched patches) + `Cliff` (basalt columns); `Hallasan` (hero, infield): broad low shield, dark forest, pale jagged summit rocks round a rough crater lake, 16 parasitic cones, ant tunnels |
| Blockade ring | The anime shows a ring of ships surrounding the island | `anime_island.ref.jpg` | `anime_island.ref.jpg` | `Ship` (22 placed in a ring offshore) |
| Ant colony and nest | Swarms of pale, spiky giant ants with red eyes on sandy earth; the colony digs into the island | https://solo-leveling.fandom.com/wiki/Jeju_Island_Arc | `webtoon_gate.ref.jpg` | `Nest` (hero, ahead of the runner): low wide sandy cratered mound, rings of tunnel mouths, pale ants climbing out and a pack at its foot (instances of `Ant`), scorched ground; `Ant` (hero): pale plated body, banded spiky abdomen, spiked crown, two big and two small red eyes, sickle mandibles, elbowed antennae, long thin spidery legs with high knees (`webtoon_gate.ref.jpg`, `queen_anime.ref.jpg`); `Mound` (burning mound with smoke column) |
| Queen's chamber | A dark green cave with hanging rock over a floor of glowing blue eggs, with one big hatched egg | https://solo-leveling.fandom.com/wiki/Ant_Queen | `queen_anime.ref.jpg`, `queen_eggs.ref.jpg` | `Chamber` (hero, beside the road): cave mouth, stalactites, moss, tightly packed rounded blue eggs under webbing, hatched egg |
| Raid briefing map / raid camp | The raid is planned on a map of the island; Korean and Japanese hunter teams stage the raid | https://solo-leveling.fandom.com/wiki/Jeju_Island_Arc | `anime_arc.ref.jpg` | `Camp`: helicopter on a marked pad, tents, floodlight masts, sandbag rings, crates, truck; one framed by the 33% run shot |
| Abandoned villages | Island houses empty for years: thatched stone houses with rope-tied roofs, stone gate posts, black lava-stone field walls, stone grandfather statues, ruined coastal concrete buildings | real island architecture; wiki text: island lost to the ants for years | (none) | `Choga`, `Ruin`, `Brush` (broadleaf trees, camellias, a black lava-stone field wall), `Bank` (embankment under the raised road) |

Not matched: the source shows the nest mostly underground, with no fixed above-ground design, so the `Nest` mound
is our own read of an ant colony. The Ant King and Queen are not modelled as likenesses. The real Seongsan sunrise
peak was skipped to stay within the 12-mesh budget. Round 2 (2026-11-23): war-zone mood (overcast dusk, burning
mounds with smoke columns, scorched ground) per the owner's 1-1 call.

Nest refs (added round 4, 2026-11-23): `nest_tunnel.ref.jpg` (anime, the ant colony's tunnel inside the nest: dark
brown-grey rough earth walls, ribbed, dim; https://static.beebom.com/wp-content/uploads/2025/03/Ant-King.jpg) and
`ant_black.ref.jpg` (anime, an ant's head close up: slate-blue chitin, angular plated head, a big almond red eye, curved
mandibles; https://static.beebom.com/wp-content/uploads/2025/03/Black-Ant.jpg). No wide shot of the nest exterior was
found; the `Nest` now uses the tunnel ref's dark earth colours, and the `Ant` the head ref's angular head and chitin.

Round 5 (2026-11-23, new builder; Ant and Chamber eggs shaped live in Blender through the MCP and compared with
`webtoon_gate` and `ant_black`, then ported): the `Ant` follows the coordinator's ruling: pale bone-grey chitin with the
legs the same colour, an angular shield-wedge head (V face narrowing to the jaw, brow blades, side horns, a five-spike
crown), two big almond and two small red eyes, long curved sickle mandibles, a bigger banded and plated abdomen with
back spikes, and long legs bent at knees that rise above the body. The `Chamber` eggs are squat rounded ovoids packed
shoulder to shoulder, with white web strands sagging from egg to egg (`queen_anime`, `queen_eggs`). The blockade ships
sit on a wide ring well out in open water, spaced evenly by arc length (`anime_island`). Packs of ants roam beside the
road (the 33% and 90% run shots and every 520 studs, 24+ studs clear), as the webtoon's swarms. Hallasan's summit is
raised and its upper slopes are pale rock, so the pale summit dominates the island centre (`anime_island`); the review
shot's sightline is kept clear of scatter. The nest's climbing ants now sit on the mound surface, heads down the slope.
