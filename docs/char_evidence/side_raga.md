# side_raga evidence

Id `side_raga`, display name Big Raga. A downsized Sidekick of the boss `boss_raga`, same design and same source: every attribute, source, licensing note and contradiction is in `docs/char_evidence/boss_raga.md`. No new research was done and no reference image ships.
Usage: public Roblox experience (boss-drop Sidekick, `docs/SIDEKICK_SPEC.md`). Rig: the same 18 named parts as `boss_raga`, `tools/blender/build_boss_event.py`, built with `-- build side_raga`.
Check date: 2026-11-05.

## What changes for the small size

The model keeps boss_raga's native units (9.237 tall). The follower scales it at runtime to the Sidekick rule, 1.7-2.3 studs of whole bounding box including the wheel: a factor of 0.184-0.249, about 0.217 for 2 studs. At 2 studs and about 50 px per stud (estimated), one model unit is about 11 px, so features under 0.2 units fall under about 2 px. For that reason only:

| Detail | boss_raga | side_raga |
|---|---|---|
| Teeth per row | 7, half width 0.068 | 4, half width 0.115 |
| Wing feathers per wing | 7 | 5, spread over the same bone |
| Forearm bandage turns | 5 | 3, taller |
| Toe claws | 6 | none |
| Wheel outer ring section and segments | 0.075, 24 | 0.12, 16 |
| Wheel inner ring section and segments | 0.05, 16 | 0.085, 12 |
| Wheel spoke half width | 0.055 | 0.09 |
| Rope section and segments | 0.065, 16 | 0.1, 10 |

Triangles: 6,864 against boss_raga's 7,840, largest mesh 1,604 (cap 20,000 per mesh). That is more than side_knight (3,688) and side_wyvern (2,800), less than side_chain (11,568).

Still needed for this size, not done here: a `SidekickConfig` row, the follower's runtime scale and its scale-aware pose (`RunnerVisual.Pose` breaks on scaled rigs), and a check of 18 MeshParts per follower when a full server wears them. No Studio check of the uploaded model has been made.

## Art

Review renders in `assets/characters_avatar/side_raga/review/`. Drawn `portrait.png` and `head.png` come from `render_portrait.py --blend`, from our own model only.
