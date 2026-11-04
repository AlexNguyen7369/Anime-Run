# Pilot character evidence and validation (internal, never ships)

Skill `design-roblox-anime-character`, checked 2026-11-03. Usage: private experience (handoff f3). Owner ruling 2026-11-03: designs match the source, only the display name differs; the vest stays; takedown risk accepted (design doc 5). The skill's license rule for public release stays open if the experience goes public. Rig: 6 rigid anchored parts moved by the server, not an avatar rig. IP label for all four: **unlicensed reference**; no rights evidence on file. Owner's target image overrides canon where noted (design doc 5).

Sources: [W-Luffy](https://en.wikipedia.org/wiki/Monkey_D._Luffy), [W-Goku](https://en.wikipedia.org/wiki/Goku), [W-Naruto](https://en.wikipedia.org/wiki/Naruto_Uzumaki), [W-Sakura](https://en.wikipedia.org/wiki/Sakura_Haruno). Wikipedia was read to 100,000 characters per page. Fandom refused automated reads (HTTP 402), so its text was not used. `inferred` = from wiki infobox images or the owner's image, no text source read.

## sea_captain (Luffy)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Hat | Straw with red ribbon | supported, W-Luffy | Match |
| Earlier outfit | Red vest, denim shorts, sandals | supported, W-Luffy | Vest, shorts, sandals |
| Later outfit | Red unbuttoned coat, yellow sash | supported, W-Luffy | Sash only |
| X chest scar | From a later fight; visible with the open coat | supported, W-Luffy | Present |
| Scar under left eye | Yes | supported, W-Luffy | Match |
| Black hair, fur cuffs | | inferred | Match |

**Mixed form:** the vest is the earlier look; the sash and X scar are the later one. Comes from the owner's image.

## db_hero (Goku)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Gi colour | Buddhist-robe colour | supported, W-Goku (colour not named) | Orange |
| Black spiked hair, blue undershirt, belt, wristbands | | inferred | Match |
| Boots | Blue with red trim and tan rope on the wiki image; yellow trim and red rope in the owner's image | inferred, conflict | Owner's image |
| Chest disc | On the wiki image; absent in the owner's image | inferred, conflict | Source: chest and back discs |

## leaf_medic (Sakura)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Pink hair, green eyes | Yes | supported, W-Sakura | Match |
| Broad forehead | Her best-known feature | supported, W-Sakura | Partly: fringe and plate cover it |
| Part II top | Karate-suit style, Chinese feel | supported, W-Sakura | Zipped vest |
| Forehead seal | Named, shape not described | supported name; diamond inferred | Violet diamond |
| Band, gloves, guards, apron, boots | | inferred | Owner's image |

## leaf_hero (Naruto)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Blond spiky hair, blue eyes | Yes | supported, W-Naruto | Match |
| Part II outfit | Orange and black top, orange pants, **black sandals** | supported, W-Naruto | Top and pants match; open-toe boots from the owner's image |
| Wider headband in Part II | Yes | supported, W-Naruto | Match |
| Spiral motif | Yes | supported, W-Naruto | Shoulder badge from the owner's image, red swirl on the back |
| Whiskers | Not in the text read | inferred | Present |

## Validation
| Check | sea_captain | db_hero | leaf_medic | leaf_hero |
|---|---|---|---|---|
| Tris (project cap 12,000; any mesh 20,000) | 7,980 | 4,324 | 5,538 | 6,730 |
| Material / atlas | 1 / 1024 | 1 / 1024 | 1 / 1024 | 1 / 1024 |
| Root at origin, 6 parts | Yes | Yes | Yes | Yes |
| Lowest z | 0 | 0 | 0 | 0 |

Skill rejects "fused hands": plain block hands are an explicit owner rule, kept (design doc 5). Bone influences do not apply: rigid parts, no armature. Roblox avatar tri budgets do not apply to this custom rig.

## Manifest
| Id | Version | Usage | Files | Asset | IP label | Open issues |
|---|---|---|---|---|---|---|
| sea_captain | Vest + later sash and scar (owner) | Private | `tools/blender/paint/char_sea_captain.py`, `assets/characters_avatar/sea_captain/` | 92259398998895 | Unlicensed reference | Mixed form accepted by owner |
| db_hero | Base form | Private | `tools/blender/paint/char_db_hero.py`, `assets/characters_avatar/db_hero/` | 139186488737019 | Unlicensed reference | Trouser fold contrast; yellow boot trim vs source red |
| leaf_medic | Part II | Private | `tools/blender/paint/char_leaf_medic.py`, `assets/characters_avatar/leaf_medic/` | 99203486532029 | Unlicensed reference | Grey wedge under plate; forehead not fully broad |
| leaf_hero | Part II | Private | `tools/blender/paint/char_leaf_hero.py`, `assets/characters_avatar/leaf_hero/` | 99496724338450 | Unlicensed reference | Open-toe boots vs source sandals; side-view torso slivers |
