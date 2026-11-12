# side_mage evidence

Id `side_mage`, display name The Elf Mage. A downsized Sidekick of the boss `boss_mage`, same design and same source: every attribute, source, licensing note and contradiction is in `docs/char_evidence/boss_mage.md`. No new research was done and no reference image ships.
Usage: public Roblox experience (boss-drop Sidekick, `docs/SIDEKICK_SPEC.md`: Secret, 0.001% from Elf Mage's Treasure as a separate roll, never summoned; owner 2026-11-11, the rule for every boss). Rig: the same named parts as `boss_mage` (staff and twin tails separate; the golem is not part of the Sidekick), built in `tools/blender/sidekicks/` (k2 of goal `boss-king`).
Check date: 2026-11-11.

## What changes for the small size

The follower scales the boss model at runtime to the Sidekick rule, 1.7-2.3 studs of whole bounding box, as `side_raga` does. At that size features under about 2 px vanish, so (as for `side_raga`) only fine detail is simplified: fewer gold bands on the capelet and cuffs, thicker earrings, the staff's crescent as one part. Exact counts and triangles are recorded here after k2's build (**proposed** budget: under `side_raga`'s 6,864 tris). The blocky R15 body is never slimmed.

Movement `Fly` (**proposed**): hovers around the character's shoulder with a gentle bob, staff held across the body as the boss hovers; flying Sidekicks' flap rule applies as a bob, since she has no wings (design doc 4.36 Ground and flying). Event attack (**proposed**, key frames approved by the owner before in-betweens): a small purple lightning bolt from the staff.

Still needed, not done here: a `SidekickConfig` row in `BossDrops`, the model, portrait and head (k2, k5), the follower's runtime scale check, and a Studio check of the uploaded model (k6, owner's upload word).

## Art

Review renders go to `assets/characters_avatar/side_mage/review/` (k2). Drawn `portrait.png` and `head.png` come from `render_portrait.py --blend`, from our own model only (k5).
