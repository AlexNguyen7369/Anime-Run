# fr_mage evidence

Id `fr_mage`, proposed display name Frierin. Based on: Frieren, Frieren: Beyond Journey's End. Version: season 1 travelling outfit.
Usage: public Roblox experience (proposed). Rig: R15 blocks, `tools/blender/paint/char_fr_mage.py`.
Check date: 2026-11-23.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Hair | Long silver, twin tails, centre-parted bangs | supported | https://zh.moegirl.org.cn/en/%E8%8A%99%E8%8E%89%E8%8E%B2 (read directly) |
| Eyes, brows | Green eyes, thick eyebrows | supported | same page |
| Ears | Pointed, elf | supported | same page |
| Tights, boots | Black pantyhose, mid-calf boots | supported | same page |
| Outfit layers, earrings | White and gold capelet, striped shirt, belt, tunic, red drops | inferred | docs/char_evidence/boss_mage.md (owner reference 4) |
| Staff | Dark red shaft, gold crescent round a red gem | supported | docs/char_evidence/boss_mage.md (https://youtooz.com/products/frieren) |

Source quality: fan wikis, guide sites and shop text only. "Read directly" means a tool fetched and summarised the page; "search extract" means only a search summary was seen. No official sheet, hex palette or image was viewed, and no row was checked against the source work.

## Contradictions and choices

- None new; see boss_mage.md.

## Project rules over source

- Chunky R15 block body, plain block hands, no fingers (design doc section 5).
- Marks: Staff crescent and clasp follow boss_mage's in-house shapes.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | season 1 travelling outfit |
| Defining attributes | pass | Silver middle part and twin tails, large elf ears, thick pale brows, green eyes, red drops, white and gold capelet, red and gold staff |
| Known gaps | open | Outfit geometry and ramps are shared with char_boss_mage.py on purpose: a change there changes this hero on rebuild. The tails are part of the Head and do not swing. |
| Views agree | pass | Front, three-quarter, back, portrait and head viewed, portrait also near 110 px; side view not viewed |
| Camera readability | not checked | Review renders only |
| Triangles | pass | 4052 of 12000 |
| Hard facets, no outline | pass | Built through `finish()` |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
