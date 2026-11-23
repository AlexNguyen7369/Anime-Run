# Track 1 DevilTokyo: source references

Source: Chainsaw Man (anime season 1 and the Reze arc film), the night streets of Tokyo where the Public Safety devil
hunters work. The game uses the tweaked name Saw Man. Reference images are look-only. They sit in
`build/world2/refs/DevilTokyo/`, which is gitignored and never ships. Everything in the biome is modelled in-house from
primitives. It has no text and no logos. Signs are abstract coloured panels with plain blocks. The convenience store
bands use colours that no real chain uses. The headquarters emblem is a changed shape (a ring and a plain diamond),
not the real Public Safety mark. Most of the street furniture is real Tokyo street design (utility poles, vending
machines, guardrails, mansion blocks), not franchise IP.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| Public Safety headquarters | Large government office building in central Tokyo. No confirmed real model; guides suggest a composite of Kasumigaseki and Nagatacho government buildings. Those are wide 8-12 storey blocks with stacked horizontal ribbon windows and projecting floor slabs, with tall dark office towers behind them | https://www.japan-pop-now.com/articles/chainsaw-man-pilgrimage-tokyo (speculative); https://commons.wikimedia.org/wiki/File:Central-Government-Building-4-01.jpg | `gov_building4.jpg` | `HQ` (hero, 2 placed across the rooftops at about 0.36 and 0.68 of the run): 11 projecting slabs, ribbon glazing with lit bays, vertical mullions, podium, canopy entrance, gatehouse and fence, roof plant, antenna masts with red beacons, 220-stud dark tower behind, changed emblem |
| Aki and Denji's apartment | Reinforced-concrete residential "mansion" block with tiled walls, balconies to the street, sliding glass doors, AC outdoor units, laundry poles, a stair core and a roof water tank | anime season 1 (episodes 2-12, apartment exterior shots); real Tokyo mansion form | `utility_poles_takadanobaba.jpg` (mansion in the background) | `Mansion` (hero): 7 storeys, 4 units per floor with balcony slab, parapet, handrail, dividers, windows (lit or dark), AC units and laundry; lobby, canopy, mailboxes, bike rack, stair core with lit slits, drainpipes, roof tank on legs, lift room, antenna, fence |
| Denji's first cheap housing / old Tokyo apartments | 2-storey wooden "apaato": siding walls, open steel corridor with railing, row of steel doors, washing machines outside, outside steel stair, shallow tin roof | anime season 1 (episode 1-2 street scenes) | (none) | `Apaato`: siding battens, 8 doors with meter boxes and small windows, corridor slab, railing and balusters, posts, steel stair, tin roof, gutter, gas cage |
| Street fronts and signs | Narrow mixed-use buildings with a shop at street level, half-open shutters, awnings, vertical projecting signs stacked down the corner, AC units hung on walls | anime street scenes; real Tokyo streets | `tokyo_night_skyline.jpg` | `ShopHouse` (shutter, awning, sign band with glyph blocks, windows, AC units, balcony, corner sign stack, roof tank); `SignTower` (freestanding lit sign stack) |
| Convenience store | Single-storey white box, glazed front with mullions over a bright interior with shelf rows, horizontal colour bands, an auto door, roof condensers, bins out front, a pole sign | real Tokyo konbini, often shown in the anime | (none) | `Konbini` (bands are violet and lime, not a real chain's colours) |
| Street furniture | Concrete utility poles with crossarms, insulators, transformer drums and dense sagging wires; vending machine rows at night; curved-arm street lamps; white guardrails on raised sidewalks; parked compact cars | real Tokyo street furniture | `utility_poles_takadanobaba.jpg`, `vending_night.jpg` | `Pole` (wires span pole to pole, 40 studs apart), `Vending`, `Lamp`, `Sidewalk`, `Car` |
| Skyline | Night Tokyo: tall office towers with lit window grids and red aircraft-warning beacons | https://commons.wikimedia.org/wiki/File:Tokyo_by_night_2011_(cropped).jpg | `tokyo_night_skyline.jpg` | `Office` (field-scattered, scaled 0.7-1.5) |

Other local refs: `vending_night.jpg` is from https://commons.wikimedia.org/wiki/File:Three_Vending_Machines_Japan_Night.jpg.
`utility_poles_takadanobaba.jpg` is from https://commons.wikimedia.org/wiki/File:Utility_poles_Takadanobaba.jpg.

Not matched: the anime's exact headquarters exterior has no confirmed real-world model, and no clean screenshot could
be fetched (the fan wiki blocks automated fetches). The `HQ` is therefore a Kasumigaseki-style government block and is
not a copy of a specific anime frame. The partners' apartment has no confirmed real address. The `Mansion` uses the
common Tokyo mansion form that the anime draws. No anime screenshots are stored for the street scenes.
