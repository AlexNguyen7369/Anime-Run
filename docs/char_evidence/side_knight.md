# side_knight evidence

Id `side_knight`, proposed display name Igriz. Based on: Igris, the Blood-Red Commander, Solo Leveling. Version: the red knight before he becomes a shadow soldier.
Usage: public Roblox experience (boss event sidekick, proposed). Rig: bespoke parts on chunky R15 proportions, `tools/blender/build_boss_event.py`: Torso, Head, LeftArm, RightArm, LeftLeg, RightLeg, Sword.
Check date: 2026-11-04.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Form | A knight who wears armour; plate design inferred from the still | supported | https://quotetheanime.com/solo-leveling/igris-wiki/ |
| Armour, first version | Red from top to bottom before he becomes a shadow | supported | https://quotetheanime.com/solo-leveling/igris-wiki/ |
| Armour, shadow version | Black from top to bottom, purple radiance | supported, not used | quotetheanime page above |
| Plume | Red hair accessory extending from the helmet | supported | quotetheanime page above |
| Cape | Tumbled-down cape; black in that text | supported, colour overridden | quotetheanime page above |
| Sword | A long sword | supported | quotetheanime page above |
| Helm | Tall pointed middle crest, layered flaring plates | inferred | Anime still, https://www.dexerto.com/anime/solo-leveling-episode-11-igris-preview-images-2603511; portrait, https://anilist.co/character/145722 |
| Eyes | Two white glowing slits, slanting up and out, in a dark V | inferred | Same still and portrait |
| Plume shape | Very long, arcs up from the crown and falls behind | inferred | Same still |
| Chest | Dark middle spine of stacked ribs, red slopes, silver four-point stars | inferred | Same still |
| Pauldrons | Large, angular, layered | inferred | Same still |
| Sword detail | Dark toothed base, long pale blade | inferred | Manhwa panel on the quotetheanime page |
| Cape shape | Huge, edges torn into hooked rags | inferred | Manhwa panel on the quotetheanime page |

Source quality: fan-level text, one anime still that shows only the head and shoulders, one anime close-up and manhwa panels mostly in silhouette. No full lit body view and no official sheet was reached. Arms below the shoulder, waist, legs and back are inferred from general plate-armour design and the silhouettes.

## Contradictions and choices

- Red or black: both are canon, for different times. Chosen: red, the name's own colour and the most recognisable, with dark parts. Kaizel uses its shadow look, so the two sidekicks come from different states of the same story. Owner may prefer black and purple here for consistency.
- Cape: text says black, while the red-armour still shows red cloth at the shoulder. Chosen: dark red.
- One page gives a horned helmet, white eyes and black armour. Taken as the shadow version. No curved horns modelled; the flaring plates take that place.

## Project rules over source

- Chunky R15 block body in place of the source's tall, lean, spiky figure (design doc section 5). This is the largest departure.
- Plain block gauntlets, no fingers.
- Sword held point-up beside the body, in the right hand: it cannot be held point-down at full length from a block arm without hitting the floor. The source often holds it diagonally. Its tip is the top of the bounding box.
- Marks: the four-point stars read as armour studs, not an emblem, so they are unchanged. Owner may rule otherwise; not entered in the marks ledger.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Red version only |
| Defining attributes | pass | Red plate, pointed helm, white slits, long plume, torn cape, long sword |
| Views agree | pass | All four views viewed on the contact sheet, some also at 1920x1080 |
| Below the shoulders, back | inferred | No lit reference reached |
| Camera readability | not checked | Line-up view reads; no in-game camera |
| Triangles | pass | 3688 total, largest mesh Head 792, of 20000 per mesh |
| Hard facets, no outline | pass | No smooth faces in the blend; no ink shell |
| Height ratio | pass | 34.5% of db_hero measured from render pixels (1 px is about 0.2%), whole bounding box (tip of the sword). Top of the crest without the sword: about 31.5%, scale computed from 6.34 of 7.05 model units |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
