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
| Ant colony and nest | Swarms of pale, spiky giant ants with red eyes on sandy earth; the colony digs into the island | https://solo-leveling.fandom.com/wiki/Jeju_Island_Arc | `webtoon_gate.ref.jpg` | `Nest` (hero, ahead of the runner): low wide sandy cratered mound, rings of tunnel mouths, bulky pale ants climbing out and a pack at its foot, scorched ground; `Mound` (burning mound with smoke column) |
| Queen's chamber | A dark green cave with hanging rock over a floor of glowing blue eggs, with one big hatched egg | https://solo-leveling.fandom.com/wiki/Ant_Queen | `queen_anime.ref.jpg`, `queen_eggs.ref.jpg` | `Chamber` (hero, beside the road): cave mouth, stalactites, moss, tightly packed rounded blue eggs under webbing, hatched egg |
| Raid briefing map / raid camp | The raid is planned on a map of the island; Korean and Japanese hunter teams stage the raid | https://solo-leveling.fandom.com/wiki/Jeju_Island_Arc | `anime_arc.ref.jpg` | `Camp`: helicopter on a marked pad, tents, floodlight masts, sandbag rings, crates, truck; one framed by the 33% run shot |
| Abandoned villages | Island houses empty for years: thatched stone houses with rope-tied roofs, stone gate posts, black lava-stone field walls, stone grandfather statues, ruined coastal concrete buildings | real island architecture; wiki text: island lost to the ants for years | (none) | `Choga`, `Ruin`, `Batdam`, `Brush` (broadleaf trees, camellias), `Bank` (embankment under the raised road) |

Not matched: the source shows the nest mostly underground, with no fixed above-ground design, so the `Nest` mound
is our own read of an ant colony. The Ant King and Queen are not modelled as likenesses. The real Seongsan sunrise
peak was skipped to stay within the 12-mesh budget. Round 2 (2026-11-23): war-zone mood (overcast dusk, burning
mounds with smoke columns, scorched ground) per the owner's 1-1 call.
