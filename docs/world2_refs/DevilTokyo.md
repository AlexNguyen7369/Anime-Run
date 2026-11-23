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
| Public Safety headquarters | Large government office building in central Tokyo. No confirmed real model; guides suggest a composite of Kasumigaseki and Nagatacho government buildings: pale grey blocks with deep projecting horizontal floor slabs and recessed ribbon windows | https://www.japan-pop-now.com/articles/chainsaw-man-pilgrimage-tokyo (speculative); https://commons.wikimedia.org/wiki/File:Central-Government-Building-4-01.jpg | `gov_building4.jpg` | `HQ` (hero, the tallest mass in town): 3 stepped tiers, deep floodlit slabs, sparse lit offices, a lit forecourt (floor strips, bollards, planters, bare flag poles), and a changed emblem (lit ring, dark disc, lit diamond, 26 studs) on the top roof edge. Two are placed at the end of the street axis that the 0.62 and 0.9 run cameras look down |
| Aki and Denji's apartment | Reinforced-concrete residential "mansion": balconies on one face; on the other an open corridor with a concrete parapet and rail, a row of steel doors with meter boxes, ceiling lights and lit stair slits | anime season 1 (episodes 2-12, apartment exterior and corridor shots); real Tokyo mansion form | `utility_poles_takadanobaba.jpg` (mansion in the background) | `Mansion` (hero): 7 storeys. Balcony face: sliding doors, AC units, laundry. Corridor face: walkway, parapet, rail, doors, meter boxes, lights. Sides: window grids, AC units, drainpipes, tile bands at every floor. Lobby, stair core, roof tank. Half the front-row mansions turn their corridor face to the road |
| Denji's first cheap housing / old Tokyo apartments | 2-storey wooden "apaato": siding walls, open steel corridor with railing, row of steel doors, washing machines outside, outside steel stair, shallow tin roof | anime season 1 (episode 1-2 street scenes) | (none) | `Apaato`: siding, 8 doors, corridor and railing, steel stair, tin roof, side windows, and a cluster of 3 vending machines with a bin |
| Narrow streets | Narrow residential streets: raised kerb, white guardrails, dark pavement, curved-arm lamps casting warm pools, concrete utility poles with transformer drums, dense sagging wires and cable bundles, wires crossing over the street | real Tokyo street furniture; anime street scenes | `utility_poles_takadanobaba.jpg` | `StreetKit` (48 studs, both sides): pavement, kerb, tactile strip, guardrail, sodium lamp and pool, 2 poles (drum on the second), 8 wires per span incl. 2 thick bundles, and 3 wires crossing the street 22+ studs up |
| Street fronts, signs, vending machines | Shops with half-open shutters, awnings, narrow vertical signs stacked down building corners, AC units, and bright red and white vending machines against the walls | anime street scenes; real Tokyo streets | `vending_night.jpg`, `tokyo_night_skyline.jpg` | `ShopHouse` (shutter, awning, glyph sign band, front and side windows, narrow dark-framed corner sign stacks, a vending pair with bin); `Konbini` (violet and lime bands, not a real chain's colours, plus a vending pair) |
| Back streets (infield) | Coin parking, small 2-storey houses, pocket parks behind the main streets | real Tokyo back streets | (none) | `LowBlock` (100 x 100): parking with stall lines, 2 cars, a pay machine, a hipped-roof house, a park with trees and a bench, a row of small houses, a lamp |
| Jinbocho corner (Reze film) | The film's Jinbocho scenes: a retro tiled building and the phone booth | https://tabimaniajapan.com/japan-trip/kanto/tokyo/chainsaw-man-reze-arc-pilgrimage-real-life-locations-in-tokyo | (none) | `Retro` (once, near the start): brown-tile 3-storey building with arched windows, cornice, lit cafe glazing and striped awning, and a lit green phone booth |
| Skyline | Night Tokyo: office towers with lit window grids and red aircraft-warning beacons, kept lower than the HQ | https://commons.wikimedia.org/wiki/File:Tokyo_by_night_2011_(cropped).jpg | `tokyo_night_skyline.jpg` | `Office` (field-scattered, scaled 0.5-0.85) |

Wall colours vary per building instance (off-white, grey concrete, brown tile, green) through an object-random material in
the draft. The game will need a colour per instance in the same way.

Other local refs: `vending_night.jpg` is from https://commons.wikimedia.org/wiki/File:Three_Vending_Machines_Japan_Night.jpg.
`utility_poles_takadanobaba.jpg` is from https://commons.wikimedia.org/wiki/File:Utility_poles_Takadanobaba.jpg.

Not matched: the anime's exact headquarters exterior has no confirmed real-world model, and no clean screenshot could
be fetched (the fan wiki blocks automated fetches). The `HQ` is therefore a Kasumigaseki-style government block and is
not a copy of a specific anime frame. The Jinbocho phone booth's exact design is not copied. The partners' apartment has no confirmed real address. The `Mansion` uses the
common Tokyo mansion form that the anime draws. No anime screenshots are stored for the street scenes.
