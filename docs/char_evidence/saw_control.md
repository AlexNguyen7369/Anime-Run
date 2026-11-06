# saw_control evidence

Id `saw_control`, proposed display name Makina. Based on: Makima, Chainsaw Man. Version: Public Safety shirt and tie, no coat.
Usage: public Roblox experience (roster draft, proposed). Rig: chunky R15 parts, `tools/blender/paint/char_saw_control.py` on `tools/blender/build_avatar.py`.
Check date: 2026-11-05.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Hair | Long red hair tied in a single braid | supported | https://en.wikipedia.org/wiki/Makima |
| Eyes | Yellow, ringed with red concentric circles | supported | https://en.wikipedia.org/wiki/Makima |
| Outfit | White dress shirt tucked into suit trousers, black necktie (search summary of a fan site) | supported | https://quotetheanime.com/makima/ |
| Bangs | Straight across, with long locks framing the face | inferred | https://anilist.co/character/137080 |
| Braid path | Comes forward over one shoulder | inferred | https://anilist.co/character/137080 |
| Tie colour | The image paints it dark navy; text says black | inferred | https://anilist.co/character/137080 |
| Belt, shoes | Dark belt, dark shoes | inferred | Not seen in the image |

Source quality: fan-level text and one colour character image, viewed for look only and kept outside the repo. The fan wiki on Fandom and its mirror could not be opened (HTTP 402 and a bot block), so wiki text is only what the search summary quoted. No official model sheet was reached. Anything below the chest and the back of the figure is inferred from general knowledge of the design, not from a viewed image.
Text rows rest on search summaries, not on pages read in full; where a summary did not name its page, the URL is the likeliest from that result list, so treat those rows as weak.
Image viewed: AniList character portrait, https://anilist.co/character/137080.

## Contradictions and choices

- Coat: one weak, likely AI-written page adds a long black coat. Not used; shirt and tie are the brief.
- Braid over the shoulder or down the back: both appear in general memory; the viewed image shows it forward. Chosen: forward, so it shows from the front and in the portrait. It starts at the back of the neck. Owner may prefer it behind.
- Hair tone: one round read too pink, so it was pulled back towards red.

## Project rules over source

- Chunky R15 block body, big head and plain block hands with no fingers (design doc section 5). This is the largest departure.
- Suit, shirt and tie are real meshes, with shading painted in.
- Marks: none on this character. The eye rings are a defining eye design, not a logo.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Public Safety shirt and tie, no coat |
| Defining attributes | pass | Ringed yellow eyes, blunt bangs and the braid read at 110 px |
| Views agree | pass | Front, three-quarter and back viewed on review sheets each round; side viewed on rounds 1 and 3 |
| Below the chest, back | inferred | No lit reference reached |
| Camera readability | not checked | Thumbnail sheet at 110 px read; no in-game camera |
| Triangles | pass | 3568 total, of the 12000 budget |
| Hard facets, no outline | pass | `finish()` sets flat faces and no ink shell |
| Known weak spots | note | The blunt bangs are a flat face with little strand detail; the hair's side is a flat red block in the portrait; the back of the hair does not show the braid strongly |
| In game | not checked | No Studio run, no upload |
| IP | label | Unlicensed reference |
