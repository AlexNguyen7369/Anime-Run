# Leaf series character evidence and validation (internal, never ships)

Skill `design-roblox-anime-character`, checked 2026-11-03. Usage: private experience (handoff f3). Owner ruling 2026-11-03: designs match the source, only the display name differs (design doc 5). Models are hand-built. IP label for all three: **unlicensed reference**; no rights evidence on file.

Sources: [W-Sasuke](https://en.wikipedia.org/wiki/Sasuke_Uchiha) (read to 100,000 characters), [W-Kakashi](https://en.wikipedia.org/wiki/Kakashi_Hatake), [W-Itachi](https://en.wikipedia.org/wiki/Itachi_Uchiha), and `docs/CHARACTER_ART_REFERENCES.md`. Wikipedia says little about outfits. Fandom refuses automated reads (HTTP 402), so its text was not used. `inferred` = from the references doc or general knowledge of the source, no text source read.

## leaf_avenger (Sasuke, Part II, Hebi outfit)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Part II clothing | Japanese clothing | supported, [W-Sasuke](https://en.wikipedia.org/wiki/Sasuke_Uchiha) | White high-collar shirt, hip cloth |
| Sword | Straight *chokutō* | supported, W-Sasuke | Straight sword, sheathed, close across the lower back |
| Clan symbol | Fan (*uchiwa*) | supported, W-Sasuke (colours and place inferred) | Red-over-white fan, upper back |
| Blue-black duck-tail spikes, long side bangs, dark eyes | | inferred | Match |
| Purple rope belt, big bow at the back, navy hip cloth, arm guards, sandals | | inferred | Match |
| Open shirt, bare chest | Open in the source | inferred | **Differs:** dark undershirt closes it (brief: modest, minor) |
| Headband | Not worn in this outfit | inferred | None, so no plate |

## leaf_copycat (Kakashi)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Mask | Covers most of the face | supported, [W-Kakashi](https://en.wikipedia.org/wiki/Kakashi_Hatake) | Modelled shell to the nose |
| Eyes | Appear half-asleep | supported, W-Kakashi | Half-lidded visible eye |
| Red copied eye | Has one | supported, W-Kakashi | Covered by the plate, none drawn (references doc) |
| Silver spikes leaning to one side | | inferred | Match; lean towards his left, the side the band falls |
| Band slanted over his left eye | | inferred | Match; pilots' plate |
| Green vest with chest pouches, navy top and trousers, shin wraps, sandals, thigh pouch | | inferred | Match |
| Red spirals on sleeves and vest back | | inferred (references doc) | Match |
| Fingerless glove with metal plate | | inferred | **Partly:** plate moved to the cuff, because hands stay plain skin blocks (brief) |
| Eye scar | | inferred | Not modelled: under the plate |

## leaf_crow (Itachi, cloak)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Red patterned eye | Has one | supported, [W-Itachi](https://en.wikipedia.org/wiki/Itachi_Uchiha) | Dark default; red kept for effects (references doc) |
| Long high-collared black cloak, red lining, white-edged red clouds | | inferred | Match, ankle length |
| Long centre-parted bangs, low ponytail | | inferred | Match |
| Lines under the eyes | | inferred | One long line each side, from the inner eye |
| Plate with a horizontal slash | | inferred | Match; pilots' plate |
| Ring, nail polish | | inferred | Left out: hands stay plain blocks |

## Validation
Measured on the built `.blend` files, merged parts.

| Check | leaf_avenger | leaf_copycat | leaf_crow |
|---|---|---|---|
| Tris (cap 12,000) | 5,552 | 5,820 | 5,516 |
| Lowest z | 0.0 | 0.0 | 0.0 |
| Parts | 6 | 6 | 6 |
| IP label | unlicensed reference | unlicensed reference | unlicensed reference |
