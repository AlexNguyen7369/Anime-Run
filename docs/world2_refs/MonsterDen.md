# World 2 Track 8 `MonsterDen`: source references

Source: One Punch Man (manga Monster Association arc, anime season 2). Look-only references for the Blender draft
`tools/blender/world2/biomes/MonsterDen.py`. The images sit in `build/world2/refs/MonsterDen/` (gitignored). They never
ship and nothing is traced or copied from them. Every prop is built in-house from primitives. No text and no symbols
(design doc 5).

| Landmark | Visual facts | Source | Local ref | Prop |
|---|---|---|---|---|
| The lair as an underground tower | Round stacked stone floors with wide ledges, which give a mushroom-like silhouette. It has arched openings, outside staircases, a broken colonnade at the top, tentacles breaking out of the walls, and a mine-cart rail ring on a timber base at its foot. | https://onepunchman.fandom.com/wiki/Monster_Association_Headquarters | `Monster_Association_HQ_Volume_23.ref.jpg`, `Hologram_of_the_Monster_Association_Headquarters.ref.jpg` | `LairTower` (hero, infield) |
| Central hall / throne room | A round hall walled with horizontal stone tiers separated by dark gaps. It has tall poles and a cracked flagstone floor. The king's throne sits on a raised dais. | https://onepunchman.fandom.com/wiki/Monster_Association_Headquarters | `Monster_Association_Headquarters_Anime_Profile.ref.jpg`, `The_Monster_Association.ref.jpg`, `Gyoro_Gyoro_and_Monster_King_Orochi.ref.jpg` | `Coliseum` (hero, open toward the road in the cavern a third of the way in) |
| The shrine deep below | A stepped stone temple with a wide central staircase and side balustrades. Every tier has square niche blocks and pillar posts with caps. A relief wall stands at the top. It sits in a rock alcove over a lava sea. | https://onepunchman.fandom.com/wiki/Z-City_Ghost_Town (The Mysterious Shrine) | `The_Mysterious_Shrine_Manga.ref.jpg` | `Shrine` (hero, lava cavern at the finish; the relief is a blank slab with bumps) |
| Underground gold veins | Mine railway on timber, ore carts, gold and ruby veins. | https://onepunchman.fandom.com/wiki/Monster_Association_Headquarters | (described on the wiki page; no image kept) | `MineRail` (with gold and ruby veins), `RockPillar` (veins at its foot) |
| Graveyard of the underground people | Broken flagstones and boulders among round, ring-banded dome helmets. | https://onepunchman.fandom.com/wiki/Monster_Association_Headquarters | `Subterranean_graveyard.ref.jpg` | `Graveyard` |
| Base torn out of the ground / old city above | Rock mass with surface city blocks, pipes and towers embedded and tilted. | https://onepunchman.fandom.com/wiki/Monster_Association_Headquarters | `Tatsumaki_lifts_Monster_Association_base_out_of_ground.ref.jpg` | `CityChunk` (rock mass with embedded tilted buildings, pipes, pylon), `Colonnade` |
| Organic lair walls | Monster flesh and bone growing through the rock (tentacles and maws in the Volume 23 cut-away). | Volume 23 plan | `Monster_Association_HQ_Volume_23.ref.jpg` | `FleshWall`, `Ceiling` rib arches, `BoneArch` |

Not matched 1-1: the source gives no single clear image of "mushroom-shaped buildings". The tower's wide round
ledges stand in for them. Characters (the king, the eyeball leader) are never modelled. The throne's back is an
in-house spike fan. The real lair is far more vertical than a race track allows, so the draft lays its pieces out as
cavern set pieces along the road.

Round 2 (2026-11-23): the open caverns keep a near-black sky, with rock vault shelves, pillars and lava chasms. The ribs are bone-ivory on dark wet rock; flesh is used only on the flesh walls. The three hero landmarks now sit inside the 33%, 62% and 90% run views (the shrine faces the runner head-on). `Crystals`, `PipeRun` and `RuinBlock` were folded into `MineRail`, `RockPillar` and `CityChunk`; `LavaChasm` was added.
