# Track 2 DemonCastle: source references

Source: Solo Leveling (webtoon and anime), the Demon Castle S-rank dungeon (100 floors; Cerberus at the gate, Vulcan on
floor 50, Metus on 75, Baran on 100). The game uses the tweaked names (Solo Levelup, Barran). Reference images are
look-only. They sit in `build/world2/refs/DemonCastle/`, which is gitignored and never ships. Everything in the biome is
modelled in-house from primitives. It has no logos and no text, and its banners carry a plain changed shape.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| The castle: a chained tower | A tall rectangular tower with rows of windows (the floors), bound by huge iron chains, with fire at its foot and smoky sky behind | Wiki page images (webtoon panel and anime ep. 7): https://solo-leveling.fandom.com/wiki/Demon_Castle | `webtoon_castle.ref.jpg`, `anime_castle.ref.jpg` | `ChainTower` (hero): 4 set-back sections, floor bands, window grid, corner buttresses with pinnacles, 4 drooping chains to anchor blocks, fire ring and moat |
| Inside the floors: ruined burning city | The castle's floors show a destroyed city: high-rises with window grids, pink-purple fire, burning debris floating in the air, a pillar of light on the horizon | https://solo-leveling.fandom.com/wiki/Demon_Castle_Arc (anime image), wiki text "a destroyed version of Seoul ... set on fire" | `anime_castle2.ref.jpg` | `RuinA`, `RuinB` (window-grid ruins, pink flames), `Chunk` (floating burning rubble), light pillar on the `ChainTower` summit |
| Gate and gatekeeper | A three-headed hound with horns guards the entrance in front of a fiery gate with tall pillars | https://solo-leveling.fandom.com/wiki/Cerberus | `cerberus_gate.ref.jpg` | `Gate` (hero, spans the road twice): spired gate towers, pointed arch, open iron doors, three-headed hound statue (generic shape) |
| Top floor: the Demon King | Purple armoured demon with gold plates, horns, blue lightning blade, ringed by curved pale horn-spikes under a dark stormy sky | https://solo-leveling.fandom.com/wiki/Baran | `baran_anime.ref.jpg` | `ChainTower` summit: horn-spike ring round a throne; rider on `Wyvern` |
| The wyvern | Pale grey-white wyvern with swept horns, red eyes and dark wing membranes | https://solo-leveling.fandom.com/wiki/Kaisellin | `kaisel_flight.ref.jpg` | `Wyvern` (circles the tower top with the rider) |
| Castle mood | Black stone, purple-black sky, crimson and lava glow | design brief + all refs above | (all) | `Rampart`, `Watchtower`, `Brazier`, `Crag`, `Fissure`, sky ramp |

Not matched: the source shows the castle in orange fire and smoky blue-grey skies. The brief asks for a purple-black
palette, so the fire in the biome is pink-violet (as in `anime_castle2.ref.jpg`) with ember accents. Characters are
not modelled as likenesses; the rider and the hound are generic shapes.
