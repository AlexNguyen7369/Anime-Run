# punch_void "Void Saitamo": evidence

Id `punch_void`, display name Void Saitamo, Void tier. Based on: Saitama, One-Punch Man. A separate rollable variant of the Robux pass character `punch_hero` "Saitamo". Version: the same standard hero suit, intact, deadpan face, inside a purple aura.
Usage: public Roblox experience (rollable, proposed). Rig: the blocky R15 body of `punch_hero`.
Check date: 2026-11-05.

Licensing: no Roblox-supported license; unlicensed reference; owner accepts takedown risk (design doc section 5). A tweaked name is not a license. The upload ruling recorded for `punch_hero` (owner 2026-11-05, design doc 4.35) names that character only, and this variant has not been ruled on for upload.

## Evidence table

The source design is not researched again here. The suit evidence is the `punch_hero` table: `docs/char_evidence/punch_hero.md` on branch `feature/alex/monetization` (read with `git show`, not merged). No new web source was opened for this variant.

| Attribute | Value | Status | Source |
|---|---|---|---|
| Head | Bald | supported | `punch_hero` evidence, Wikipedia row |
| Expression | Deliberately blank | supported | `punch_hero` evidence, Wikipedia row |
| Suit | Yellow jumpsuit | supported, weak | `punch_hero` evidence, figure and cosplay listings |
| Cape | White | supported, weak | `punch_hero` evidence, figure listing |
| Gloves and boots | Red | supported, weak | `punch_hero` evidence, one art description |
| Zip, black belt, gold buckle, two round clasps | As modelled | inferred | `punch_hero` evidence, model's memory, no source opened |
| Eyes, cape length | As modelled | inferred | `punch_hero` evidence, model's memory, no source opened |
| Purple aura and haze | Glowing purple haze round the figure | owner ruling, not from the source | Owner ruling 2026-11-05 |

## Contradictions and choices

- The contradictions and open owner checks in the `punch_hero` evidence apply here too. The suit is a straight copy: `tools/blender/paint/char_punch_void.py` differs from `char_punch_hero.py` only in its header comment.
- The aura is not canon to this version of the character. It exists only so that nobody confuses the two (owner ruling 2026-11-05).
- Aura colour: deep violet to pale lilac. Purple is far from the suit's yellow and the gloves' red, so the suit stays readable.
- Portrait: the figure is drawn smaller (72 percent, head 70 percent) on the same straight bottom cut, to give the flames room. That is the portrait spec's framing bent on purpose. The die-cut edge turns lilac.
- Portrait haze: the soft haze has semi-transparent pixels, unlike the crisp alpha edge that `render_portrait.py` checks for other characters. The owner asked for haze, so `void_glow.py` checks size, frame clearance and bytes only.
- Model: 10 faceted translucent `AuraShell*` meshes, separate from the body and open at the base. They are in `punch_void.blend` and the review renders only. The export keeps the 6 body parts, so the plan is ParticleEmitters in game.

## Project rules over source

- Chunky R15 block body and plain block hands, as `punch_hero` (design doc section 5).
- All art is drawn from our own model and atlas, including the flames, haze and motes. No outside art.

## Validation

| Check | Result | Note |
|---|---|---|
| Version unambiguous | pass | one suit, no mixed forms |
| Defining attributes | pass | bald, blank face, yellow suit, red gloves and boots, white cape, belt |
| Views agree | pass | front, three-quarter, side and back looked at; the side view is the most washed by the shells |
| Distinct from `punch_hero` | pass | compared side by side at 256, 110, 64 and 60 px, on orange and dark |
| Camera readability | not checked | not seen in game or at running speed |
| Tris | pass | 2,442 of the 12,000 budget, 398 of them aura |
| Body rule | pass | same blocky body as `punch_hero`, no taper |
| Roblox import | not done | local draft, nothing uploaded |
| IP | unlicensed | see Licensing |
