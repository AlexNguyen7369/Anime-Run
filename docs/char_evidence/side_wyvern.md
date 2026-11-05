# side_wyvern evidence

Id `side_wyvern`, proposed display name Kaizel. Based on: Kaisel, Solo Leveling. Version: the shadow wyvern of anime season 2.
Usage: public Roblox experience (boss event sidekick, proposed). Rig: bespoke parts, `tools/blender/build_boss_event.py`: Body, Neck, Head, WingLeft, WingRight, Tail, LegLeft, LegRight. Non-humanoid.
Check date: 2026-11-04.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Kind | Wyvern, a mount, shadow of the Demon King's mount | supported | https://anilist.co/character/184546 |
| Scales | Large wyvern, black scales, sharp teeth | supported | https://solo-leveling.fandom.com/wiki/Kaisel (search summary only) |
| Glow | Glowing neck and underbelly, wings, horns | supported, colour overridden | Fandom summary above, which says purple |
| Tail | Long and black | supported | Fandom summary above |
| Colour of the glow | Cyan-blue wing membranes and belly | inferred | Official shadow visual, season 2, https://animetv-jp.net/news/solo-leveling-season-2-arise-from-the-shadow-reveals-shadow-kaisel-visual |
| Neck | Long, arching S | inferred | Same visual |
| Belly | Bright, crossed by dark seams in bands | inferred | Same visual |
| Head | Narrow wedge, sharp snout, small violet eye, spiked brow | inferred | Same visual |
| Horns | Long pale horns swept up and back, shorter ones below | inferred | Same visual; portrait, https://anilist.co/character/184546 |
| Cracks | Thin glowing lines over black limbs and neck | inferred | Same visual |
| Claws | Pale curved claws on hind feet and wing | inferred | Same visual |

Source quality: the shadow visual is official but only shows part of the body, cropped at the wing and with no front or rear view. Fandom appeared only as a search summary and was not read. An AI avatar page calling it a fire-breathing Black Dragon was rejected. Wing outline, leg stance and back are inferred.

## Contradictions and choices

- Purple or cyan glow: Fandom text says purple, the official visual is cyan. Chosen: cyan, the official art.
- Living or shadow form: the manhwa portrait shows it pale with orange eyes before the shadow extraction. Chosen: the black shadow form, the only official colour art reached. The brief names the wyvern, not the state.
- Pose: owner 2026-11-04, it flies. Body angled, chest high, legs tucked, wings spread, tail trailing, nothing on the ground.

## Project rules over source

- Owner ruling, design doc 4.36: a thin wyvern, not a bulky dragon, in place of section 5's chunky build. Hard facets stay.
- Claws are modelled: the plain hand rule covers humanoid hands.
- Blue parts are separate meshes for Material Neon, emissive in the renders. Horns, claws and the violet eye are not neon: the owner named the blue parts.
- No marks: cracks and belly bands are skin, so no shape change applies.

## Changes

- 2026-11-04, owner review: torso, neck, legs and tail slimmed by about half, wings kept large with thinner bones. Flying pose. Neon parts split out.
- Neon meshes: WingNeonLeft, WingNeonRight, BodyNeon, NeckNeon, HeadNeon, TailNeon, LegNeonLeft, LegNeonRight. Each is a child of the part it moves with.
- Wings: WingLeft and WingRight have their origin at the wing root; rotate them to flap, and the neon child follows (checked by rotating WingLeft in the blend). No animation frames made.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Shadow form only |
| Defining attributes | pass | Black scales, cyan wings and belly, long neck, swept pale horns, long tail |
| Views agree | pass | All four views viewed on the contact sheet, some also at 1920x1080 |
| Back, wing outline | inferred | No reference reached |
| Camera readability | not checked | Line-up view reads; no in-game camera |
| Triangles | pass | 2800 total, largest mesh Head 452, of 20000 per mesh |
| Hard facets, no outline | pass | No smooth faces in the blend; no ink shell |
| Height ratio | pass | 34.5% of db_hero measured from render pixels, whole bounding box (claws to the top of the horns). Line-up also shows it hovering at db_hero shoulder height |
| Width | note | At 35% height the wingspan is about 5.3 model units, wider than db_hero, so it may clip the runner when hovering |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
