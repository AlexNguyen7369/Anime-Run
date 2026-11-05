# Board

## Doing
- u5 / c3 compatibility check: stopped on the owner's word 2026-11-04, not fully verified. UI `[UITEST] END pass=44 fail=0`; server `[CARTEST] END pass=49 fail=1` (`data`, fix 0fa4d06 not run), final server run skipped; audit FAIL, 5 of 6 addressed, not re-audited

- boss-event b1: revised Big Raga, Pochito, Kaizel and arena renders, no upload (owner to approve)
- boss-event b2: Gems, quest rewards, save fields, HUD, `/gems`

## Next
- boss-event b3 onward: `docs/ORCHESTRATOR_GOALS.md`
- Design doc 4.25 track loading: Tracks 1-5 first, the rest by proximity

## Done
- 2026-11-04 market copies Up to 3 copies of each aura and trail (6184cc9): slot_items 21, vehicle_effects 130 fail=0; ui_market 100 checks fail=0 at 0, 1, 3 copies; real BUY and slot clicks on desktop; rules audit not run
- 2026-11-04 roll-anim r4 Drawn portraits and head art: 44 + 44 uploaded; `roll_anim`, `hud`, `gacha`, `scrap`, `catalog` pass=5 fail=0; `ui_layout` 962 checks fail=0; `ui_roll_anim`, `ui_roll_emphasized`, `ui_index`, `ui_backpack_characters`, `ui_starter_pick`, `ui_showdown`, `ui_defeated` fail=0; rules audit PASS
- 2026-11-04 declutter d3 In-house Market stall, 2 gate Legends (d553ec1): spawn_area, world_layout, dojo, workshop pass=4 fail=0, rules audit PASS
- 2026-11-04 villains v1 + v2 (ad8f9cb): 9 redesigned models, 8 rollable: catalog 21, gacha 318 fail=0, audit PASS
- 2026-11-04 roll-anim r1-r3 Roll animation (147f02d): `roll_anim`, `hud`, `gacha`, `scrap` pass=4 fail=0; `ui_roll_anim`, `ui_roll_emphasized`, `ui_toast`, `ui_hitboxes`, `ui_buttons`, `ui_hud`, `ui_reduced_motion` fail=0; `ui_layout` 962 checks fail=2 (Index EnemiesTab, BUGS); rules audit PASS
- 2026-11-04 c6, c7, s1, s2 (c91c1d4): enemy banners, Defeated Enemies page, Bleech series: ui_showdown 10, ui_defeated 5, catalog 20, gacha 278 all fail=0, audit PASS
- 2026-11-04 declutter d1, d2 Clear spawn plaza (68e565a): spawn_area, world_layout, dojo, workshop pass=4 fail=0, rules audit PASS
- 2026-11-04 c5 Screen-edge pointer for the track enemy (8691b0e): `ui_billboards` 21 checks fail=0, rules audit PASS
Older entries: `current_progress.md`.
- 2026-11-04 c5 Track enemies: biome-matched cast, always-visible indicator, 9 new models (8dea3f3): `npc` 117 checks fail=0, `ui_billboards` 12 checks fail=0, rules audit PASS
- 2026-11-03 first-impression fi5: plaza petals and audio, trunks, Index icon: pass=8 fail=0, rules audit findings fixed
- 2026-11-03 first-impression fi3, fi4, load optimization: fresh server 40-44 s (was 65-77), pass=4 fail=0, rules audit PASS round 4; gate burst, real fresh save, phone, Reduced Motion not seen
- 2026-11-03 first-impression fi1 + fi2 (5759bae): plaza and Dojo meshes, loading screen, Market and Race Start landmarks: world_layout, spawn_area, dojo, workshop pass=4 fail=0; rules audit PASS round 2
- 2026-11-03 trim t1: stale docs and unused assets removed
