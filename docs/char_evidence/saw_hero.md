# saw_hero evidence

Id `saw_hero`, proposed display name Denjy. Based on: Denji, Chainsaw Man. Version: Human form only; the saw form is NOT this version.
Usage: public Roblox experience (roster draft, proposed). Rig: chunky R15 parts, `tools/blender/paint/char_saw_hero.py` on `tools/blender/build_avatar.py`.
Check date: 2026-11-05.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Hair | Scruffy blond (search summary of the fan wiki and Wikipedia) | supported | https://chainsaw-man.fandom.com/wiki/Denji |
| Eyes | Yellowish-brown with bags under them (search summary) | supported | https://chainsaw-man.fandom.com/wiki/Denji |
| Teeth | Sharp (search summary) | supported | https://chainsaw-man.fandom.com/wiki/Denji |
| Outfit | Shirt with rolled sleeves, black tie, black trousers, a laid-back take on the uniform (search summary) | supported | https://breezewiki.discard.no/chainsaw-man/wiki/Denji |
| Chest cord | He transforms by pulling a cord on his chest | supported | https://en.wikipedia.org/wiki/Denji_(Chainsaw_Man) |
| Hair colour detail | Orange-tinted blond in shaggy clumps | inferred | https://anilist.co/character/130102 |
| Loose tie | Knot pulled down, blade to one side | inferred | https://anilist.co/character/130102 |
| Cord handle shape | Short line ending in a small ring handle | inferred | Modelled from the text; no image viewed |

Source quality: fan-level text and one colour character image, viewed for look only and kept outside the repo. The fan wiki on Fandom and its mirror could not be opened (HTTP 402 and a bot block), so wiki text is only what the search summary quoted. No official model sheet was reached. Anything below the chest and the back of the figure is inferred from general knowledge of the design, not from a viewed image.
Text rows rest on search summaries, not on pages read in full; where a summary did not name its page, the URL is the likeliest from that result list, so treat those rows as weak.
Image viewed: AniList character portrait, https://anilist.co/character/130102.

## Contradictions and choices

- The brief's default is shirt, tie and loose suit. The wiki text gives no jacket. Chosen: no jacket, rolled sleeves, untucked. Owner may want a jacket.
- The cord is normally shown on the bare chest, not outside a buttoned shirt. Chosen: it hangs on the shirt front because it is his one tie to the saw form. Owner may prefer it removed.
- The viewed image has his tongue out. Chosen: a closed-tongue grin, which carries the teeth better.

## Project rules over source

- Chunky R15 block body, big head and plain block hands with no fingers (design doc section 5). This is the largest departure.
- Suit, shirt and tie are real meshes, with shading painted in.
- Marks: none on this character. The cord is treated as a prop, not an emblem; owner may rule otherwise.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Human form only; the saw form is NOT this version |
| Defining attributes | pass | Shaggy orange-blond hair and the toothy grin read at 110 px |
| Views agree | pass | Front, three-quarter and back viewed on review sheets each round; side viewed on rounds 1 and 3 |
| Below the chest, back | inferred | No lit reference reached |
| Camera readability | not checked | Thumbnail sheet at 110 px read; no in-game camera |
| Triangles | pass | 2852 total, of the 12000 budget |
| Hard facets, no outline | pass | `finish()` sets flat faces and no ink shell |
| Known weak spots | note | The hair alone could be a generic blond anime hero; the teeth carry the read. Cord handle is small and outside the portrait crop |
| In game | not checked | No Studio run, no upload |
| IP | label | Unlicensed reference |
