# side_king evidence

Id `side_king`, display name The Golden King. A downsized Sidekick of the boss `boss_king`, same design and same source: every attribute, source, licensing note and contradiction is in `docs/char_evidence/boss_king.md`. No new research was done and no reference image ships.
Usage: public Roblox experience (boss-drop Sidekick, `docs/SIDEKICK_SPEC.md`: Secret, 0.001% from Golden King's Treasure as a separate roll, never summoned). Rig: the same named parts as `boss_king` (Ea and the key separate), built in `tools/blender/sidekicks/` (k2).
Check date: 2026-11-11.

## What changes for the small size

The follower scales the boss model at runtime to the Sidekick rule, 1.7-2.3 studs of whole bounding box, as `side_raga` does. At that size features under about 2 px vanish, so (as for `side_raga`) only fine detail is simplified: fewer skirt plates, thicker earrings, a single-cylinder Ea, the key as one flat part. Exact counts and triangles are recorded here after k2's build (**proposed** budget: under `side_raga`'s 6,864 tris). The blocky R15 body is never slimmed.

Movement `Walk` (**proposed**): a short armoured stride; arms folded when still, as the boss idles. Event attack (**proposed**, key frames approved by the owner before in-betweens): a small Gate volley, 2 or 3 tiny gold ripple portals that fire weapon projectiles in straight lines.

Still needed, not done here: a `SidekickConfig` row in `BossDrops`, the model, portrait and head (k2, k5), the follower's runtime scale check, and a Studio check of the uploaded model (k6, owner's upload word).

## Art

Review renders go to `assets/characters_avatar/side_king/review/` (k2). Drawn `portrait.png` and `head.png` come from `render_portrait.py --blend`, from our own model only (k5).
