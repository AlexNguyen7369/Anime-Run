# MHA character evidence and validation (internal, never ships)

Skill `design-roblox-anime-character`, checked 2026-11-03. Usage: private experience (handoff f3). Owner ruling 2026-11-03: designs match the source, only the display name differs; takedown risk accepted (design doc 5). The skill's license rule for public release stays open if the experience goes public. IP label for all five: **unlicensed reference**; no rights evidence on file. Rig: 6 rigid anchored parts moved by the server, not an avatar rig.

Sources: [W-Izuku](https://en.wikipedia.org/wiki/Izuku_Midoriya), [W-Bakugo](https://en.wikipedia.org/wiki/Katsuki_Bakugo), [W-Shoto](https://en.wikipedia.org/wiki/Shoto_Todoroki), [W-Ochaco](https://en.wikipedia.org/wiki/Ochaco_Uraraka), [W-List](https://en.wikipedia.org/wiki/List_of_My_Hero_Academia_characters). `All_Might` on Wikipedia redirects to W-List. W-Ochaco was read to 100,000 of 122,098 characters and W-List to 200,000 of 278,273. These pages describe costumes and hair very little. Fandom refused automated reads (HTTP 402), so it was not used. `inferred` = from `docs/CHARACTER_ART_REFERENCES.md`, whose per-character facts are model knowledge, not fetched text. Treat those rows as unverified. Version for all five: first-year student era costume; `mha_symbol` is the hero form, not the weakened form.

Brief for this series: student characters; every hero suit is non-revealing, with loose block forms and no skin-tight emphasis. Applied to all five.

## mha_hero (Izuku Midoriya, shown as Deko)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Suit colour | Teal, from his own sketch | supported, W-Izuku | Teal-green loose jumpsuit with dark lines |
| Dark green curly hair, green eyes, freckles | | inferred | Match |
| Hood with two tips | | inferred | Hood down, tips standing behind the jaw |
| White gloves, red boots with white soles | | inferred | Match |
| Steel mouth guard, belt | | inferred | Guard at the throat; belt with gold pouches (pouch colour is a guess) |
| Validation | 4,346 tris, lowest z 0.0, unlicensed reference | | |

## mha_blast (Katsuki Bakugo, shown as Bakugoo)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Ash-blond spikes, narrow red eyes | | inferred | Match |
| Black eye mask, orange edges | | inferred | Match, painted |
| Black top, orange X strap | | inferred | Match, front and back. Neckline closed to a high collar, a change from the source's open V neck |
| Grenade gauntlets, green with yellow bands, pin ring | | inferred | Match, built wider on the outside to clear the torso |
| Belt pouches, knee pads, black and orange boots | | inferred | Match |
| Validation | 5,562 tris, lowest z 0.0, unlicensed reference | | |

## mha_icefire (Shoto Todoroki, shown as Todoroky)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Scar around his left eye | Yes, a burn | supported, W-Shoto | Viewer's right |
| Ice from the right side, fire from the left | Yes | supported, W-List | Crystals on the viewer's left shoulder; fire left for VFX |
| Hair split white and red, centre part | Right side white, left side red | inferred | Match |
| Heterochromia | Category on W-Shoto; grey right, turquoise left inferred | supported in part, W-Shoto | Match |
| Navy suit, silver zip, white belt, brown boots | | inferred | Match, plus a silver chest harness (inferred) |
| Validation | 3,784 tris, lowest z 0.0, unlicensed reference | | |

**Mixed form:** the shoulder ice stands in for a power in use; the suit is the plain costume.

## mha_float (Ochaco Uraraka, shown as Ochaku)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| Permanent blush | Yes | supported, W-Ochaco | Painted cheek circles |
| Fingertip pads | Yes | supported, W-List | Omitted: hands are plain blocks by rule |
| Brown bob with two long front locks, big brown eyes | | inferred | Match |
| Black and pink suit, ring collar, chunky cuffs, pink-soled boots, white belt | | inferred | Match in colours; panel layout simplified, cut loose and boxy with no body emphasis |
| Helmet with visor | | inferred | Omitted so the hair and face read |
| Validation | 3,494 tris, lowest z 0.0, unlicensed reference | | |

W-Ochaco reports the author's intent of a solidly built figure. The model ignores it: the body stays the standard R15 blocks.

## mha_symbol (All Might, shown as All Mighty)
| Attribute | Canon | Status | Model |
|---|---|---|---|
| "American looks" | Yes | supported, W-List | Heavy square jaw, wide grin, cheek lines |
| Two tall blond bang spikes in a V, short back spikes | | inferred | Match |
| Blue eyes in deep shadow, wide grin | | inferred | Match |
| Blue suit, V chest band, yellow gloves, red boots, short red cape | | inferred | Match, plus white band edges and a yellow belt |
| Huge muscular build | | inferred | Not matched: body stays R15 blocks by rule; broad shoulder and chest plates add bulk |
| Validation | 3,262 tris, lowest z 0.0, unlicensed reference | | |
