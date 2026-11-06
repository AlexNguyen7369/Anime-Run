# side_pig evidence

Id `side_pig`, proposed display name Hawke. Based on: Hawk, The Seven Deadly Sins. Version: the ordinary talking pig, not the armoured or giant forms.
Usage: public Roblox experience (Sidekick, Common, Walk, draft for owner approval). Rig: named parts in `tools/blender/sidekicks/side_pig.py`: Body, Head, HeadEarLeft, HeadEarRight, Tail, four Leg parts.
Check date: 2026-11-05.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Species and role | Talking pig, cleaner of the bar | supported | https://anilist.co/character/86683 |
| Colour | Pink | supported | Same page; anime stills https://static0.cbrimages.com/wordpress/wp-content/uploads/2020/06/Hawk-Ston-Floor-e1593413511318.jpg and https://static0.cbrimages.com/wordpress/wp-content/uploads/2022/04/Seven-Deadly-Sins-Hawk.jpg |
| Body | Well rounded, fairly short legs | supported | https://anilist.co/character/86683 |
| Mark | Patch of black spots shaped like a four-leaf clover | supported | https://anilist.co/character/86683 |
| Earring | On the left ear, with words on it | supported, words left out | Same page; tag visible in the first still above |
| Mark position | Left flank | inferred | The text gives no position; the brief says "on its side" |
| Face | Wide flat oval snout, two upright slit nostrils, small upright eye with a glint, small crease above it, round blush below | inferred | The two stills above and the AniList portrait |
| Ear | Long, folds over and hangs past the eye | inferred | Same stills |
| Hooves | Dark brown | inferred | Same stills |
| Tail | Thin, curled in a loop | inferred | Second still above |

Source quality: one short database text and a few anime stills, mostly head and shoulders. The fandom wiki was blocked (HTTP 402 and 403). The back and underside were not seen.

## Contradictions and choices

- Text says a "relatively large" pig; the Sidekick rule makes every Sidekick the same small ratio. Size follows the rule.
- Mark: no still reached shows the clover patch, so its look rests on the text alone. Chosen: four separate round black spots on the left flank. The owner may want it elsewhere.
- Mouth: stills range from closed to wide open. Chosen: a small open grin with tongue, for his talking character.

## Project rules over source

- Hard facets and painted shading (design doc section 5) replace the smooth round anime body. Only Pochito has a smooth ruling, so none is assumed here.
- Earring is a plain metal tag with no lettering.
- Legs are block legs, longer than the source so the block silhouette reads.
- Marks: the clover is modelled in-house. It is not yet listed in `docs/CHARACTER_ART_REFERENCES.md`: outside this draft's files.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Ordinary form only |
| Defining attributes | pass | Pink, round, wide snout, blush, hanging ears, clover spots, tag earring, curled tail |
| Views agree | pass | Four views viewed. From the back the ear reads as a thin hoop |
| Back, underside | inferred | No reference reached |
| Camera readability | not checked | Portrait read at 110 px; no in-game camera |
| Triangles | pass | 2432 total, largest mesh 776, of 20000 per mesh |
| Hard facets, no outline | pass | No smooth faces requested; no ink shell |
| Height ratio | not measured | 2.77 model units; to be scaled to 35% of a character on import. Not in a line-up render |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
