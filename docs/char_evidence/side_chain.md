# side_chain evidence

Id `side_chain`, proposed display name Pochito. Based on: Pochita, Chainsaw Man. Version: weakened dog form, not the hybrid or Hero of Hell forms.
Usage: public Roblox experience (boss event sidekick, proposed). Rig: bespoke parts, `tools/blender/build_boss_event.py`. Non-humanoid.
Check date: 2026-11-04.

Licensing: no Roblox-supported license found; unlicensed reference. The owner accepts the takedown risk (design doc section 5). A tweaked name is not a license.

## Evidence table

| Attribute | Value | Status | Source |
|---|---|---|---|
| Form | Tiny, cute dog-like creature in its weakest state | supported | https://beebom.com/chainsaw-man-pochita/ |
| Colour | Orange, sometimes red in the manga | supported | https://quotetheanime.com/pochita/ |
| Head | Chainsaw blade protruding from the head | supported | https://knowyourmeme.com/memes/pochita |
| Back | A handlebar on its back | supported | Know Your Meme page above |
| Tail | A pull cord as its tail | supported | Know Your Meme page above |
| Eye | White circle, on the design's real-chainsaw link | supported | quotetheanime page above |
| Body | Round egg, head and body one mass | inferred | Colour art, Know Your Meme cover, https://i.kym-cdn.com/entries/icons/original/000/042/503/cover3.jpg |
| Bar | Long rounded fin leaning forward above the snout, pale grey, flat seen from the side | inferred | Same art; anime portrait, https://anilist.co/character/170266 |
| Chain | Dark links round the bar edge with sharp spikes | inferred | Same art |
| Handle shape | Dark flat bar from behind the bar, along the top, its rear end turning down into the back | inferred | Same art |
| Cord end | Thin dark cord rising from the rear, triangular grip | inferred | Same art |
| Eyes | Big, round, cream ring, dark brown iris | inferred | Same art and portrait |
| Mouth | Overhanging snout, wide open dark red mouth, two upper fangs, pink tongue | inferred | Same art and portrait |
| Mark | Small pale spot on the flank | inferred | Same art |
| Legs | Four short stubby legs | inferred | Same art |

Source quality: Know Your Meme and quotetheanime are fan-level. The art is unattributed on Know Your Meme. The Fandom page was truncated before its Appearance section and was left alone. No official sheet was reached.

## Contradictions and choices

- Bar direction: the portrait is near-frontal and suggests a broad face from the front; the side-on art shows it flat from the side, in line with the body. A flat bar cannot do both. Chosen: turned 32 degrees off the body axis, so the broad face reads from the front and still from the side. This is a compromise to the side-on art, and the bar now shows edge-on from a three-quarter view on one side.
- Colour: orange or red. Chosen: a red-orange, `#EE7038` in the ramp's light half, between the two.
- One page mentions a "tail chainsaw"; Know Your Meme and the art show a cord. Chosen: cord.

## Project rules over source

- Owner ruling, design doc 4.36: this model overrides section 5's hard facets, with smooth rounded surfaces closer to the source. The bar's plate and chain links stay hard-edged as metal.
- Tongue held out at rest, mouth open, as in the cover art. Other art shows a closed smile with the tongue out.
- Toes are small rounded lumps in place of the art's drawn toe lines.
- No marks: the flank spot is skin, so no shape change applies.

## Changes

- 2026-11-04, owner review: rebuilt smooth. One smooth egg body with soft bumps for snout, rump and hips; mouth a true hollow with a clean edge; eyes and flank mark follow the body's curve; slim tapered legs with rounded paws and toes; bar with even chain links and sparse thorns; curved pull-cord tail. Atlas height 1024 px. Bar turned 32 degrees.
- Parts: Body, Bar, Handle, Tail, LegFrontL, LegFrontR, LegBackL, LegBackR. Origins at the joints; the Bar's turn is its object rotation.

## Validation

| Check | Result | Note |
|---|---|---|
| Version | pass | Dog form only |
| Defining attributes | pass | Orange egg body, head bar with chain, back handle, cord tail with grip, round eyes, fangs, tongue |
| Views agree | pass | All four views viewed on the contact sheet, some also at 1920x1080 |
| Back | inferred | No back reference reached |
| Follower size | pass, cost noted | 170 px wide render still reads: bar, handle, cord, eye, mouth. At 2 studs most of the density is not visible; no lower level of detail was made |
| Camera readability | pass | Front, line-up and small views read; no in-game camera |
| Triangles | pass | 11568 total, largest mesh Body 6776, of 20000 per mesh |
| Smooth surfaces, no outline | pass | Owner override of hard facets; no ink shell |
| Height ratio | pass | 34.9% of db_hero measured from render pixels, whole bounding box (top of the bar) |
| In game | not checked | No Studio run, no upload, no animation |
| IP | label | Unlicensed reference |
