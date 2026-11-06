# side_crow evidence

Id `side_crow`, proposed display name Kasugay. Based on: the Kasugai crows, Demon Slayer. Version: a generic crow of the corps, closest to Matsuemon Tennouji, with none of the named crows' accessories.
Usage: public Roblox experience (Sidekick, Common, Fly, draft for owner approval). Rig: named parts in `tools/blender/sidekicks/side_crow.py`: Body, Head, WingLeft, WingRight, Tail, LegLeft, LegRight. Wings have their origin at the shoulder, to flap.
Check date: 2026-11-05.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Role | Messenger crow assigned to a corps member | supported | https://anilist.co/character/137810; search summary of https://kimetsu-no-yaiba.fandom.com/wiki/Kasugai_Crow |
| Speech | Talks, loudly | supported, not modelled | Same search summary |
| Colour | Blue-black, with slate shading | inferred | Portrait on https://anilist.co/character/137810 |
| Beak | Large, grey, pointed, darker line along the bite | inferred | Same portrait |
| Eye | Pale grey-lilac with a dark pupil | inferred | Same portrait |
| Plumage | Shaggy points on the head and throat | inferred | Same portrait |
| Wings, tail, legs | Ordinary crow shape | inferred | No source view reached; general crow anatomy |

Source quality: short database text and one close portrait of the head and chest. The fandom wiki was blocked for direct reading. The wings, tail and legs were not seen in any source.

## Contradictions and choices

- Which crow: many exist. Some have accessories, such as Urara's clover crown. Chosen: a plain crow, because the Sidekick stands for the corps' crows in general.
- The source has no strong feature beyond being a crow. This is a real recognition limit: without context it reads as a sharp cartoon crow. Owner may want a small accessory, for example a rolled message on the leg. That would be our invention, so it is left out.
- Pose: half-spread wings and tucked feet, for the hover rule (design doc 4.36).

## Project rules over source

- Hard facets and painted shading replace the source's soft feathering (design doc section 5).
- Feathers are hard flat plates.
- Fly: the wings stay separate parts. No flap animation in this draft.
- Marks: none.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Plain crow, no named crow's accessory |
| Defining attributes | pass, with a limit | Black, big grey beak, pale eye, shaggy throat; see the recognition limit above |
| Views agree | pass | Four views viewed |
| Wings, back, tail | inferred | No reference reached |
| Camera readability | not checked | Portrait read at 110 px; no in-game camera |
| Triangles | pass | 2796 total, largest mesh 832, of 20000 per mesh |
| Hard facets, no outline | pass | No smooth faces requested; no ink shell |
| Height ratio | not measured | 3.69 model units; to be scaled to 35% of a character on import. Wingspan is 8.4 units, 2.3 times its height: owner to look at it beside a runner |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
