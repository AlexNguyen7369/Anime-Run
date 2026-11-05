# boss_raga evidence

Id `boss_raga`, proposed display name Big Raga. Based on: Eight-Handled Sword Divergent Sila Divine General Mahoraga, Jujutsu Kaisen. Version: the summoned form, no adaptation state and no cursed energy effects.
Usage: public Roblox experience (boss event, proposed). Rig: bespoke named parts with origins at the joints, `tools/blender/build_boss_event.py`; not the 6 RunnerFactory parts.
Check date: 2026-11-04.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Build | Tall humanoid, monstrous look | supported | https://www.yahoo.com/entertainment/jujutsu-kaisen-divine-general-mahoraga-084706092.html |
| Physique | Lean and muscular | supported, overridden | https://www.toy-people.com/en/?p=108431 |
| Skin | Pale | supported | Yahoo article above |
| Wheel | Golden eight-handled wheel floating over the head; rotates as it reacts | supported | Yahoo article above; https://jujutsu-kaisen.fandom.com/wiki/Eight-Handled_Sword_Divergent_Sila_Divine_General_Mahoraga (search summary only) |
| Head wings | Wings on the face | supported | toy-people page above |
| Horn-like growths | Four horn-like protrusions from the face | supported | Yahoo article above |
| Sword | Blade attached to the right hand (Sword of Extermination) | supported | Yahoo article above |
| Bandages | Wrapped round the arms | supported | toy-people page above |
| Wheel shape | Eight spokes passing a ring, a ball on each end and at the hub; gold | inferred | Licensed figure photos, toy-people page above |
| Wing layout | Four wings from the eye line, bone on top, long feathers below; two rise, two go out | inferred | Same photos |
| Eyes | None visible: the wings grow where eyes would be | inferred | Same photos |
| Face | Tall column head, furrowed brow, heavy lips, wide rows of square teeth, pale blue-grey | inferred | Same photos; anime portrait, https://anilist.co/character/319339 |
| Tail | Thick pale tube in segments split by dark bands, ending in a long white sickle | inferred, unsure | Same photos. The photos do not show its root. No text source calls it a tail |
| Rope | Black rope ring round the shoulders with black hanging tags | inferred | Same photos |
| Cloth | Grey torn cloth at the waist, trailing | inferred | Same photos |
| Rings | Dark ring on the sword wrist and on the ankle | inferred | Same photos |
| Feet | Large toes with short claws | inferred | Same photos |
| Height | No officially confirmed height found | supported | https://www.lojasouparceiro.ticketlog.com.br/celebrity-radar-news-hub-024/the-colossal-enigma-how-tall-is-mahoraga-unpacking-the-shikigamis-controversial-size-jp67z.html (low quality) |

Source quality: only the toy-people page and its photos describe a licensed product. The Yahoo article is secondary. Fandom appeared only as a search summary and was not read. No official character sheet was reached. No full front, side or back view of the character was reached, so every view but the figure's front three-quarter is built from inference.

## Contradictions and choices

- Multiple arms, eight arms, a single eye, white hair, a wheel on the back: only low-quality or AI avatar pages say so, and they contradict the sources above. Rejected. Two arms, wheel over the head.
- Number and place of wings: one avatar page says four from the eye sockets, Daily O gives no count. The figure photos show about four. Chosen: four.
- Horn-like protrusions: read as the bare bones of the four wings, not as extra horns. No separate horns modelled.
- Wheel plane: the photos and text give no resting angle. Chosen: upright facing front, leaning back 10 degrees so its face reads from the ground.
- Bandages: text says arms, the photos show only the sword arm. Chosen: both forearms, and up to mid upper arm on the sword side.
- Ankle ring: seen on one leg. Chosen: both.

## Project rules over source

- Blocky chunky body, no lean or tapered limbs, muscle as angled slabs and blocks (design doc section 5). This is the largest departure: the source is lean and organic, and the model can read as armour.
- Plain block hands, no fingers. Toes stay, because feet are not covered by the hand rule.
- A-pose, sword arm out 26 degrees, so the blade clears the body and floor. Blade length is cut to fit that pose: it is shorter than the figure's.
- Effects left out: purple cursed energy, rubble.
- Marks: inner wheel pattern is a plain ring in place of the source's crossing arcs, a small shape change. Whether the wheel counts as a mark under design doc section 5 is the owner's call; not entered in the marks ledger.

## Animation parts

18 meshes: LowerTorso (root), UpperTorso, Head, Wheel, Tail, Sword, and Left and Right UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot. Each origin is at its joint. Wheel origin is the hub: spin about its local Y.

## Changes

- 2026-11-04, owner review: scale only. 560 studs now means the top of the head; the wheel sits above it. Design, part names and filename unchanged. Mesh not rebuilt for this.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | One form, no adaptation state |
| Defining attributes | pass | Wheel over head, four face wings, right-arm blade, pale skin, bandages, teeth |
| Views agree | pass | All four views viewed on the contact sheet, some also at 1920x1080 |
| Back, side | inferred | No reference reached for either |
| Camera readability | not checked | Scale panel only; no in-game camera |
| Triangles | pass | 7840 total, largest mesh Head 2124, of 20000 per mesh |
| Hard facets, no outline | pass | No smooth faces in the blend; no ink shell |
| Scale | pass | Owner 2026-11-04: head top at 560 studs, wheel on top of that. 804.4 studs overall, 87.1 studs per model unit (head top measured at 6.43 units, overall 9.24) |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
