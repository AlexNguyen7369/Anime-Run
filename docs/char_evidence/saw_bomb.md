# saw_bomb evidence

Id `saw_bomb`, proposed display name Rezi. Based on: Reze, Chainsaw Man. Version: Cafe worker.
Usage: public Roblox experience (roster draft, proposed). Rig: chunky R15 parts, `tools/blender/paint/char_saw_bomb.py` on `tools/blender/build_avatar.py`.
Check date: 2026-11-05.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Hair | Short, black with purple tones (fan page) | supported | https://shapes.inc/rezechainsawman |
| Eyes | Green (fan page; agrees with the image) | supported | https://shapes.inc/rezechainsawman |
| Choker | Black choker, part of her series look | supported | https://www.siliconera.com/reze-joins-chainsaw-man-bunny-girl-figure-collection/ |
| Apron | Wears an apron at the cafe (search summary of the fan wiki) | supported | https://breezewiki.discard.no/chainsaw-man/wiki/Reze |
| Blouse, ribbon, skirt | White collared shirt, thin black ribbon, dark high-waisted skirt (cosplay guide) | supported | https://origin-exchange.autodesk.com/reze-cosplay |
| Bang | Long sweep hiding most of one eye | inferred | https://anilist.co/character/148740 |
| Knot | Small knot behind one ear | inferred | https://anilist.co/character/148740 |
| Sleeves, apron colour, shoes | Rolled sleeves, dark apron, flat dark shoes, bare legs | inferred | No source reached |

Source quality: fan-level text and one colour character image, viewed for look only and kept outside the repo. The fan wiki on Fandom and its mirror could not be opened (HTTP 402 and a bot block), so wiki text is only what the search summary quoted. No official model sheet was reached. Anything below the chest and the back of the figure is inferred from general knowledge of the design, not from a viewed image.
Text rows rest on search summaries, not on pages read in full; where a summary did not name its page, the URL is the likeliest from that result list, so treat those rows as weak.
Image viewed: AniList character portrait, https://anilist.co/character/148740.

## Contradictions and choices

- Choker ring: one fan page mentions a pin on the choker, unconfirmed. Chosen: a small plain steel ring, modelled in-house.
- Apron colour and style were not found. Chosen: dark waist apron over the skirt; this is the least certain part of the outfit.
- The cosplay guide sits on an odd host and is weak evidence for the outfit.

## Project rules over source

- Chunky R15 block body, big head and plain block hands with no fingers (design doc section 5). This is the largest departure.
- Suit, shirt and tie are real meshes, with shading painted in.
- Marks: none on this character.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Cafe worker |
| Defining attributes | pass | Bob, covered eye, green eye and choker read at 110 px |
| Views agree | pass | Front, three-quarter and back viewed on review sheets each round; side viewed on rounds 1 and 3 |
| Below the chest, back | inferred | No lit reference reached |
| Camera readability | not checked | Thumbnail sheet at 110 px read; no in-game camera |
| Triangles | pass | 3266 total, of the 12000 budget |
| Hard facets, no outline | pass | `finish()` sets flat faces and no ink shell |
| Known weak spots | note | Apron and skirt merge into one dark shape; the hair's side is a flat dark block in the portrait |
| In game | not checked | No Studio run, no upload |
| IP | label | Unlicensed reference |
