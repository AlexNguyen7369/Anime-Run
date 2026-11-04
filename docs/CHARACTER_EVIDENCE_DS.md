# DS series character evidence and validation (internal, never ships)

Skill `design-roblox-anime-character`, checked 2026-11-03. Usage: private experience. Owner ruling 2026-11-03: designs match the source, only the display name differs (design doc 5). IP label for all five: **unlicensed reference**; no rights evidence on file. The skill's license rule for public release stays open if the experience goes public. Models are hand-built; no ripped models, textures or image files.

Sources: [W-List](https://en.wikipedia.org/wiki/List_of_Demon_Slayer:_Kimetsu_no_Yaiba_characters) (first 100,000 of 138,217 characters read; the Zenitsu and Rengoku URLs show the same list page), [W-Tanjiro](https://en.wikipedia.org/wiki/Tanjiro_Kamado), [W-Nezuko](https://en.wikipedia.org/wiki/Nezuko_Kamado). Those pages describe almost no visual detail. Fandom refuses automated reads (HTTP 402), so it was not used. `inferred` = from `docs/CHARACTER_ART_REFERENCES.md`, whose per-character facts come from model knowledge, not a fetched source.

## ds_hero (Tanjiro Kamado)
| Attribute | Value | Status |
|---|---|---|
| Earrings | Hanafuda; card with red sun and rays. Rising Sun-style elements were retouched in China | supported, W-List, W-Tanjiro |
| Sword | Black blade; model shows black sheath and handle | supported, W-List |
| Forehead scar | Exists in the design; shape and side not described | supported (existence), W-Tanjiro; shape inferred |
| Dark red hair with bright tips, wine-red eyes | Match | inferred |
| Green and black check coat, black uniform, white belt, white wraps, sandals | Match | inferred |

## ds_sister (Nezuko Kamado)
| Attribute | Value | Status |
|---|---|---|
| Bamboo muzzle | "wears a bamboo muzzle"; modelled as a bar with red ties | supported, W-Nezuko |
| Younger sister of ds_hero | Treated as a child: fully covered, high collar, kimono to the shins | supported, W-Nezuko |
| Black hair with orange ends, to the thighs (references say knees), pink eyes, pink bow | Match, hair shorter | inferred |
| Pink hemp-leaf kimono, checked obi, green cord, dark red check coat, white wraps | Match | inferred |

## ds_thunder (Zenitsu Agatsuma)
| Attribute | Value | Status |
|---|---|---|
| Sword | Yellow; model shows a yellow handle, the blade stays sheathed | supported, W-List |
| Gold hair with orange tips, frightened face, tears | Match | inferred |
| Yellow to orange coat with white triangles, black uniform, wraps, sandals | Match | inferred |

## ds_boar (Inosuke Hashibira)
| Attribute | Value | Status |
|---|---|---|
| Boar-head mask | "wears the head of his deceased boar mother as a mask" | supported, W-List |
| Two swords | "two serrated, indigo-gray" | supported, W-List |
| Bare torso | Kept from the references; a plain skin block with no anatomy drawn | inferred |
| Fur belt, dark wide trousers, black and white diamond wraps, bare feet | Match | inferred |

## ds_flame (Kyojuro Rengoku)
| Attribute | Value | Status |
|---|---|---|
| Sword guard | Mentioned, shape not described; model uses a plain round guard, not the flame shape | supported (existence), W-List; shape inferred |
| Gold hair with red tips, gold eyes ringed red, forked brows, grin | Match | inferred |
| White coat with flame hem, black uniform, wraps, sandals | Match | inferred |

## Validation
| Check | ds_boar | ds_flame | ds_hero | ds_sister | ds_thunder |
|---|---|---|---|---|---|
| Tris (cap 12,000) | 4,466 | 4,290 | 4,530 | 4,516 | 4,290 |
| Lowest z | 0 | 0 | 0 | 0 | 0 |
| Merged parts | 6 | 6 | 6 | 6 | 6 |
| IP label | Unlicensed reference | Unlicensed reference | Unlicensed reference | Unlicensed reference | Unlicensed reference |
